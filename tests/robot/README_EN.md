# Robot Framework functional tests for stream connectors

## What this tests

Unlike the busted unit tests (`modules/tests/`, which mock the `broker` global) and the
packaging smoke test (`tests/packaging/`, which only loads a connector script without
calling `init`/`write`/`flush`), these tests run a **real `centreon-engine` + `centreon-broker`
pair** and drive a stream connector exactly as it runs in production: broker's `lua` output
module loads the connector script and dispatches real BBDO events to it.

Scope for now: only "apiv2" connectors (the modern pattern built on
`modules/centreon-stream-connectors-lib`). The pilot suite covers
`centreon-certified/splunk/splunk-events-apiv2.lua`.

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
  BBDO events to broker.

## Running locally (Docker)

```bash
cd tests/robot
docker compose build
docker compose run --rm robot-tests
```

Reports (`report.html`, `log.html`, `output.xml`) are written to `tests/robot/results/`.

To iterate on a suite without rebuilding the image, edit files under `tests/robot/` —
they are mounted as a volume — then re-run `docker compose run --rm robot-tests`. If you
change `modules/centreon-stream-connectors-lib` itself, rebuild the image
(`docker compose build`), since the library is copied into the Lua path at build time.

## What's not covered yet

- CI integration (a GitHub Actions workflow) is a deliberate follow-up, not part of this
  first iteration.
- `bigquery-events-apiv2.lua` does not support `send_data_test` and needs a different
  capture strategy.
- Only host/service status events are meaningfully assertable for this connector today:
  broker does deliver acknowledgement/downtime as their own BBDO element, but this
  connector's `accepted_elements` only lists `host_status,service_status`, so those are
  received and filtered out before reaching `send_data` (see the
  "Acknowledging A Service Does Not Produce A Splunk Event" test case).
