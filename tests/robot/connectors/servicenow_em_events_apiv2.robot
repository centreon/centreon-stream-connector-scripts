*** Settings ***
Documentation       Functional tests for centreon-certified/servicenow/servicenow-em-events-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default).
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 Logging gotcha: this connector's send_data logs `"[send_data]: " .. tostring(data)
...                 .. " to endpoint: " .. tostring(endpoint)` - trailing text *after* the JSON on the
...                 same line. EngineBroker.py's `_decode_all_json_values` (via raw_decode) stops at
...                 the first fully-parsed JSON value and ignores that trailing text automatically.
...
...                 `severity` is raw passthrough for host (event.state, 0-3) but a connector-local
...                 remap for service (0->0, 1->3, 2->1, 3->4) - not the sc_params text translation.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-servicenow-em.json
...                 connector_logfile=/var/log/centreon-broker/servicenow-em-events-test.log
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
    Should Be Equal    ${down_event}[payload][node]    ${HOST}
    Should Be Equal    ${down_event}[payload][resource]    ${HOST}
    Should Be Equal As Integers    ${down_event}[payload][severity]    1
    Should Contain    ${down_event}[payload][description]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal As Integers    ${up_event}[payload][severity]    0

Service State Transitions Are Sent In Order With Correct Content
    [Documentation]    Service severity remap: 0->0 (OK), 1->3 (WARNING), 2->1 (CRITICAL), 3->4 (UNKNOWN).
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][resource]    ${SERVICE_1}
    Should Be Equal As Integers    ${warning_event}[payload][severity]    3

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal As Integers    ${critical_event}[payload][severity]    1
    Should Contain    ${critical_event}[payload][description]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal As Integers    ${ok_event}[payload][severity]    0

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][resource]    ${SERVICE_1}
    Should Be Equal As Integers    ${service_1_event}[payload][severity]    1

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][resource]    ${SERVICE_2}
    Should Be Equal As Integers    ${service_2_event}[payload][severity]    3

Acknowledging A Service Does Not Produce A ServiceNow Event Management Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
