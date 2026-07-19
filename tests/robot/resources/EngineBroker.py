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
COMMAND_FILE = "/var/lib/centreon-engine/rw/centengine.cmd"

# Every tests/robot/config/broker/*.json sets storage_backend=sqlite without overriding
# sc_storage.sqlite.db_file, so they all default (sc_params.lua) to this same path. All
# suites also reuse the same host_1/service_1/service_2 test entities, so state one suite
# writes here (e.g. a downtime marker) would otherwise leak into whatever suite starts next
# in the same container - only reproduces when multiple suites run in one `robot` invocation
# (the Dockerfiles' default CMD), not when each suite gets its own fresh `docker compose run`.
STORAGE_DB_FILE = "/var/lib/centreon-broker/stream-connector-storage.sdb"

# Engine writes current host/service states here (retention_update_interval and on
# shutdown) and loads it back as each object's *starting* state on the next startup -
# regardless of use_retained_program_state/use_retained_scheduling_info in centengine.cfg,
# which only gate program-wide settings and check scheduling, not object state. Without
# wiping this, a suite that leaves e.g. service_1 CRITICAL (canopsis_events_apiv2.robot's
# last test does) makes the next suite's engine boot with service_1 already CRITICAL
# instead of the config's OK default, silently turning that suite's baseline-setting
# checks into no-op "transitions" that never fire a SERVICE ALERT/BBDO event.
RETENTION_FILE = "/var/log/centreon-engine/retention.dat"

# Defaults match the pilot splunk suite's config, so existing suites calling
# `Start Engine And Broker` with no arguments keep working unchanged. A suite testing
# a different connector passes its own `broker_config`/`connector_logfile` (its own
# dedicated tests/robot/config/broker/*.json, with its own lua output and logfile).
DEFAULT_BROKER_CFG = "/etc/centreon-broker/central-broker.json"
DEFAULT_CONNECTOR_LOGFILE = "/var/log/centreon-broker/splunk-events-test.log"

_SEND_DATA_LINE = re.compile(r"\[send_data\]:\s*(.*)")

# Marks the start of a genuine new sc_logger line (e.g. "Sun Jul 19 11:06:27 2026: INFO: ..."),
# as opposed to a continuation line that's part of the *same* logged message - some connectors'
# payloads contain literal embedded newlines (elastic-events-apiv2.lua's send_data logs Elasticsearch
# bulk NDJSON: an index-action line, the event JSON, and a trailing blank line, all in one
# `sc_logger:notice(...)` call). Used to know where one `[send_data]:` message's text really ends.
_LOG_LINE_START = re.compile(r"^[A-Za-z]{3} [A-Za-z]{3}\s+\d{1,2} \d{2}:\d{2}:\d{2} \d{4}: ")

# Some connectors' send_data logs trailing text after the JSON on the same line (servicenow's
# `"[send_data]: " .. tostring(data) .. " to endpoint: " .. tostring(endpoint)`) - a plain
# json.loads on the whole captured text would fail on that trailing garbage. Decoding with
# raw_decode from position 0 and stopping at the first successfully parsed value sidesteps it
# automatically, and doubles as elastic's NDJSON handling: decode every JSON value found in the
# block and keep the *last* one - for a single-object payload that's the only value found; for
# elastic's two-line bulk NDJSON (index metadata, then the real event) it's the real event.
def _decode_all_json_values(text):
    decoder = json.JSONDecoder()
    values = []
    pos, length = 0, len(text)
    while True:
        while pos < length and text[pos].isspace():
            pos += 1
        if pos >= length:
            break
        try:
            value, pos = decoder.raw_decode(text, pos)
        except json.JSONDecodeError:
            break
        values.append(value)
    return values


# omi_events-apiv2.lua's payload isn't JSON at all - build_payload produces a flat, non-nested
# XML string ("<event_data>\t<title>...</title>\t<node>...</node>\t</event_data>"). Turned into a
# dict so Robot assertions can use the same `${event}[payload][field]` access pattern as every
# JSON-based connector.
_XML_TAG = re.compile(r"<(\w+)>(.*?)</\1>", re.DOTALL)
# re.findall matches leftmost-first: without stripping it first, the outer <event_data>...
# </event_data> wrapper itself matches (non-greedily consuming everything up to the only
# </event_data> in the string, since that's the sole valid match for backreference \1), and
# findall never gets to the inner tags at all - "event_data" ends up as the only extracted key.
_XML_OUTER_WRAPPER = re.compile(r"^<(\w+)>(.*)</\1>$", re.DOTALL)


def _parse_xml_flat(text):
    outer = _XML_OUTER_WRAPPER.match(text)
    if outer:
        text = outer.group(2)
    return dict(_XML_TAG.findall(text))


def _parse_send_data_block(lines, start_index):
    """Decode the `[send_data]:` message starting at lines[start_index], which may spill
    across following lines that aren't themselves a new sc_logger entry (see
    `_LOG_LINE_START`). Returns (envelope, end_index) where end_index is the index of the
    first line *not* part of this message (a new log line, or len(lines) at EOF).
    """
    text = _SEND_DATA_LINE.search(lines[start_index]).group(1)
    end_index = start_index + 1
    while end_index < len(lines) and not _LOG_LINE_START.match(lines[end_index]):
        text += lines[end_index]
        end_index += 1

    values = _decode_all_json_values(text)
    if values:
        return values[-1], end_index

    stripped = text.strip()
    if stripped.startswith("<"):
        return _parse_xml_flat(stripped), end_index
    raise AssertionError(f"Could not decode connector payload as JSON or XML: {text!r}")

_engine_process = None
_broker_process = None
_broker_cfg = DEFAULT_BROKER_CFG
_connector_logfile = DEFAULT_CONNECTOR_LOGFILE


def start_engine_and_broker(startup_timeout=30, broker_config=None, connector_logfile=None):
    """Start a real cbd and centengine using the static config under tests/robot/config.

    Broker is started first so it is already listening on its BBDO input port when
    engine's embedded broker module tries to connect to it. `broker_config` selects
    which tests/robot/config/broker/*.json cbd loads (which connector's lua output is
    under test); `connector_logfile` must match that config's `send_data_test` logfile.
    """
    global _engine_process, _broker_process, _broker_cfg, _connector_logfile

    _broker_cfg = broker_config or DEFAULT_BROKER_CFG
    _connector_logfile = connector_logfile or DEFAULT_CONNECTOR_LOGFILE

    os.makedirs(os.path.dirname(COMMAND_FILE), exist_ok=True)
    if os.path.exists(COMMAND_FILE) and not stat.S_ISFIFO(os.stat(COMMAND_FILE).st_mode):
        os.remove(COMMAND_FILE)
    if not os.path.exists(COMMAND_FILE):
        os.mkfifo(COMMAND_FILE, 0o660)

    if os.path.exists(STORAGE_DB_FILE):
        os.remove(STORAGE_DB_FILE)
    if os.path.exists(RETENTION_FILE):
        os.remove(RETENTION_FILE)

    _broker_process = subprocess.Popen([BROKER_BIN, _broker_cfg])
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
    open(_connector_logfile, "w").close()


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


def _extract_payload(envelope):
    """Different connectors wrap the actual formatted event differently: Splunk's HEC
    payload nests it under an "event" key alongside Splunk-specific metadata (index,
    source, sourcetype, host, time); Canopsis just JSON-encodes a one-element array
    (`build_payload` does `table.insert(payload, event)`, which is a bare Lua array).
    servicenow-em-events-apiv2.lua wraps it in a ServiceNow-specific bulk-import envelope
    instead (`'{"records":[' .. payload .. ']}'`) - a dict with a "records" key holding a
    one-element array. `payload` is always the inner, connector-formatted event dict
    either way.
    """
    if isinstance(envelope, list):
        return envelope[0] if envelope else {}
    if isinstance(envelope, dict) and "event" in envelope:
        return envelope["event"]
    if isinstance(envelope, dict) and "records" in envelope:
        records = envelope["records"]
        return records[0] if records else {}
    return envelope


def wait_for_sent_event(timeout=15, since_line=0):
    """Wait for the next `[send_data]: <json>` line appended to the connector logfile.

    Returns a dict with `payload` (the connector-formatted event - see
    `_extract_payload`) and `envelope` (the raw decoded JSON, useful for
    connector-specific metadata `payload` doesn't carry) plus the 1-based line number
    it was found at (pass that number back as `since_line` to only look for later
    events in the same test case).

    Some status changes make the connector (or the engine/broker pipeline feeding it)
    emit more than one identical `send_data` for what looks like a single command -
    e.g. a host recovering to UP has been observed sending the same event twice in a
    row, milliseconds apart. Once a match is found, this briefly polls for more lines
    with the exact same envelope immediately after it and coalesces them into one
    logical event, returning the *last* duplicate's line number - otherwise a caller
    using this event's `line` as a later `since_line` would mistake the unconsumed
    duplicate for a genuinely new, later event.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        lines = _read_connector_log()
        for index in range(since_line, len(lines)):
            if not _SEND_DATA_LINE.search(lines[index]):
                continue
            envelope, last_line = _parse_send_data_block(lines, index)
            settle_deadline = time.time() + 1
            while time.time() < settle_deadline:
                time.sleep(0.2)
                more_lines = _read_connector_log()
                if len(more_lines) <= last_line or not _SEND_DATA_LINE.search(more_lines[last_line]):
                    break
                next_envelope, next_last_line = _parse_send_data_block(more_lines, last_line)
                if next_envelope != envelope:
                    break
                last_line = next_last_line
                settle_deadline = time.time() + 1
            return {"line": last_line, "envelope": envelope, "payload": _extract_payload(envelope)}
        time.sleep(0.2)
    raise AssertionError(
        f"No event sent by the connector within {timeout}s (logfile: {_connector_logfile})"
    )


def assert_no_status_change_after(since_line, expected_state, timeout=8):
    """Consume every event arriving within `timeout`; pass if none arrive, or if every
    one that does still reports `expected_state` (a harmless same-state echo - see
    `Wait For Event With State`). Fail immediately if any event reports a different
    state - that would be a real status-change event that should have been held back
    while the object was in downtime.
    """
    expected_state = int(expected_state)
    deadline = time.time() + timeout
    line = since_line
    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            return
        try:
            event = wait_for_sent_event(timeout=remaining, since_line=line)
        except AssertionError:
            return
        actual_state = int(event["payload"].get("state"))
        if actual_state != expected_state:
            raise AssertionError(
                "Unexpected status-change event sent after the downtime ended: "
                f"state={actual_state} (expected only harmless echoes of {expected_state}, "
                "if anything at all)"
            )
        line = event["line"]


def _read_connector_log():
    if not os.path.exists(_connector_logfile):
        return []
    with open(_connector_logfile, "r") as handle:
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
