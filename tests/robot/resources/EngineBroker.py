"""Robot Framework keywords to drive a real centreon-engine + centreon-broker pair
for stream connector functional tests.

The engine/broker configuration is static (tests/robot/config/), pointing broker's
"lua" output at a stream connector script with send_data_test=1: instead of making a
real HTTP call, the connector writes the payload it would have sent to its own
logfile. These keywords start/stop the two daemons, inject events through engine's
external command file, and read that logfile back for assertions.
"""

import json
import os
import re
import socket
import stat
import subprocess
import time

ENGINE_BIN = "/usr/sbin/centengine"
ENGINE_CFG = "/etc/centreon-engine/centengine.cfg"
BROKER_BIN = "/usr/sbin/cbd"
BROKER_BBDO_PORT = 5669
BROKER_CFG = "/etc/centreon-broker/central-broker.json"
COMMAND_FILE = "/var/lib/centreon-engine/rw/centengine.cmd"
CONNECTOR_LOGFILE = "/var/log/centreon-broker/splunk-events-test.log"

_SEND_DATA_LINE = re.compile(r"\[send_data\]:\s*(.*)")

_engine_process = None
_broker_process = None


def start_engine_and_broker(startup_timeout=30):
    """Start a real cbd and centengine using the static config under tests/robot/config.

    Broker is started first so it is already listening on its BBDO input port when
    engine's embedded broker module tries to connect to it.
    """
    global _engine_process, _broker_process

    os.makedirs(os.path.dirname(COMMAND_FILE), exist_ok=True)
    if os.path.exists(COMMAND_FILE) and not stat.S_ISFIFO(os.stat(COMMAND_FILE).st_mode):
        os.remove(COMMAND_FILE)
    if not os.path.exists(COMMAND_FILE):
        os.mkfifo(COMMAND_FILE, 0o660)

    _broker_process = subprocess.Popen([BROKER_BIN, BROKER_CFG])
    _wait_until_broker_listening(startup_timeout)

    _engine_process = subprocess.Popen([ENGINE_BIN, ENGINE_CFG])
    _wait_until_command_file_writable(startup_timeout)


def stop_engine_and_broker():
    """Terminate the centengine and cbd processes started by `Start Engine And Broker`."""
    global _engine_process, _broker_process

    for proc in (_engine_process, _broker_process):
        if proc is None:
            continue
        proc.terminate()
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)

    _engine_process = None
    _broker_process = None


def clear_connector_log():
    """Truncate the stream connector's own logfile, so each test starts from a clean slate."""
    open(CONNECTOR_LOGFILE, "w").close()


def send_host_check_result(host_name, state, output):
    """Inject a passive host check result, e.g. `Send Host Check Result    host_1    1    DOWN`."""
    _write_external_command(f"PROCESS_HOST_CHECK_RESULT;{host_name};{state};{output}")


def send_service_check_result(host_name, service_description, state, output):
    """Inject a passive service check result.

    | Send Service Check Result | host_1 | service_1 | 2 | CRITICAL - disk full |
    """
    _write_external_command(
        f"PROCESS_SERVICE_CHECK_RESULT;{host_name};{service_description};{state};{output}"
    )


def acknowledge_service(host_name, service_description, author="robot", comment="ack from robot test"):
    """Acknowledge a service problem (sticky, non-persistent, with notification)."""
    _write_external_command(
        f"ACKNOWLEDGE_SVC_PROBLEM;{host_name};{service_description};2;1;0;{author};{comment}"
    )


def schedule_service_downtime(host_name, service_description, duration_seconds=120, author="robot", comment="downtime from robot test"):
    """Schedule a fixed downtime on a service starting now."""
    start = int(time.time())
    end = start + int(duration_seconds)
    _write_external_command(
        f"SCHEDULE_SVC_DOWNTIME;{host_name};{service_description};{start};{end};1;0;{duration_seconds};{author};{comment}"
    )


def schedule_host_downtime(host_name, duration_seconds=120, author="robot", comment="downtime from robot test"):
    """Schedule a fixed downtime on a host starting now."""
    start = int(time.time())
    end = start + int(duration_seconds)
    _write_external_command(
        f"SCHEDULE_HOST_DOWNTIME;{host_name};{start};{end};1;0;{duration_seconds};{author};{comment}"
    )


def delete_service_downtime(host_name, service_description):
    """Delete every scheduled downtime matching this host/service.

    Uses DEL_SVC_DOWNTIME_FULL rather than DEL_SVC_DOWNTIME, which needs the numeric
    downtime_id engine assigned when the downtime was scheduled (not something we
    track). DEL_SVC_DOWNTIME_FULL instead matches on criteria - host and service here,
    every other field (start/end/fixed/triggered_by/duration/author/comment) left
    empty means "don't filter on this field", so this deletes all downtimes for that
    service regardless of when/how they were scheduled.
    """
    criteria = [host_name, service_description, "", "", "", "", "", "", ""]
    _write_external_command("DEL_SVC_DOWNTIME_FULL;" + ";".join(criteria))


def delete_host_downtime(host_name):
    """Delete every scheduled downtime matching this host (see `Delete Service Downtime`)."""
    criteria = [host_name, "", "", "", "", "", "", ""]
    _write_external_command("DEL_HOST_DOWNTIME_FULL;" + ";".join(criteria))


def wait_for_sent_event(timeout=10, since_line=0):
    """Wait for the next `[send_data]: <json>` line appended to the connector logfile.

    Splunk's HEC payload wraps the actual connector-formatted event under an "event"
    key alongside Splunk-specific metadata (index, source, sourcetype, host, time);
    `payload` is that inner dict, `envelope` is the full outer one. Returns a dict
    with both plus the 1-based line number it was found at (pass that number back as
    `since_line` to only look for later events in the same test case).
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        lines = _read_connector_log()
        for index in range(since_line, len(lines)):
            match = _SEND_DATA_LINE.search(lines[index])
            if match:
                envelope = json.loads(match.group(1))
                return {"line": index + 1, "envelope": envelope, "payload": envelope["event"]}
        time.sleep(0.2)
    raise AssertionError(
        f"No event sent by the connector within {timeout}s (logfile: {CONNECTOR_LOGFILE})"
    )


def _read_connector_log():
    if not os.path.exists(CONNECTOR_LOGFILE):
        return []
    with open(CONNECTOR_LOGFILE, "r") as handle:
        return handle.readlines()


def _write_external_command(command):
    timestamp = int(time.time())
    line = f"[{timestamp}] {command}\n"
    # Engine keeps the FIFO open for reading; a short retry loop absorbs the rare
    # case where the previous command is still being drained.
    last_error = None
    for _ in range(20):
        try:
            with open(COMMAND_FILE, "w") as handle:
                handle.write(line)
            return
        except OSError as error:
            last_error = error
            time.sleep(0.2)
    raise AssertionError(f"Could not write external command '{command}': {last_error}")


def _wait_until_broker_listening(timeout):
    # A fixed sleep here is not enough: cbd can take a variable amount of time to
    # bind its BBDO/TCP input depending on machine load, and engine's embedded broker
    # module does not retry gracefully - a first "Connection refused" sends it into an
    # exponential backoff (1s, 2s, 4s, ...) that alone can burn through a test's whole
    # event-wait timeout. Poll the actual port instead of guessing a sleep duration.
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _broker_process.poll() is not None:
            raise AssertionError(f"cbd exited early with code {_broker_process.returncode}")
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            probe.settimeout(0.5)
            try:
                probe.connect(("127.0.0.1", BROKER_BBDO_PORT))
                return
            except OSError:
                time.sleep(0.2)
    raise AssertionError(f"cbd never started listening on port {BROKER_BBDO_PORT}")


def _wait_until_command_file_writable(timeout):
    deadline = time.time() + timeout
    last_error = None
    while time.time() < deadline:
        if _engine_process.poll() is not None:
            raise AssertionError(f"centengine exited early with code {_engine_process.returncode}")
        try:
            with open(COMMAND_FILE, "w"):
                pass
            return
        except OSError as error:
            last_error = error
            time.sleep(0.5)
    raise AssertionError(f"centengine command file never became writable: {last_error}")
