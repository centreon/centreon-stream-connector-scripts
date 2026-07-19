*** Settings ***
Documentation       Functional tests for centreon-certified/elasticsearch/elastic-events-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach (send_data_test writes the
...                 payload to the connector's own logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default).
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 Payload shape gotcha: unlike every other connector here, this one's send_data
...                 logs Elasticsearch bulk NDJSON - an index-action line, the event JSON, and a
...                 trailing blank line, all as ONE multi-line message (build_payload does
...                 `http_post_metadata .. '\\n' .. broker.json_encode(event) .. '\\n'`). EngineBroker.py's
...                 `_parse_send_data_block`/`_decode_all_json_values` handle this generically: they
...                 decode every JSON value found in the whole logged block and keep the *last* one -
...                 the bulk index-action object comes first, the real event second, so `${event}[payload]`
...                 is still the real event, same as every JSON-based connector.
...
...                 `state` here is the raw Centreon int (0-3), not translated - simpler assertions
...                 than most other connectors, which only expose a text-translated state.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-elastic.json
...                 connector_logfile=/var/log/centreon-broker/elastic-events-test.log
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
    Should Be Equal    ${down_event}[payload][event_type]    host
    Should Be Equal    ${down_event}[payload][host]    ${HOST}
    Should Be Equal    ${down_event}[payload][status]    DOWN
    Should Be Equal As Integers    ${down_event}[payload][state]    1
    Should Contain    ${down_event}[payload][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal    ${up_event}[payload][status]    UP
    Should Be Equal As Integers    ${up_event}[payload][state]    0

Service State Transitions Are Sent In Order With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][event_type]    service
    Should Be Equal    ${warning_event}[payload][host]    ${HOST}
    Should Be Equal    ${warning_event}[payload][service]    ${SERVICE_1}
    Should Be Equal    ${warning_event}[payload][status]    WARNING
    Should Be Equal As Integers    ${warning_event}[payload][state]    1

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Be Equal As Integers    ${critical_event}[payload][state]    2
    Should Contain    ${critical_event}[payload][output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal As Integers    ${ok_event}[payload][state]    0

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][service]    ${SERVICE_1}
    Should Be Equal As Integers    ${service_1_event}[payload][state]    2

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][service]    ${SERVICE_2}
    Should Be Equal As Integers    ${service_2_event}[payload][state]    1

Acknowledging A Service Does Not Produce An Elastic Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
