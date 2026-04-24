# Stream Connector Tests — Robot Framework

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Directory structure](#directory-structure)
- [Running the tests](#running-the-tests)
- [Writing a new test suite](#writing-a-new-test-suite)
  - [1. Create event JSON fixtures](#1-create-event-json-fixtures)
  - [2. Create the .robot test file](#2-create-the-robot-test-file)
  - [3. Useful assertions](#3-useful-assertions)
  - [4. Overriding connector parameters](#4-overriding-connector-parameters)
  - [5. Providing broker cache fixtures](#5-providing-broker-cache-fixtures)
- [How the test runner works](#how-the-test-runner-works)
- [Broker mock reference](#broker-mock-reference)

---

## Overview

These tests validate stream connectors (Lua scripts) **without** a running Centreon Broker.
A lightweight test runner (`sc_runner.lua`) loads a connector, injects a synthetic BBDO event
(from a JSON file), and captures the payload the connector would have sent to its destination.

The Centreon Broker Lua globals (`broker`, `broker_log`, `broker_cache`) are provided by
`broker_mock.lua`, so no Centreon installation is needed.

Tests are written with [Robot Framework](https://robotframework.org/) and run inside a
Docker container that provides Lua 5.3, `lua-cjson`, and `robotframework`.

---

## Prerequisites

Build the Docker image once from the root of the repository:

```bash
docker build \
  --build-arg REGISTRY_URL=docker.io/library \
  -t testing-stream-connector-bookworm \
  -f .github/docker/Dockerfile.testing-stream-connectors-bookworm \
  .
```

> **Note:** `REGISTRY_URL=docker.io/library` uses the public `debian:bookworm` base image.
> Inside Centreon CI, omit this argument to use the private Centreon base image,
> or pass `CENTREON_REPO=<url>` to also install the official `centreon-stream-connectors-lib`
> and `centreon-broker` packages.

---

## Directory structure

```
tests/robot/
├── README_EN.md                    # this file (English)
├── README_FR.md                    # this file (French)
├── variables.robot                 # shared Robot variables (paths)
├── resources/
│   ├── broker_mock.lua             # mock of broker, broker_log, broker_cache globals
│   └── sc_runner.lua               # test runner: loads connector + injects event
└── suites/
    └── <connector-name>/
        ├── <connector-name>.robot  # Robot test suite
        └── events/
            ├── host_down.json      # BBDO event fixtures
            ├── service_critical.json
            └── service_ok.json
```

Each connector gets its own sub-directory under `suites/`.

---

## Running the tests

**Run all test suites:**

```bash
docker run --rm \
  -v "$(pwd):/repo" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --outputdir /tmp/robot-results suites/
```

**Run a single suite:**

```bash
docker run --rm \
  -v "$(pwd):/repo" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --outputdir /tmp/robot-results suites/datadog/
```

**Run a single test case by name:**

```bash
docker run --rm \
  -v "$(pwd):/repo" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --test "Host DOWN should produce a valid Datadog payload" \
        --outputdir /tmp/robot-results suites/
```

Robot Framework writes `output.xml`, `log.html`, and `report.html` to the `--outputdir`.
To read them outside the container, mount a host directory instead of `/tmp/robot-results`:

```bash
mkdir -p /tmp/rf-results
docker run --rm \
  -v "$(pwd):/repo" \
  -v "/tmp/rf-results:/results" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --outputdir /results suites/
# then open /tmp/rf-results/report.html in a browser
```

---

## Writing a new test suite

### 1. Create event JSON fixtures

Create `tests/robot/suites/<connector>/events/` and add one JSON file per scenario.

A JSON fixture is a raw BBDO event as Centreon Broker would pass it to the `write()` function.
Required fields vary by event type:

**Host status event** (`_type: 65550`, `category: 1`, `element: 14`):

```json
{
  "_type": 65550,
  "category": 1,
  "element": 14,
  "host_id": 1,
  "service_id": 0,
  "state": 1,
  "state_type": 1,
  "output": "CRITICAL - Host is unreachable",
  "last_check": 1700000000,
  "last_state_change": 1700000000,
  "last_hard_state_change": 1700000000,
  "last_hard_state": 1,
  "scheduled_downtime_depth": 0,
  "acknowledged": false
}
```

**Service status event** (`_type: 65563`, `category: 1`, `element: 24`):

```json
{
  "_type": 65563,
  "category": 1,
  "element": 24,
  "host_id": 1,
  "service_id": 1,
  "state": 2,
  "state_type": 1,
  "output": "CRITICAL - Service is down",
  "perfdata": "rta=100ms;50;200;0",
  "last_check": 1700000000,
  "last_state_change": 1700000000,
  "last_hard_state_change": 1700000000,
  "last_hard_state": 2,
  "scheduled_downtime_depth": 0,
  "acknowledged": false
}
```

> **Deduplication note:** The stream connector library deduplicates events by comparing
> `last_hard_state_change` and `last_check`. Set them to the same value to avoid the
> event being silently dropped by the dedup filter.

Common state values:
- Host: `0` = UP, `1` = DOWN, `2` = UNREACHABLE
- Service: `0` = OK, `1` = WARNING, `2` = CRITICAL, `3` = UNKNOWN

---

### 2. Create the .robot test file

Create `tests/robot/suites/<connector>/<connector>.robot`:

```robotframework
*** Settings ***
Resource          ../../variables.robot
Library           Process
Library           String

*** Variables ***
${CONNECTOR}    ${CONNECTORS_DIR}/<connector>/<connector-script>.lua
${EVENTS_DIR}   ${CURDIR}/events

*** Test Cases ***
Service CRITICAL should produce a valid payload
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/service_critical.json
    ...    api_key\=fake_key
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    [send_data]:
    Should Contain    ${result.stdout}    CRITICAL
```

The `Run Process` call invokes:
```
lua sc_runner.lua <connector.lua> <event.json> [key=value ...]
```

The connector runs with `send_data_test=1` (no real HTTP call).
When the connector sends data, it logs a line of the form:
```
[NOTICE] [send_data]: <json-payload>
```

---

### 3. Useful assertions

| Goal | Keyword |
|---|---|
| Event was sent | `Should Contain    ${result.stdout}    [send_data]:` |
| Event was dropped | `Should Not Contain    ${result.stdout}    [send_data]:` |
| Payload contains a value | `Should Contain    ${result.stdout}    expected-string` |
| Exact payload match | `Should Contain    ${result.stdout}    "key":"expected-value"` |
| Script exited cleanly | `Should Be Equal As Integers    ${result.rc}    0` |
| Check for an error log | `Should Contain    ${result.stderr}    [ERROR]` |

---

### 4. Overriding connector parameters

Any `key=value` argument after the event file is passed to the connector as a configuration
parameter, overriding the default. This allows testing different filter scenarios without
modifying the connector.

```robotframework
# Only accept CRITICAL service events; an OK event must be dropped
Service OK should be dropped when service_status filter only accepts CRITICAL
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/service_ok.json
    ...    api_key\=fake_key    service_status\=2
    Should Be Equal As Integers    ${result.rc}    0
    Should Not Contain    ${result.stdout}    [send_data]:
```

Backslash-escape `=` in Robot Framework (`\=`) to prevent it from being interpreted as a
named argument.

Common parameters:

| Parameter | Default | Description |
|---|---|---|
| `host_status` | `0,1,2` | Accepted host states (comma-separated) |
| `service_status` | `0,1,2,3` | Accepted service states (comma-separated) |
| `hard_only` | `1` | `1` = HARD state only, `0` = HARD and SOFT |
| `max_buffer_size` | `1` | Queue size before flush (use `0` to flush immediately) |
| `log_level` | `1` | Verbosity: `1`=INFO, `2`=DEBUG |

---

### 5. Providing broker cache fixtures

By default, `broker_cache` returns generic mock data (e.g., host name `mock-host-1`).
To test with realistic cache data, pass a `cache_file` pointing to a JSON fixture:

```robotframework
${result}=    Run Process
...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/host_down.json
...    api_key\=fake_key    cache_file\=${CURDIR}/cache/my_cache.json
```

Cache fixture format (`tests/robot/suites/<connector>/cache/my_cache.json`):

```json
{
  "hosts": {
    "1": {
      "name": "my-server",
      "alias": "production web server",
      "address": "192.168.1.10",
      "state": 0,
      "state_type": 1,
      "acknowledged": false,
      "scheduled_downtime_depth": 0,
      "instance_id": 1
    }
  },
  "services": {
    "1_1": {
      "description": "HTTP",
      "state": 0,
      "state_type": 1,
      "acknowledged": false,
      "scheduled_downtime_depth": 0
    }
  },
  "hostgroups": {
    "1": [{"id": 10, "name": "Linux-Servers"}]
  },
  "instances": {
    "1": {"name": "Central"}
  }
}
```

The key for `services` is `"<host_id>_<service_id>"`.

---

## How the test runner works

`resources/sc_runner.lua` performs the following steps:

1. Loads `broker_mock.lua` to define `broker`, `broker_log`, and `broker_cache` globals.
2. Parses `key=value` arguments and builds a configuration table with `send_data_test=1`
   and `max_buffer_size=0` (to force immediate flush).
3. If `cache_file` is provided, loads the JSON fixture into `_MOCK_CACHE` and reloads
   `broker_mock.lua` so `broker_cache` picks up the fixture data.
4. Adds the repository `modules/` directory to `package.path` so the stream connector
   library is loaded from the working copy (not the installed system package).
5. Loads the event from the JSON file and decodes it with `broker.json_decode`.
6. Calls `dofile(connector)` then `init(conf)`, `write(event)`, `flush()`.

Because `send_data_test=1`, the connector never makes a real HTTP request.
Instead it calls `sc_logger:notice("[send_data]: " .. payload)`, which is captured on
stdout.

---

## Broker mock reference

`resources/broker_mock.lua` provides three globals:

### `broker_log`

All methods (`info`, `warning`, `error`, `debug`, `notice`) write to **stdout** with
a `[LEVEL]` prefix so Robot Framework can capture and assert on log messages.

### `broker`

| Method | Behaviour |
|---|---|
| `broker.json_encode(t)` | Encodes a Lua table to a JSON string via `lua-cjson`. |
| `broker.json_decode(s)` | Decodes a JSON string; integer-valued floats are normalised to Lua integers. |

### `broker_cache`

All methods fall back to sensible defaults if no `cache_file` fixture is provided.

| Method | Default return |
|---|---|
| `broker_cache:get_host(id)` | `{name="mock-host-<id>", address="127.0.0.1", ...}` |
| `broker_cache:get_service(hid, sid)` | `{description="mock-service-<sid>", state=0, ...}` |
| `broker_cache:get_hostgroups(id)` | `{}` |
| `broker_cache:get_servicegroups(hid, sid)` | `{}` |
| `broker_cache:get_severity(hid[, sid])` | `nil` |
| `broker_cache:get_instance(id)` | `{name="mock-poller-<id>"}` |
| `broker_cache:get_instance_name(id)` | `"mock-poller-<id>"` |
| `broker_cache:get_ba(id)` | `nil` |
| `broker_cache:get_bv(id)` | `nil` |
