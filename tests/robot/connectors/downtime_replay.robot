*** Settings ***
Documentation       Exercises modules/centreon-stream-connectors-lib/sc_event.lua's downtime-replay
...                 mechanism (do not send a status-change event while it happens during a downtime;
...                 send it once the downtime ends, but only if the status actually differs from what
...                 it was before the downtime started) through
...                 centreon-certified/splunk/splunk-events-apiv2.lua. This is shared-library behaviour,
...                 not connector-specific formatting, so any apiv2 connector would exhibit it the same
...                 way - splunk is just the pilot connector.
...
...                 This needs storage_backend=sqlite (set in config/broker/central-broker.json) - the
...                 default "broker" backend is an intentional no-op placeholder
...                 (storage_backends/sc_storage_broker.lua: every read/write "succeeds" without
...                 persisting anything), which is why the shared config overrides it just for this
...                 output. storage_backend=sqlite itself needs the lua-lsqlite3 package (published in
...                 Centreon's rpm-plugins/apt-plugins repos, not rpm-standard/apt-standard - see each
...                 Dockerfile) - see the "Writing a new test" section in README_EN.md/README_FR.md for
...                 how the missing-package case was diagnosed before the package was published.
...
...                 enable_host_status_dedup/enable_service_status_dedup are left at their default
...                 (enabled): every test's baseline is preceded by a throwaway opposite-state check
...                 result instead, so the baseline is always a genuine transition and never silently
...                 dropped as a duplicate of whatever state the previous test case left the object in -
...                 see the "Writing a new test" section for why disabling dedup instead is the wrong fix
...                 (it also lets through harmless periodic status re-announcements that dedup is there
...                 to filter out, which broke the "nothing happens" test below).
...
...                 A host recovering to UP has also been observed making the connector send the exact
...                 same event twice in a row, milliseconds apart - `Wait For Sent Event`
...                 (tests/robot/resources/EngineBroker.py) coalesces immediate duplicates like this into
...                 one logical event so an unconsumed second copy is never mistaken later for a
...                 genuinely new event.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1


*** Keywords ***
Given A Service Baseline Of OK
    [Documentation]    Sends a throwaway CRITICAL first so the OK baseline that follows is always a
    ...                genuine transition, regardless of what state the previous test case left
    ...                service_1 in - otherwise dedup (enabled by default) would silently drop it.
    ...                Returns the baseline event (for use as a `since_line` reference).
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - throwaway to bypass dedup
    ${throwaway}=    Wait For Sent Event
    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - baseline before downtime
    ${baseline_event}=    Wait For Sent Event    since_line=${throwaway}[line]
    Should Be Equal As Integers    ${baseline_event}[payload][state]    0
    RETURN    ${baseline_event}

Given A Host Baseline Of UP
    [Documentation]    Same as `Given A Service Baseline Of OK`, for host_1 (throwaway DOWN, then UP).
    Send Host Check Result    ${HOST}    1    DOWN - throwaway to bypass dedup
    ${throwaway}=    Wait For Sent Event
    Send Host Check Result    ${HOST}    0    UP - baseline before downtime
    ${baseline_event}=    Wait For Sent Event    since_line=${throwaway}[line]
    Should Be Equal As Integers    ${baseline_event}[payload][state]    0
    RETURN    ${baseline_event}


*** Test Cases ***
No Status Change During Service Downtime Sends No Event After It Ends
    [Documentation]    Baseline OK, downtime starts, nothing happens, downtime is deleted -> no
    ...                status-change event should ever be sent, since sc_event never has anything
    ...                to replay (its stored broker_event is only ever set by an actual status change).
    ${baseline_event}=    Given A Service Baseline Of OK

    Schedule Service Downtime    ${HOST}    ${SERVICE_1}    duration_seconds=300
    Sleep    2s

    Delete Service Downtime    ${HOST}    ${SERVICE_1}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=5    since_line=${baseline_event}[line]

Service Status Returning To Baseline During Downtime Sends No Event After It Ends
    [Documentation]    OK -> WARNING -> OK, all *during* the downtime: the final state matches what it
    ...                was before the downtime started, so sc_event clears the held event instead of
    ...                keeping it - nothing should be sent once the downtime ends.
    ${baseline_event}=    Given A Service Baseline Of OK

    Schedule Service Downtime    ${HOST}    ${SERVICE_1}    duration_seconds=300
    Sleep    2s

    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - during downtime
    Sleep    1s
    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to baseline during downtime
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${baseline_event}[line]

    Delete Service Downtime    ${HOST}    ${SERVICE_1}
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=5    since_line=${baseline_event}[line]

Only The Final Service Status Change During Downtime Is Sent After It Ends
    [Documentation]    OK -> WARNING -> CRITICAL, all *during* the downtime: WARNING is held then
    ...                overwritten by CRITICAL (sc_event only ever keeps the latest divergent status),
    ...                so only one event - the CRITICAL one - should be sent once the downtime ends.
    ${baseline_event}=    Given A Service Baseline Of OK

    Schedule Service Downtime    ${HOST}    ${SERVICE_1}    duration_seconds=300
    Sleep    2s

    Send Service Check Result    ${HOST}    ${SERVICE_1}    1    WARNING - during downtime
    Sleep    1s
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full during downtime
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${baseline_event}[line]

    Delete Service Downtime    ${HOST}    ${SERVICE_1}
    ${replayed_event}=    Wait For Sent Event    since_line=${baseline_event}[line]
    Should Be Equal    ${replayed_event}[payload][event_type]    service
    Should Be Equal    ${replayed_event}[payload][service_description]    ${SERVICE_1}
    Should Be Equal As Integers    ${replayed_event}[payload][state]    2
    Should Contain    ${replayed_event}[payload][output]    disk full during downtime

    # Only one event should ever be sent (the CRITICAL one) - the held WARNING must
    # have been overwritten, not queued up behind it.
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${replayed_event}[line]

No Status Change During Host Downtime Sends No Event After It Ends
    [Documentation]    Same as the service test above, for a host downtime. Unlike services, ending a
    ...                host downtime has been observed making engine force a recheck that re-announces
    ...                the host's current, unchanged status a few seconds later - `Assert No Status
    ...                Change After` tolerates that harmless echo (still same state, not a change) but
    ...                fails immediately if anything reporting a *different* state ever shows up.
    ${baseline_event}=    Given A Host Baseline Of UP

    Schedule Host Downtime    ${HOST}    duration_seconds=300
    Sleep    2s

    Delete Host Downtime    ${HOST}
    Assert No Status Change After    since_line=${baseline_event}[line]    expected_state=0    timeout=8

Host Status Returning To Baseline During Downtime Sends No Event After It Ends
    [Documentation]    UP -> DOWN -> UP, all *during* the downtime: same as the service test above,
    ...                the final state matches the pre-downtime baseline so nothing is sent.
    ${baseline_event}=    Given A Host Baseline Of UP

    Schedule Host Downtime    ${HOST}    duration_seconds=300
    Sleep    2s

    Send Host Check Result    ${HOST}    1    DOWN - during downtime
    Sleep    1s
    Send Host Check Result    ${HOST}    0    UP - back to baseline during downtime
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${baseline_event}[line]

    Delete Host Downtime    ${HOST}
    Assert No Status Change After    since_line=${baseline_event}[line]    expected_state=0    timeout=8

Only The Final Host Status Change During Downtime Is Sent After It Ends
    [Documentation]    UP -> DOWN ("first outage reason") -> DOWN ("second outage reason"), all
    ...                *during* the downtime: the first DOWN is held then overwritten by the second
    ...                (sc_event only ever keeps the latest divergent status - see
    ...                `is_valid_event_downtime_state` in sc_event.lua: each divergent submission is
    ...                compared against the pre-downtime baseline, not the previously-held one, so the
    ...                latest write always wins), so once the downtime ends, only an event reporting the
    ...                *second* reason should ever be sent - never the first.
    ...
    ...                Unlike services, a host only has two states directly reachable through a passive
    ...                check result - UP and DOWN; UNREACHABLE is computed by engine itself from parent
    ...                host reachability, not something a check result can request directly (confirmed
    ...                empirically: submitting state 2 for a parent-less host here is recorded as state
    ...                1). This test demonstrates the same "overwrite, don't queue" behaviour with two
    ...                different DOWN outputs instead of a third state.
    ${baseline_event}=    Given A Host Baseline Of UP

    Schedule Host Downtime    ${HOST}    duration_seconds=300
    Sleep    2s

    Send Host Check Result    ${HOST}    1    DOWN - first outage reason
    Sleep    1s
    Send Host Check Result    ${HOST}    1    DOWN - second outage reason
    Run Keyword And Expect Error    No event sent by the connector*
    ...    Wait For Sent Event    timeout=3    since_line=${baseline_event}[line]

    Delete Host Downtime    ${HOST}
    ${replayed_event}=    Wait For Sent Event    since_line=${baseline_event}[line]
    Should Be Equal    ${replayed_event}[payload][event_type]    host
    Should Be Equal    ${replayed_event}[payload][hostname]    ${HOST}
    Should Be Equal As Integers    ${replayed_event}[payload][state]    1
    Should Contain    ${replayed_event}[payload][output]    second outage reason
    Should Not Contain    ${replayed_event}[payload][output]    first outage reason

    # No further event reporting the overwritten first reason should ever be sent - an
    # echo repeating the (already correct) second reason is still fine.
    Assert No Status Change After    since_line=${replayed_event}[line]    expected_state=1    timeout=5
