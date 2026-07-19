# Robot Framework functional tests for stream connectors

## What this tests

Unlike the busted unit tests (`modules/tests/`, which mock the `broker` global) and the
packaging smoke test (`tests/packaging/`, which only loads a connector script without
calling `init`/`write`/`flush`), these tests run a **real `centreon-engine` + `centreon-broker`
pair** and drive a stream connector exactly as it runs in production: broker's `lua` output
module loads the connector script and dispatches real BBDO events to it.

Scope for now: only "apiv2" connectors (the modern pattern built on
`modules/centreon-stream-connectors-lib`) — both the `*-events-apiv2.lua` family (host/
service status, acknowledgement, downtime) and the `*-metrics-apiv2.lua` family
(performance data). 17 connectors are covered so far: 12 events connectors — splunk (the
pilot suite), canopsis, datadog, elasticsearch, keep, logstash, omi, opsgenie, pagerduty,
servicenow (both `-em-` and `-incident-` variants) and signl4 — plus all 5 metrics
connectors — clickhouse, datadog-metrics, elasticsearch-metrics, influxdb2, splunk-metrics
— see "Connectors covered" below for each one's specifics. Three connectors are
explicitly out: `bigquery-events-apiv2.lua` doesn't support `send_data_test`;
`kafka-events-apiv2.lua` needs LuaJIT's `ffi` module (via its bundled `rdkafka`
binding), which doesn't exist under centreon-broker's actual Lua runtime here (plain
PUC-Rio Lua 5.4 — confirmed with `lua -e 'print(pcall(require, "ffi"))'`);
`bsm-events-apiv2.lua` isn't in git yet (still someone's local work in progress) so it
isn't touched by this harness.

Metrics connectors turned out to need no new BBDO plumbing at all: they read
performance data out of the exact same host_status/service_status events the events
connectors use (via `broker.parse_perfdata()` in
`modules/centreon-stream-connectors-lib/sc_metrics.lua`), not a separate "storage"
category — see "Testing metrics connectors" below.

## How output is captured

Almost every apiv2 connector supports a `send_data_test` parameter
(`modules/centreon-stream-connectors-lib/sc_params.lua`, documented in
`modules/docs/sc_param.md`): when set to `1`, the connector writes the JSON payload it
would have sent to the external API into its own logfile instead of making the real
HTTP call. The broker config used here (`tests/robot/config/broker/central-broker.json`)
sets `send_data_test: 1` and a dedicated `logfile`, so no HTTP mock server is needed —
`tests/robot/resources/EngineBroker.py` just tails that logfile.

Events are injected by writing lines to centreon-engine's external command file
(`PROCESS_HOST_CHECK_RESULT`, `PROCESS_SERVICE_CHECK_RESULT`, `ACKNOWLEDGE_SVC_PROBLEM`,
`SCHEDULE_SVC_DOWNTIME`, ...), the same mechanism engine's own command pipe uses in
production — no BBDO client had to be reimplemented.

### Testing more than one connector

Each connector under test gets its own `tests/robot/config/broker/*.json` (its own `lua`
output, `send_data_test` logfile, and connector-specific mandatory params) and its own
suite passes both to `Start Engine And Broker`:

```robotframework
Suite Setup    Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-canopsis.json
...            connector_logfile=/var/log/centreon-broker/canopsis-events-test.log
```

Calling it with no arguments keeps using the pilot splunk config/logfile (both default
to that), so existing suites didn't need touching when the second connector was added.
`EngineBroker.py` also normalizes how a payload is unwrapped: Splunk's HEC format nests
the connector-formatted event under an `"event"` key, while Canopsis's `build_payload`
just does `table.insert(payload, event)` — a bare one-element JSON array. `wait_for_sent_event`'s
`_extract_payload` helper handles both shapes so `${event}[payload][...]` works the same
way regardless of which connector is under test.

### Connectors covered

Each row is `tests/robot/config/broker/central-broker-<name>.json` +
`tests/robot/connectors/<name>_events_apiv2.robot`; `splunk`/`canopsis` use
`central-broker.json`/`central-broker-canopsis.json` (no `-events` suffix, being the
first two suites written). "Recovery?" = whether sending the object back to OK/UP
produces an event.

| Connector | Ack? | Recovery? | Payload shape | Notable gotcha |
|---|---|---|---|---|
| splunk | no (filtered) | yes | `{"event": {...}}` | pilot suite |
| canopsis | yes | yes | bare `[{...}]` array | downtime untested (see below) |
| datadog | no (no formatter) | yes | bare object | — |
| elasticsearch | no (no formatter) | yes | bulk NDJSON, 2 JSON values per message | multi-line payload |
| keep | yes | yes | bare object | `flush()` bug, see below |
| logstash | no (no formatter) | yes | bare object | — |
| omi | no (no formatter) | n/a (service only) | **XML**, not JSON | no host support at all |
| opsgenie | no (no formatter) | yes | bare object | — |
| pagerduty | no (no formatter) | yes | bare object, own nested `"payload"` key | needs `luatz` (see below) |
| servicenow-em | no (no formatter) | yes | `{"records": [{...}]}` | trailing text after JSON in the log line |
| servicenow-incident | no (no formatter) | **no, by design** | bare object | trailing text after JSON; recovery filtered by `host_status`/`service_status` params |
| signl4 | no (no formatter) | yes | bare object | `flush()` bug, see below |

Every connector without an acknowledgement formatter has a matching negative test
("Acknowledging A Service Does Not Produce A `<X>` Event") confirming nothing is sent,
mirroring splunk's own such test — not just an oversight, this is deliberately verified
per connector rather than assumed from reading the source.

### Testing metrics connectors

The `*-metrics-apiv2.lua` family turned out to need **no new BBDO plumbing**: they read
Nagios-style perfdata straight out of the same host_status/service_status events the
events connectors use, via `sc_metrics.lua`'s `build_metric` (`broker.parse_perfdata()`
on `event.perfdata`) — there is no separate "storage"/"metric" BBDO category involved,
and `accepted_categories`/`accepted_elements` default to the exact same `"neb"`/
`"host_status,service_status"` as every events connector. The one extra requirement:
`process_performance_data=1` in `centengine.cfg` (flipped from the default `0` — harmless
for the events suites, which never set perfdata). `Send Host/Service Check Result` both
take an optional `perfdata` argument, appended to the check's output after a `|`:

```robotframework
Send Service Check Result    host_1    service_1    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
```

Each metric found in one perfdata string produces its own, separately-flushed event
(confirmed with a two-metric perfdata string in `splunk_metrics_apiv2.robot`) —
`sc_metrics:build_metric` loops over every parsed metric and calls the connector's
`format_metric` once per metric.

| Connector | Payload shape | Notable gotcha |
|---|---|---|
| splunk-metrics | `{"fields": {...}}`, dynamic `"metric_name:<name>"` key | — |
| clickhouse | raw SQL `INSERT ... VALUES (...)` string | not JSON/XML at all |
| datadog-metrics | `{"series": [{host, metric, points:[[ts,value]], tags}]}` | **crashes on host metrics** (see below) |
| elasticsearch-metrics | bulk NDJSON, fixed field names (`metric_name`, `metric_value`, ...) | same multi-line shape as elastic-events |
| influxdb2 | raw InfluxDB line-protocol text | not JSON/XML at all |

`_extract_payload` (`tests/robot/resources/EngineBroker.py`) gained two more recognized
wrapper keys for these — `"fields"` (splunk-metrics) and `"series"` (datadog-metrics) —
and `_parse_send_data_block` falls back to the **raw string itself** (rather than
raising) when a block parses as neither JSON nor XML, covering clickhouse's SQL and
influxdb2's line-protocol text without needing a third dedicated parser: those suites'
assertions use `Should Contain` on `${event}[payload]` directly instead of dict-key
access.

**datadog-metrics-apiv2.lua crashes on every host-level metric** — a real, previously
unexercised bug, not a test-config workaround like the others. `format_metric_event`
(shared by `format_metric_host`/`format_metric_service`) calls `build_metadata`, which
unconditionally does `if self.sc_event.event.cache.service.description then` to add a
`"service:..."` tag. But `event.cache.service` is only ever populated by
`sc_event.lua`'s `is_valid_service()`, which `sc_metrics.lua`'s
`is_valid_host_metric_event` never calls (only `is_valid_service_metric_event` does).
For a host metric, `event.cache.service` is `nil`, so this line crashes with `attempt to
index a nil value (field 'service')` — confirmed via `central-broker.log`'s `[lua]
[error]` output, not just a timeout. `datadog_metrics_apiv2.robot` has no host metric
test as a result (see "What's not covered yet").

## Engine and broker configuration

The static config lives under `tests/robot/config/` and is copied into the image at
build time (`/etc/centreon-engine/`, `/etc/centreon-broker/` — see the Dockerfile).
Two separate processes run inside the container, wired together like in a real
Centreon setup:

```
centengine  --(cbmod, BBDO/TCP :5669)-->  cbd
(config/engine/)                          (config/broker/central-broker.json)
                                              |
                                              +--> lua output --> splunk-events-apiv2.lua
                                                                     (send_data_test=1)
                                                                     --> logfile
```

### What each file is

| File | Purpose |
|---|---|
| `config/engine/centengine.cfg` | Engine's main config: which `cfg_file`s to load below, the `broker_module`/`broker_module_cfg_file` directives that wire it to broker (see below), the external command file path, logging. |
| `config/engine/hosts.cfg` | Defines `host_1` — passive-only (`active_checks_enabled 0`), `max_check_attempts 1` (see the gotcha below). |
| `config/engine/services.cfg` | Defines `service_1` and `service_2` on `host_1` — same passive-only, `max_check_attempts 1` pattern. |
| `config/engine/commands.cfg` | One dummy `check_dummy` command (`/bin/true`), referenced by the host/services above because engine requires every object to have a `check_command` — it's never actually executed since checks are passive-only. |
| `config/engine/timeperiods.cfg` | A single `24x7` timeperiod, referenced by the host/services (engine requires a valid `check_period`). |
| `config/engine/resource.cfg` | Engine's global macros (`$USER1$`, ...) — present because `centengine.cfg` references it via `resource_file`, effectively empty for our purposes. |
| `config/engine/hostgroups.cfg`, `config/engine/connectors.cfg` | Empty, but referenced by `cfg_file` in `centengine.cfg` — the files must exist even with nothing in them. |
| `config/broker/central-module.json` | Broker config *embedded in the engine process* (see below). |
| `config/broker/central-broker.json` | The standalone `cbd` daemon's config for the splunk suite, including the `lua` output under test (see below). |
| `config/broker/central-broker-canopsis.json`, `central-broker-<name>.json` (one per connector) | Same as above, one per connector under test — its own `lua` output/logfile and connector-specific mandatory params. See "Testing more than one connector" and "Connectors covered" above. |

- **`config/broker/central-module.json`** is the broker config *embedded in the engine
  process*: it has no `input`, only an `output` that opens a plain BBDO/TCP connection
  to `127.0.0.1:5669` (no TLS — everything runs in the same container). Engine loads it
  via the `broker_module_cfg_file` directive in `centengine.cfg`.
- **`config/broker/central-broker.json`** is the standalone `cbd` daemon: it declares
  the matching `input` on port `5669`, plus the `output` that actually matters for
  these tests — a `"type": "lua"` endpoint pointing at the connector script, configured
  with `send_data_test`/`logfile` (see "How output is captured" above).
- **`lua_parameter` gotcha**: broker's C++ parser (`broker/lua/src/factory.cc` in
  centreon-collect) only accepts `lua_parameter` as a single `{name, type, value}`
  object or an **array** of them — not a plain `{"key": "value"}` JSON object. `type` is
  `"string"`, `"password"` or `"number"`, and even for `"number"` the `value` must still
  be a JSON **string** (e.g. `"1"`, not `1`) — broker reads it as a string first, then
  parses it as a number. Get this wrong and `cbd` exits immediately with
  `key 'name' not found`.

- **`config/engine/`** defines one host (`host_1`) and two services (`service_1`,
  `service_2`), all with `active_checks_enabled 0` / `passive_checks_enabled 1`: nothing
  ever runs a real check script, every status comes from the external commands the
  Python library writes to `/var/lib/centreon-engine/rw/centengine.cmd`
  (`PROCESS_HOST_CHECK_RESULT`, `PROCESS_SERVICE_CHECK_RESULT`,
  `ACKNOWLEDGE_SVC_PROBLEM`, ...) — the same command pipe engine exposes in production,
  so no BBDO client had to be reimplemented.
- **`max_check_attempts 1` gotcha**: with the default of 3+ attempts, a single passive
  check result is a *soft* state change, and `sc_event` only forwards *hard* state
  changes — the connector would silently drop every event. Setting
  `max_check_attempts 1` on both the host and the services makes every check result
  immediately hard.
- `broker_module=/usr/lib64/centreon-engine/externalcmd.so` in `centengine.cfg` is what
  makes engine actually listen on the external command pipe; `broker_module_cfg_file`
  (pointing at `central-module.json`) is the separate directive that makes it forward
  BBDO events to broker — **on the 25.10/26.10 line only** (el8, el9, bookworm, trixie). See
  "Supported distributions" below: the 24.04/24.10 line (bullseye, jammy, noble) needs
  an extra `broker_module` line instead.

## Supported distributions

One Dockerfile per distro under `tests/robot/docker/`, matching the OS/Centreon-version
combinations this repo packages for (see the root `CLAUDE.md`):

| Distrib | Dockerfile | Centreon line | Status |
|---|---|---|---|
| AlmaLinux 9 (el9) | `Dockerfile.el9` | 25.10 | reference, default `docker compose` service |
| AlmaLinux 8 (el8) | `Dockerfile.el8` | 25.10 | working |
| AlmaLinux 10 (el10) | `Dockerfile.el10` | 26.10 | **not usable yet** — Centreon's rpm repo for it doesn't exist (404) as of this writing |
| Debian 11 (bullseye) | `Dockerfile.bullseye` | 24.04 | working |
| Debian 12 (bookworm) | `Dockerfile.bookworm` | 25.10 | working |
| Debian 13 (trixie) | `Dockerfile.trixie` | 26.10 | **not usable yet** — Centreon's apt repo for it doesn't exist (404) as of this writing |
| Ubuntu 22.04 (jammy) | `Dockerfile.jammy` | 24.04 | working |
| Ubuntu 24.04 (noble) | `Dockerfile.noble` | 24.10 | working |

They all install real `centreon-engine`/`centreon-broker` packages from Centreon's
`unstable` repo (same repo layout as `.github/actions/test-packages/action.yml`), but
**not the same Centreon version** — which distro maps to which version line is decided
by Centreon's own package repos, not by us. That version split matters here because the
two lines wire engine → broker differently:

- **25.10/26.10 line** (el8, el9, bookworm, trixie): a single `broker_module_cfg_file`
  directive in `centengine.cfg` is enough; there's no separate cbmod package.
- **24.04/24.10 line** (bullseye, jammy, noble): forwarding BBDO events to broker is a
  distinct loadable module shipped by the `centreon-broker-cbmod` package
  (`/usr/lib64/nagios/cbmod.so`), and it silently does nothing unless `centengine.cfg`
  also has an explicit
  `broker_module=/usr/lib64/nagios/cbmod.so /etc/centreon-broker/central-module.json`
  line — without it, engine starts up cleanly and processes external commands, but no
  event ever reaches broker and every test just times out waiting for an event. Each of
  these three Dockerfiles appends that line after copying the shared
  `tests/robot/config/engine/centengine.cfg`, rather than forking the config file itself.

Two more apt-specific gotchas hit only while building the Debian/Ubuntu images (fixed in
all five Debian/Ubuntu Dockerfiles, kept here since they're easy to reintroduce by copy-pasting):
`centreon-broker-core`'s `70-lua.so` dynamically loads `liblua<ver>.so.0` at runtime but
only pulls in the `lua<ver>` interpreter package as a declared dependency (not the
shared-library package) — install `liblua<ver>-0` explicitly, using the version reported
by `lua -e "print(string.sub(_VERSION, 5))"` (works everywhere here since the `lua<ver>`
package registers `/usr/bin/lua` via `update-alternatives`). Likewise `lua-curl`'s
`lcurl.so` links against `libcurl.so.4` without declaring it as a dependency either —
install `libcurl4` explicitly too.

Two more native dependencies, needed by specific connectors and installed in every
Dockerfile alongside `lua-curl`/`lua-lsqlite3`: `lua-socket` (elasticsearch and omi
`require("socket.http")`/`require("ltn12")`/`require("mime")`) and `luatz` (pagerduty
needs RFC 3339 timestamps) — the latter isn't packaged by any distro repo here, so it's
installed via `luarocks install luatz`, which in turn needs the Lua headers
(`lua-devel` / `liblua<ver>-dev`) to build against even though `luatz` itself has no C
parts to compile.

## Running locally (Docker)

```bash
cd tests/robot

# Build one distro at a time (only rebuilds what changed) ...
docker compose build robot-tests-bookworm
docker compose build robot-tests-jammy

# ... or build every distro in one shot (skips el10/trixie - see "Supported
# distributions" above; explicitly naming them still builds them on their own).
docker compose build

# Run just one distro's suite:
docker compose run --rm robot-tests            # AlmaLinux 9 (default/reference)
docker compose run --rm robot-tests-bookworm    # or any other service from the table above

# Run every distro's suite at once, in parallel, from already-built images:
docker compose up
```

`docker compose up` starts every default-profile service (el10/trixie excluded, same
as `build`), each running its image's default command (the full `connectors/` suite),
interleaving their logs prefixed by container name; it exits once they all finish, one
exit code per service. It does **not** rebuild images first — run `docker compose build`
beforehand if you've changed anything.

Reports (`report.html`, `log.html`, `output.xml`) are written to
`tests/robot/results/<distro>/` — a separate directory per distro (`el9`, `el8`,
`bullseye`, ...) specifically so parallel `docker compose up` runs don't overwrite each
other's output.

To iterate on a suite without rebuilding the image, edit files under
`tests/robot/{config,connectors,resources}/` — they are mounted as volumes — then
re-run `docker compose run --rm <service>` (or `up`). If you change
`modules/centreon-stream-connectors-lib` or `centreon-certified/` themselves, rebuild
the image(s) first, since those are copied in at build time, not mounted.

## Writing a new test

### General recipe

1. **Pick the scenario**: which BBDO event(s) does it need (host/service status,
   acknowledgement, downtime, ...), on which connector.
2. **Check `tests/robot/resources/EngineBroker.py` for the keyword you need.** If it's
   not there yet, add it: every keyword so far is a thin wrapper that writes one line to
   engine's external command pipe (`_write_external_command`). Find the exact command
   name and argument order in centreon-collect's
   `engine/src/commands/processing.cc` (the `"COMMAND_NAME"` -> `CMD_XXX` table) and
   `engine/src/commands/commands.cc` (the `cmd_xxx` function that parses the
   semicolon-separated args — read it rather than guessing the argument order/count).
3. **Write the `.robot` file**: `Suite Setup    Start Engine And Broker` /
   `Suite Teardown    Stop Engine And Broker`, `Test Setup    Clear Connector Log`, then
   for each event: send it, `Wait For Sent Event` (or `Run Keyword And Expect Error` if
   you expect it to be suppressed), assert on `${event}[payload][...]`. Pass
   `since_line=${previous_event}[line]` so a later `Wait For Sent Event` in the same test
   doesn't re-match an earlier line.
4. **Iterate**: `docker compose build` once, then
   `docker compose run --rm robot-tests robot --outputdir /opt/centreon-stream-connector-scripts/tests/robot/results /opt/centreon-stream-connector-scripts/tests/robot/connectors/your_file.robot`
   to run just your new file (faster than the whole `connectors/` directory). Rebuilding
   is only needed again if you change something under `modules/` or `centreon-certified/`
   (baked into the image) — editing the `.robot`/`.py` files themselves doesn't need a
   rebuild, they're volume-mounted.

### Debugging technique when a test doesn't behave as expected

Robot's `Wait For Sent Event` timeout (default 15s — bumped from 10s once a few
connectors turned out to have an inherent few-seconds flush latency, see "Cross-
connector gotchas" below) is too coarse a signal to debug a
new scenario — it only tells you "nothing arrived," not why. Drop to a manual shell in
the same image instead, so you can drive engine/broker step by step and read both logs
directly:

```bash
docker compose run --rm --entrypoint bash robot-tests -c '
/usr/sbin/cbd /etc/centreon-broker/central-broker.json &
sleep 2
/usr/sbin/centengine /etc/centreon-engine/centengine.cfg &
sleep 3
ts=$(date +%s)
echo "[$ts] YOUR_COMMAND;args;here" > /var/lib/centreon-engine/rw/centengine.cmd
sleep 3
cat /var/log/centreon-engine/centengine.log
cat /var/log/centreon-broker/splunk-events-test.log
'
```

What to look for:
- `centengine.log`: `EXTERNAL COMMAND: ...` (your command was parsed and accepted —
  if it's missing, the command name/argument count is wrong), `SERVICE ALERT`/`HOST ALERT`
  (an actual state change happened; passive checks that don't change state may not log
  this), `PASSIVE SERVICE CHECK`.
- the connector's own logfile: `[EventQueue:xxx]` lines trace the connector's own
  pipeline; `dropping event because element is not valid` and the `sc_event:is_valid_*`
  `WARNING`/`INFO` lines trace `sc_event`'s filtering decisions — these are the most
  useful line when a status/downtime/ack event isn't behaving as expected, since they
  say exactly which check rejected it and why.

If you need visibility *inside* `modules/centreon-stream-connectors-lib` itself (not
just its log output), temporarily add a line like
`self.sc_logger:error("[TEMP DEBUG]: value=" .. tostring(some_value))` right where you
need it — `error()` is always logged regardless of `log_level`. **Remove it before
committing anything** — this is real shared library code, not test code.

### Worked example: the downtime-replay test (`connectors/downtime_replay.robot`)

Built to test `sc_event.lua`'s "don't send a status change that happened during a
downtime immediately; hold it and replay it once the downtime ends" mechanism. It
passes on all six working distros. Getting there surfaced two things worth knowing if
you touch this test or the feature it covers:

1. **`storage_backend` matters.** The default backend
   (`storage_backends/sc_storage_broker.lua`) is an explicit no-op placeholder — every
   `set`/`get` call "succeeds" without persisting anything, silently (confirmed with a
   temporary debug line, see above, showing `get_multiple` always returning an empty
   table). The replay logic depends on data surviving between the downtime-start event
   and the later status-change/downtime-end events, so `config/broker/central-broker.json`
   sets `storage_backend=sqlite` on this output specifically (backed by
   `storage_backends/sc_storage_sqlite.lua`), leaving every other connector on the
   default.
2. **`sqlite` needs the `lua-lsqlite3` package**, which is published in Centreon's
   `rpm-plugins`/`apt-plugins` repos — *not* `rpm-standard`/`apt-standard`/`ubuntu-standard`,
   where every other package this harness installs comes from. Each Dockerfile
   configures both repos and installs `lua-lsqlite3` next to `lua-curl`. (Before this
   package was published, setting `storage_backend=sqlite` without it also surfaced a
   bug in `sc_storage.lua`'s own fallback-on-load-failure path — it tried to `require`
   the same missing module a second time outside a `pcall`, crashing the whole
   connector's `init()` instead of degrading gracefully. Worth knowing if you ever see
   a connector crash immediately after changing `storage_backend`.)

`tests/robot/resources/EngineBroker.py` also gained `Schedule Host Downtime`,
`Delete Service Downtime` and `Delete Host Downtime` while building this test —
`Delete Service Downtime`/`Delete Host Downtime` use `DEL_SVC_DOWNTIME_FULL`/
`DEL_HOST_DOWNTIME_FULL` (criteria-based: host/service and everything else left
blank matches any downtime for that host/service) rather than `DEL_SVC_DOWNTIME`/
`DEL_HOST_DOWNTIME`, which need engine's internal numeric `downtime_id` — something
this harness never tracks.

### Worked example: the canopsis test (`connectors/canopsis_events_apiv2.robot`)

Second connector added to the harness, mostly following the splunk pattern above (own
broker config, own logfile). Two things worth knowing:

1. **`accepted_elements` deliberately excludes `"downtime"`.** `canopsis2x-events-apiv2.lua`'s
   `EventQueue.new()` makes real blocking HTTP calls at init time to resolve pbehavior
   reason/type IDs and the Canopsis version — but only when
   `canopsis_downtime_send_pbh ~= 0` (default `1`) **and** `"downtime"` is in
   `accepted_elements` (default yes). Under `send_data_test=1` these calls short-circuit
   safely (they don't hang or error), but `canopsis_version` ends up as boolean `false`
   (the short-circuit's return value) instead of a real version string — and
   `format_event_downtime()` later does `string.find(canopsis_version, "22.10.")`, which
   crashes on a boolean the moment an actual downtime event is formatted. The test config
   (`central-broker-canopsis.json`) leaves `"downtime"` out of `accepted_elements`
   (host_status/service_status/acknowledgement only) and sets
   `canopsis_downtime_send_pbh=0` for extra clarity — this sidesteps the whole
   init-time API-lookup block and the crash, at the cost of not testing downtime for this
   connector yet (see "What's not covered yet" below).
2. **Cross-suite state leak, only visible when multiple suites run in the same
   container.** Every `docker compose run --rm <service>` starts a fresh container, so
   running one suite at a time (or via `docker compose up`, one suite per service) never
   hits this. But each Dockerfile's default `CMD` runs the *whole* `connectors/`
   directory as a single `robot` invocation — the same container's filesystem persists
   across every suite's `Start Engine And Broker`/`Stop Engine And Broker` cycle within
   that one run. Two files under `/var/lib/` outlive an individual suite and leak into
   whichever suite starts next:
   - `/var/lib/centreon-broker/stream-connector-storage.sdb` — the sqlite storage
     backend's db file (see the downtime-replay worked example above); every broker
     config here sets `storage_backend=sqlite` without overriding
     `sc_storage.sqlite.db_file`, so they all default to this same path
     (`sc_params.lua`).
   - `/var/log/centreon-engine/retention.dat` — engine loads this back as each object's
     *starting* state on the next startup, regardless of `use_retained_program_state`/
     `use_retained_scheduling_info` in `centengine.cfg` (those only gate program-wide
     settings and check scheduling, not object state). A suite that leaves e.g.
     `service_1` CRITICAL (canopsis's last test does) made the next suite's engine boot
     with `service_1` already CRITICAL instead of the config's OK default, silently
     turning that suite's baseline-setting checks into no-op "transitions" that never
     fired a `SERVICE ALERT`/BBDO event — surfaced as spurious `downtime_replay.robot`
     service-test failures ("No event sent...") that only reproduced when canopsis's
     suite ran first in the same `robot` invocation.

   Fixed by having `Start Engine And Broker` delete both files unconditionally before
   starting broker/engine, so every suite always starts from the same clean slate
   regardless of what ran before it in the same container — same idea as the existing
   command-file reset, just for these two extra pieces of state.

### Cross-connector gotchas (adding datadog through signl4)

Ten connectors added in one batch after canopsis surfaced patterns worth knowing before
touching any of them:

1. **A systemic off-by-one in most connectors' own `flush()`.** Unlike splunk/canopsis
   (which call the shared `sc_flush.lua`'s `flush_all_queues`, using `>=`), most of these
   ten connectors hand-roll their own `flush()` with
   `if queues_size > self.sc_params.params.max_buffer_size then ...` — with `>` instead
   of `>=`. Combined with `max_buffer_size` defaulting to (or, in keep/pagerduty/signl4/
   servicenow-em/servicenow-incident, being hard-forced to) `1`, a single queued event
   can never satisfy `1 > 1`, so it only ever gets flushed by the *other* branch (`if
   last_global_flush < os.time() - max_all_queues_age`, default 5s) — and since
   `last_global_flush` is set once at connector construction and `flush()` is only
   re-invoked when a *new* event arrives (there's no independent timer), a single event
   sent to a freshly-started connector can sit unflushed indefinitely: nothing ever
   triggers a second `flush()` call to re-check the age condition. Confirmed real (not a
   timing accident) by watching `keep-events-test.log` sit at "queue size is now: 1, max
   is: 1" for 15+ seconds straight. **Fixed in every affected `central-broker-<name>.json`
   by setting `max_all_queues_age=0`**, so the age-based branch is satisfied on that
   connector's very first `flush()` call regardless of wall-clock timing. Datadog/
   opsgenie/logstash *happened* to pass without this override in early runs purely
   because enough time had already elapsed since connector construction (broker startup
   overhead) by the time their first test sent an event — a coincidence, not a fix; they
   got the same override anyway for determinism. This is a real bug in each connector's
   own code, not touched here (out of scope, same as the canopsis `canopsis_version`
   bug) — only worked around in the test config.
2. **Payload shape is a genuine zoo**, all handled by `EngineBroker.py`'s
   `_parse_send_data_block`/`_decode_all_json_values`/`_extract_payload` rather than by
   each `.robot` file: bare JSON object (most connectors), bare one-element array
   (canopsis), dict wrapping the event under an `"event"` key (splunk) or a `"records"`
   key holding a one-element array (servicenow-em), Elasticsearch bulk NDJSON — two JSON
   values logged as one multi-line message, index-metadata then the real event (elastic;
   `_decode_all_json_values` decodes every value found and keeps the *last* one, which
   handles both this and #3 below with the same code), flat non-nested **XML** instead
   of JSON entirely (omi; `_parse_xml_flat` falls back to a tag regex when JSON decoding
   finds nothing, after stripping the outer wrapper tag — a naive tag regex matches that
   wrapper first and greedily consumes everything before any inner tag gets a chance,
   since it's the *only* valid match for its own backreference).
3. **Trailing text after the JSON on the same log line.** Both servicenow connectors log
   `"[send_data]: " .. tostring(data) .. " to endpoint: " .. tostring(endpoint)` — plain
   `json.loads` on the whole captured line would fail on that trailing garbage.
   `_decode_all_json_values` uses `json.JSONDecoder().raw_decode`, which stops cleanly at
   the end of the first valid JSON value and ignores whatever follows.
4. **servicenow-incident never sends recoveries, by design**, not a bug: it overrides
   the generic `host_status`/`service_status` params (which filter which *raw states*
   are even considered valid — distinct from `accepted_elements`' element-type
   filtering) to `"1,2"` and `"1,2,3"` respectively, excluding state `0` (UP/OK)
   entirely. Makes sense for an incident-management system: only problems open an
   incident.
5. **omi has no host support at all** — its default `accepted_elements` is
   `"service_status"` alone (not even `host_status`), and there's no
   `format_event_host` function to add it back without a custom `format_file`. Its
   suite only has service-based tests.

## What's not covered yet

- CI integration (a GitHub Actions workflow) is a deliberate follow-up, not part of this
  first iteration.
- Host-level metrics for datadog-metrics-apiv2.lua — the connector crashes on them (see
  "Testing metrics connectors" above), a real bug, not a coverage gap in this harness.
- `bigquery-events-apiv2.lua` does not support `send_data_test` and needs a different
  capture strategy.
- `kafka-events-apiv2.lua` can't run under this (or, seemingly, any real) centreon-broker
  Lua runtime — its bundled `rdkafka` binding requires LuaJIT's `ffi` module, and broker
  here uses plain PUC-Rio Lua 5.4, which has no such module (confirmed empirically, see
  "What this tests" above).
- `bsm-events-apiv2.lua` isn't tracked in git yet — not touched by this harness until
  it's committed.
- Only host/service status events are meaningfully assertable for splunk today: broker
  does deliver acknowledgement/downtime as their own BBDO element, but this connector's
  `accepted_elements` only lists `host_status,service_status`, so those are received and
  filtered out before reaching `send_data` (see the "Acknowledging A Service Does Not
  Produce A Splunk Event" test case).
- Downtime is only tested for the original two connectors (splunk implicitly filters it
  out; the downtime-replay suite exercises `sc_event.lua`'s replay mechanism through
  splunk). It's not tested for canopsis — its `format_event_downtime()` crashes on a
  boolean `canopsis_version` under `send_data_test=1` (see the canopsis worked example
  above) — nor for any of the ten connectors added after it: none of them have a
  `format_event_downtime` function at all, so there's nothing downtime-specific to
  assert on beyond "no event is sent," which the existing `accepted_elements` (none of
  them include `"downtime"`) already guarantees without a dedicated test.
- omi has no acknowledgement or downtime support either (no matching `format_event_*`
  functions), on top of having no host support at all (see "Cross-connector gotchas"
  above).
