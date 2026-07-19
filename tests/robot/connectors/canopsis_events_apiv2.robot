*** Settings ***
Documentation       Functional tests for centreon-certified/canopsis/canopsis2x-events-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 Uses its own broker config (config/broker/central-broker-canopsis.json) and its own
...                 connector logfile, passed explicitly to `Start Engine And Broker` - see
...                 tests/robot/resources/EngineBroker.py's `broker_config`/`connector_logfile`
...                 parameters.
...
...                 accepted_elements is deliberately "host_status,service_status,acknowledgement" -
...                 downtime is left out. Unlike splunk, this connector *does* format acknowledgement
...                 and downtime events (see format_event_acknowledgement/format_event_downtime), but
...                 enabling downtime here would also make EventQueue.new() call the real Canopsis API
...                 at init time (GET pbehavior-reasons/-types/app-info) to resolve
...                 canopsis_downtime_reason_id/canopsis_downtime_type_id - harmless under
...                 send_data_test (getCanopsisAPI/postCanopsisAPI short-circuit immediately, they don't
...                 hang or error), except canopsis_version then stays `false` (the boolean send_data_test
...                 short-circuit's return value) instead of a real version string, and
...                 format_event_downtime's `string.find(canopsis_version, "22.10.")` check crashes on a
...                 boolean instead of a string the moment an actual downtime event is formatted. Testing
...                 downtime for this connector needs that bug fixed (or canopsis_downtime_send_pbh=0 -
...                 set here - and confirming that alone is enough to dodge the crash) first.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-canopsis.json
...                 connector_logfile=/var/log/centreon-broker/canopsis-events-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Down Then Recovery Are Sent As Distinct Events
    [Documentation]    Two events sent in the same test, output checked after each one. Host state
    ...                mapping (EventQueue.centreon_to_canopsis_state) is {[0]=0, [1]=3, [2]=2} - Centreon
    ...                DOWN(1) becomes Canopsis state 3, not 1.
    Send Host Check Result    ${HOST}    1    DOWN - no response to ping
    ${down_event}=    Wait For Sent Event
    Should Be Equal    ${down_event}[payload][event_type]    check
    Should Be Equal    ${down_event}[payload][source_type]    component
    Should Be Equal    ${down_event}[payload][component]    ${HOST}
    Should Be Equal As Integers    ${down_event}[payload][state]    3
    Should Contain    ${down_event}[payload][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal As Integers    ${up_event}[payload][state]    0
    Should Contain    ${up_event}[payload][output]    UP

Service State Transitions Are Sent In Order With Correct Content
    [Documentation]    Three events (WARNING, CRITICAL, OK) sent in the same test. Service state mapping
    ...                is {[0]=0, [1]=1, [2]=3, [3]=2} - Centreon CRITICAL(2) becomes Canopsis state 3.
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][event_type]    check
    Should Be Equal    ${warning_event}[payload][source_type]    resource
    Should Be Equal    ${warning_event}[payload][component]    ${HOST}
    Should Be Equal    ${warning_event}[payload][resource]    ${SERVICE_1}
    Should Be Equal As Integers    ${warning_event}[payload][state]    1

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal As Integers    ${critical_event}[payload][state]    3
    Should Contain    ${critical_event}[payload][output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal As Integers    ${ok_event}[payload][state]    0

Two Independent Services Report Correctly In The Same Test
    [Documentation]    Two different services, checked after each send, to make sure events are not
    ...                mixed up between entities.
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][resource]    ${SERVICE_1}
    Should Be Equal As Integers    ${service_1_event}[payload][state]    3

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][resource]    ${SERVICE_2}
    Should Be Equal As Integers    ${service_2_event}[payload][state]    1

Acknowledging A Critical Service Produces An Ack Event
    [Documentation]    Unlike splunk-events-apiv2.lua (which has no acknowledgement formatting and so
    ...                never sends anything for one - see splunk_events_apiv2.robot), this connector
    ...                formats a dedicated "ack" event (format_event_acknowledgement), carrying the
    ...                acknowledgement's own author/comment rather than the check's output.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event
    Should Be Equal As Integers    ${critical_event}[payload][state]    3

    Acknowledge Service    ${HOST}    ${SERVICE_2}    author=robot    comment=ack from robot test
    ${ack_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ack_event}[payload][event_type]    ack
    Should Be Equal    ${ack_event}[payload][source_type]    resource
    Should Be Equal    ${ack_event}[payload][component]    ${HOST}
    Should Be Equal    ${ack_event}[payload][resource]    ${SERVICE_2}
    Should Be Equal    ${ack_event}[payload][author]    robot
    Should Contain    ${ack_event}[payload][output]    ack from robot test
