*** Settings ***
Documentation       Functional tests for centreon-certified/splunk/splunk-events-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair.
...                 The connector's `send_data_test` parameter makes it write the JSON
...                 payload it would have POSTed to Splunk into its own logfile instead
...                 of making a real HTTP call (see modules/centreon-stream-connectors-lib/sc_params.lua).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Down Then Recovery Are Sent As Distinct Events
    [Documentation]    Two events sent in the same test, output checked after each one.
    Send Host Check Result    ${HOST}    1    DOWN - no response to ping
    ${down_event}=    Wait For Sent Event
    Should Be Equal    ${down_event}[payload][event_type]    host
    Should Be Equal As Integers    ${down_event}[payload][state]    1
    Should Be Equal    ${down_event}[payload][hostname]    ${HOST}
    Should Contain    ${down_event}[payload][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal As Integers    ${up_event}[payload][state]    0
    Should Contain    ${up_event}[payload][output]    UP

Service State Transitions Are Sent In Order With Correct Content
    [Documentation]    Three events (WARNING, CRITICAL, OK) sent in the same test.
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][event_type]    service
    Should Be Equal As Integers    ${warning_event}[payload][state]    1
    Should Be Equal    ${warning_event}[payload][service_description]    ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal As Integers    ${critical_event}[payload][state]    2
    Should Contain    ${critical_event}[payload][output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal As Integers    ${ok_event}[payload][state]    0

Two Independent Services Report Correctly In The Same Test
    [Documentation]    Two different services, checked after each send, to make sure
    ...                events are not mixed up between entities.
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][service_description]    ${SERVICE_1}
    Should Be Equal As Integers    ${service_1_event}[payload][state]    2

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][service_description]    ${SERVICE_2}
    Should Be Equal As Integers    ${service_2_event}[payload][state]    1

Acknowledging A Service Does Not Produce A Splunk Event
    [Documentation]    accepted_elements is set to "host_status,service_status" only
    ...                (see tests/robot/config/broker/central-broker.json), so an
    ...                acknowledgement is received by the connector but filtered out
    ...                before it reaches send_data - no payload should be sent for it.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
