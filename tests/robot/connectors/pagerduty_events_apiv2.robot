*** Settings ***
Documentation       Functional tests for centreon-certified/pagerduty/pagerduty-events-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default).
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 Field-nesting gotcha: this connector's own event structure has a field literally
...                 named "payload" (PagerDuty Events API v2's own envelope shape: routing_key,
...                 event_action, payload: {summary, severity, ...}, ...). EngineBroker.py's own
...                 wrapper also names its outer key "payload", so assertions here read
...                 `${event}[payload][payload][field]` - the first "payload" is EngineBroker.py's,
...                 the second is PagerDuty's own.
...
...                 `severity`/`event_action` come from a connector-local state_to_severity_mapping
...                 (0=info/resolve, 1=warning/trigger, 2=critical/trigger, 3=error/trigger) - not
...                 the sc_params default text translation other connectors use.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-pagerduty.json
...                 connector_logfile=/var/log/centreon-broker/pagerduty-events-test.log
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
    Should Be Equal    ${down_event}[payload][payload][summary]    ${HOST}: DOWN
    Should Be Equal    ${down_event}[payload][payload][severity]    warning
    Should Be Equal    ${down_event}[payload][payload][class]    host
    Should Be Equal    ${down_event}[payload][event_action]    trigger
    Should Be Equal    ${down_event}[payload][dedup_key]    1_H

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][payload][summary]    ${HOST}: UP
    Should Be Equal    ${up_event}[payload][payload][severity]    info
    Should Be Equal    ${up_event}[payload][event_action]    resolve

Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][payload][summary]    ${HOST}/${SERVICE_1}: WARNING
    Should Be Equal    ${warning_event}[payload][payload][severity]    warning
    Should Be Equal    ${warning_event}[payload][payload][class]    service

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal    ${critical_event}[payload][payload][severity]    critical
    Should Contain    ${critical_event}[payload][payload][custom_details][Output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ok_event}[payload][payload][severity]    info
    Should Be Equal    ${ok_event}[payload][event_action]    resolve

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][payload][summary]    ${HOST}/${SERVICE_1}: CRITICAL

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][payload][summary]    ${HOST}/${SERVICE_2}: WARNING

Acknowledging A Service Does Not Produce A PagerDuty Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
