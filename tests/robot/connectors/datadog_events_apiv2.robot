*** Settings ***
Documentation       Functional tests for centreon-certified/datadog/datadog-events-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default -
...                 it overrides sc_params.lua's "neb,bam" categories / "...,ba_status" elements
...                 itself). No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 State is never a raw Centreon int here: `title` embeds the text translation from
...                 sc_params' default status_mapping (UP/DOWN/UNREACHABLE, OK/WARNING/CRITICAL/UNKNOWN),
...                 and `alert_type` is a second, connector-local translation
...                 (state_to_alert_type_mapping: host 0=info/1=error/2=warning,
...                 service 0=info/1=warning/2=error/3=warning).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-datadog.json
...                 connector_logfile=/var/log/centreon-broker/datadog-events-test.log
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
    Should Be Equal    ${down_event}[payload][title]    DOWN ${HOST}
    Should Be Equal    ${down_event}[payload][host]    ${HOST}
    Should Be Equal    ${down_event}[payload][alert_type]    error
    Should Contain    ${down_event}[payload][text]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][title]    UP ${HOST}
    Should Be Equal    ${up_event}[payload][alert_type]    info

Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][title]    WARNING ${HOST}: ${SERVICE_1}
    Should Be Equal    ${warning_event}[payload][alert_type]    warning

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal    ${critical_event}[payload][title]    CRITICAL ${HOST}: ${SERVICE_1}
    Should Be Equal    ${critical_event}[payload][alert_type]    error
    Should Contain    ${critical_event}[payload][text]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ok_event}[payload][title]    OK ${HOST}: ${SERVICE_1}
    Should Be Equal    ${ok_event}[payload][alert_type]    info

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][title]    CRITICAL ${HOST}: ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][title]    WARNING ${HOST}: ${SERVICE_2}

Acknowledging A Service Does Not Produce A Datadog Event
    [Documentation]    accepted_elements never includes acknowledgement (no format_event_acknowledgement
    ...                exists in this connector at all), so nothing is ever sent for one.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
