*** Settings ***
Documentation       Functional tests for centreon-certified/keep/keep-events-apiv2.lua, run against
...                 a real centreon-engine + centreon-broker pair - see splunk_events_apiv2.robot for
...                 the general approach (send_data_test writes the payload to the connector's own
...                 logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status,acknowledgement" (this
...                 connector's own default - matches out of the box, no override needed). No
...                 downtime: no format_event_downtime exists in this connector at all.
...
...                 `status` is never a raw Centreon int nor sc_params' usual text translation - it's
...                 this connector's own state_host_keep/state_service_keep tables, mapping to
...                 KeepHQ's own vocabulary ("firing"/"resolved"/"pending"), independent of the
...                 sc_params default status_mapping other connectors use.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-keep.json
...                 connector_logfile=/var/log/centreon-broker/keep-events-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Down Then Recovery Are Sent As Distinct Events
    [Documentation]    Host state mapping (state_host_keep): 0=resolved, 1/2=firing.
    Send Host Check Result    ${HOST}    1    DOWN - no response to ping
    ${down_event}=    Wait For Sent Event
    Should Be Equal    ${down_event}[payload][name]    ${HOST}: firing
    Should Be Equal    ${down_event}[payload][status]    firing
    Should Contain    ${down_event}[payload][labels][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][name]    ${HOST}: resolved
    Should Be Equal    ${up_event}[payload][status]    resolved

Service State Transitions Are Sent In Order With Correct Content
    [Documentation]    Service state mapping (state_service_keep): 0=resolved, 1/2=firing.
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][name]    ${HOST}/${SERVICE_1}: firing
    Should Be Equal    ${warning_event}[payload][status]    firing

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal    ${critical_event}[payload][status]    firing
    Should Contain    ${critical_event}[payload][labels][output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ok_event}[payload][name]    ${HOST}/${SERVICE_1}: resolved
    Should Be Equal    ${ok_event}[payload][status]    resolved

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][name]    ${HOST}/${SERVICE_1}: firing

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][name]    ${HOST}/${SERVICE_2}: firing

Acknowledging A Critical Service Produces An Ack Event
    [Documentation]    format_event_acknowledgement marks status="acknowledged" (a distinct value
    ...                from firing/resolved/pending) and carries the ack's own author/comment rather
    ...                than the check's output.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event
    Should Be Equal    ${critical_event}[payload][status]    firing

    Acknowledge Service    ${HOST}    ${SERVICE_2}    author=robot    comment=ack from robot test
    ${ack_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ack_event}[payload][status]    acknowledged
    Should Be Equal    ${ack_event}[payload][name]    ${HOST}/${SERVICE_2}
    Should Be Equal    ${ack_event}[payload][labels][author]    robot
    Should Be Equal    ${ack_event}[payload][labels][comment_data]    ack from robot test
