*** Settings ***
Documentation       Functional tests for
...                 centreon-certified/servicenow/servicenow-incident-events-apiv2.lua, run against a
...                 real centreon-engine + centreon-broker pair - see splunk_events_apiv2.robot for
...                 the general approach (send_data_test writes the payload to the connector's own
...                 logfile instead of a real HTTP call).
...
...                 accepted_elements is "host_status,service_status" (this connector's own default).
...                 No acknowledgement or downtime: neither format_event_acknowledgement nor
...                 format_event_downtime exists in this connector at all, so acknowledging a service
...                 produces no event, same as splunk_events_apiv2.robot's equivalent test.
...
...                 Same trailing-text-after-JSON logging gotcha as servicenow-em (see that suite's
...                 documentation) - handled generically by EngineBroker.py.
...
...                 There is no raw/translated `state`/`severity` field at all here - state only
...                 appears interpolated into `short_description` via the sc_params default text
...                 translation (UP/DOWN/UNREACHABLE, OK/WARNING/CRITICAL/UNKNOWN).
...
...                 Recoveries are never sent, by design: this connector overrides the generic
...                 `host_status`/`service_status` params (which filter which raw states are even
...                 considered valid, separate from `accepted_elements`' element-type filtering) to
...                 "1,2" and "1,2,3" respectively - excluding state 0 (UP/OK) entirely. Makes sense
...                 for an incident-management system: only problems open an incident, recoveries
...                 don't produce one here.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-servicenow-incident.json
...                 connector_logfile=/var/log/centreon-broker/servicenow-incident-events-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Down Produces An Event, Recovery To Up Does Not
    Send Host Check Result    ${HOST}    1    DOWN - no response to ping
    ${down_event}=    Wait For Sent Event
    Should Be Equal    ${down_event}[payload][cmdb_ci]    ${HOST}
    Should Contain    ${down_event}[payload][short_description]    DOWN ${HOST}
    Should Contain    ${down_event}[payload][comments]    DOWN - no response to ping

    Send Host Check Result    ${HOST}    0    UP - ping ok
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${down_event}[line]

Service State Transitions Are Sent In Order, Recovery To Ok Does Not
    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - load average high
    ${warning_event}=    Wait For Sent Event
    Should Be Equal    ${warning_event}[payload][cmdb_ci]    ${HOST}
    Should Contain    ${warning_event}[payload][short_description]    WARNING ${HOST} ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Contain    ${critical_event}[payload][short_description]    CRITICAL ${HOST} ${SERVICE_1}
    Should Contain    ${critical_event}[payload][comments]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Contain    ${service_1_event}[payload][short_description]    ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Contain    ${service_2_event}[payload][short_description]    ${SERVICE_2}

Acknowledging A Service Does Not Produce A ServiceNow Incident Event
    [Documentation]    No format_event_acknowledgement exists in this connector at all, so
    ...                acknowledging never produces an event.
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event

    Acknowledge Service    ${HOST}    ${SERVICE_2}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${critical_event}[line]
