*** Settings ***
Documentation       Functional tests for centreon-certified/opsgenie/opsgenie-events-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default).
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 There is no raw/translated `state` field at all - state only appears interpolated
...                 into `message` (which also has a timestamp prefix, so only `Should Contain` is
...                 used on it) and `alias` (host_state or host_service_state, no timestamp - exact
...                 match works).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-opsgenie.json
...                 connector_logfile=/var/log/centreon-broker/opsgenie-events-test.log
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
    Should Be Equal    ${down_event}[payload][alias]    ${HOST}_DOWN
    Should Contain    ${down_event}[payload][message]    ${HOST} is DOWN
    Should Contain    ${down_event}[payload][description]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][alias]    ${HOST}_UP
    Should Contain    ${up_event}[payload][message]    ${HOST} is UP

Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][alias]    ${HOST}_${SERVICE_1}_WARNING
    Should Contain    ${warning_event}[payload][message]    ${HOST} // ${SERVICE_1} is WARNING

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal    ${critical_event}[payload][alias]    ${HOST}_${SERVICE_1}_CRITICAL
    Should Contain    ${critical_event}[payload][description]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ok_event}[payload][alias]    ${HOST}_${SERVICE_1}_OK

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][alias]    ${HOST}_${SERVICE_1}_CRITICAL

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][alias]    ${HOST}_${SERVICE_2}_WARNING

Acknowledging A Service Does Not Produce An Opsgenie Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
