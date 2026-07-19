*** Settings ***
Documentation       Functional tests for centreon-certified/logstash/logstash-events-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default).
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 `state` is the sc_params default text translation (UP/DOWN/UNREACHABLE,
...                 OK/WARNING/CRITICAL/UNKNOWN), not a raw Centreon int.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-logstash.json
...                 connector_logfile=/var/log/centreon-broker/logstash-events-test.log
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
    Should Be Equal    ${down_event}[payload][state]    DOWN
    Should Be Equal    ${down_event}[payload][title]    DOWN: ${HOST}
    Should Be Equal    ${down_event}[payload][hostname]    ${HOST}
    Should Contain    ${down_event}[payload][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][state]    UP
    Should Be Equal    ${up_event}[payload][title]    UP: ${HOST}

Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][state]    WARNING
    Should Be Equal    ${warning_event}[payload][title]    WARNING: ${HOST}, ${SERVICE_1}
    Should Be Equal    ${warning_event}[payload][service]    ${SERVICE_1}

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
    Should Be Equal    ${service_1_event}[payload][state]    CRITICAL

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][service]    ${SERVICE_2}
    Should Be Equal    ${service_2_event}[payload][state]    WARNING

Acknowledging A Service Does Not Produce A Logstash Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
