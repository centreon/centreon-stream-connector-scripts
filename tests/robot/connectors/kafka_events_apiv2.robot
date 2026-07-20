*** Settings ***
Documentation       Functional tests for centreon-certified/kafka/kafka-events-apiv2.lua, run against
...                 a real centreon-engine + centreon-broker pair - see splunk_events_apiv2.robot for
...                 the general approach.
...
...                 Initially thought untestable: this connector's bundled rdkafka binding
...                 (modules/centreon-stream-connectors-lib/rdkafka/librdkafka.lua) does
...                 `pcall(require, "ffi")` (LuaJIT-only, absent under centreon-broker's actual
...                 PUC-Rio Lua 5.4 runtime here). But that file *already* falls back to
...                 `require("cffi")` on failure - the `lua-cffi` package (published in the same
...                 `centreon-plugins-unstable` repo as `lua-lsqlite3`/`lua-openssl`) provides exactly
...                 that as a LuaJIT-ffi-compatible shim (same function set used here: cast/cdef/
...                 errno/gc/load/new/string). The only other missing piece was `librdkafka` itself -
...                 the real native C client library `ffi.load()`s at runtime (from the base
...                 `appstream` repo, no special config needed). No connector code changes were
...                 needed, unlike bigquery - just the two missing packages, added to the Dockerfile.
...
...                 `EventQueue.new()` unconditionally constructs a real `kafka_producer`/`kafka_topic`
...                 (calling `producer:brokers_add()` with our dummy, unreachable `brokers` value) -
...                 confirmed safe: librdkafka connects to brokers asynchronously in a background
...                 thread, so this never blocks or errors at init, and `send_data_test=1` short-circuits
...                 before the actual `produce()` call, so a real broker connection is never needed.
...
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...                 accepted_categories/accepted_elements aren't overridden by the connector itself
...                 (sc_params.lua's defaults are "neb,bam"/"host_status,service_status,ba_status") -
...                 restricted to "neb"/"host_status,service_status" here to match every other suite.
...
...                 Payload is a bare JSON object (comma-joined without brackets if buffer > 1, but
...                 max_buffer_size=1 here keeps it to one object per line). `state` is the sc_params
...                 default text translation (UP/DOWN/UNREACHABLE, OK/WARNING/CRITICAL/UNKNOWN), not a
...                 raw Centreon int. Same `>` vs `>=` flush() off-by-one as most other connectors in
...                 this harness - worked around with max_all_queues_age=0.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-kafka.json
...                 connector_logfile=/var/log/centreon-broker/kafka-events-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Down Then Recovery Are Sent As Distinct Events
    Send Host Check Result    ${HOST}    1    DOWN - no response to ping
    ${down_event}=    Wait For Sent Event
    Should Be Equal    ${down_event}[payload][host]    ${HOST}
    Should Be Equal    ${down_event}[payload][state]    DOWN
    Should Contain    ${down_event}[payload][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][state]    UP

Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][host]    ${HOST}
    Should Be Equal    ${warning_event}[payload][service]    ${SERVICE_1}
    Should Be Equal    ${warning_event}[payload][state]    WARNING

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal    ${critical_event}[payload][state]    CRITICAL
    Should Contain    ${critical_event}[payload][output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ok_event}[payload][state]    OK

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][service]    ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][service]    ${SERVICE_2}

Acknowledging A Service Does Not Produce A Kafka Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
