*** Settings ***
Documentation       Exercises modules/centreon-stream-connectors-lib/sc_event.lua's downtime-replay
...                 mechanism (do not send a status-change event while it happens during a downtime;
...                 send it once the downtime ends) through centreon-certified/splunk/splunk-events-apiv2.lua.
...                 This is shared-library behaviour, not connector-specific formatting, so any apiv2
...                 connector would exhibit it the same way - splunk is just the pilot connector.
...
...                 This needs storage_backend=sqlite (set in config/broker/central-broker.json) - the
...                 default "broker" backend is an intentional no-op placeholder
...                 (storage_backends/sc_storage_broker.lua: every read/write "succeeds" without
...                 persisting anything), which is why the shared config overrides it just for this
...                 output. storage_backend=sqlite itself needs the lua-lsqlite3 package (published in
...                 Centreon's rpm-plugins/apt-plugins repos, not rpm-standard/apt-standard - see each
...                 Dockerfile) - see the "Writing a new test" section in README_EN.md/README_FR.md for
...                 how the missing-package case was diagnosed before the package was published.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1


*** Test Cases ***
Status Change During Downtime Is Held Then Replayed When Downtime Ends
    [Documentation]    1) baseline OK status (also seeds broker_cache with the "before downtime" state)
    ...                2) downtime starts
    ...                3) status changes to CRITICAL *during* the downtime -> must NOT be sent immediately
    ...                4) downtime is deleted -> the held CRITICAL change must now be sent
    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - baseline before downtime
    ${baseline_event}=    Wait For Sent Event
    Should Be Equal As Integers    ${baseline_event}[payload][state]    0

    Schedule Service Downtime    ${HOST}    ${SERVICE_1}    duration_seconds=300
    # Give broker time to receive and process the downtime-start BBDO event before
    # the status change below, since sc_event's replay logic keys off scheduled_downtime_depth.
    Sleep    2s

    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full during downtime
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${baseline_event}[line]

    Delete Service Downtime    ${HOST}    ${SERVICE_1}
    ${replayed_event}=    Wait For Sent Event    since_line=${baseline_event}[line]
    Should Be Equal    ${replayed_event}[payload][event_type]    service
    Should Be Equal    ${replayed_event}[payload][service_description]    ${SERVICE_1}
    Should Be Equal As Integers    ${replayed_event}[payload][state]    2
    Should Contain    ${replayed_event}[payload][output]    disk full during downtime
