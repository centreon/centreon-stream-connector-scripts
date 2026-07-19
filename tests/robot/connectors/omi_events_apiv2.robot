*** Settings ***
Documentation       Functional tests for centreon-certified/omi/omi_events-apiv2.lua, run against a
...                 real centreon-engine + centreon-broker pair - see splunk_events_apiv2.robot for
...                 the general approach (send_data_test writes the payload to the connector's own
...                 logfile instead of a real HTTP call).
...
...                 Despite the "apiv2" filename, this connector's payload is XML, not JSON
...                 (build_payload wraps each field as `<field>value</field>` inside a flat
...                 `<event_data>...</event_data>`, no nesting). EngineBroker.py's
...                 `_parse_send_data_block` falls back to a flat XML-tag regex when the logged block
...                 doesn't parse as JSON, so `${event}[payload][field]` still works the same way -
...                 values just come through as strings (e.g. severity is "2", not an int).
...
...                 Service only: default accepted_elements is "service_status" alone (not even
...                 host_status), and there is no format_event_host/format_event_acknowledgement/
...                 format_event_downtime anywhere in this connector - host, acknowledgement and
...                 downtime scenarios don't apply here at all.
...
...                 `description` is not asserted on: format_event_service does
...                 `string.match(event.output, "^(.*)\\n")`, a Lua pattern that only matches if
...                 `output` contains a literal embedded newline - a single-line check result (as
...                 used here, matching every other suite's style) leaves `description` unset.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-omi.json
...                 connector_logfile=/var/log/centreon-broker/omi-events-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][title]    ${SERVICE_1}
    Should Be Equal    ${warning_event}[payload][node]    ${HOST}
    Should Be Equal As Integers    ${warning_event}[payload][severity]    1

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal As Integers    ${critical_event}[payload][severity]    2

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal As Integers    ${ok_event}[payload][severity]    0

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][title]    ${SERVICE_1}
    Should Be Equal As Integers    ${service_1_event}[payload][severity]    2

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][title]    ${SERVICE_2}
    Should Be Equal As Integers    ${service_2_event}[payload][severity]    1
