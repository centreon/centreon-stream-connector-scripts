*** Settings ***
Documentation       Functional tests for centreon-certified/datadog/datadog-metrics-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_metrics_apiv2.robot for the general metrics-testing approach (perfdata
...                 embedded in a normal host_status/service_status check result, no separate BBDO
...                 category needed).
...
...                 Payload matches Datadog's real `/api/v1/series` shape:
...                 `{"series": [{host, metric, points: [[timestamp, value]], tags: [...]}]}` -
...                 `_extract_payload` unwraps the `"series"` key (a one-element array, since
...                 max_buffer_size is 1 here) so `${event}[payload]` is directly the single series
...                 entry. `points` is `[[timestamp, value]]` - a one-element array of
...                 `[timestamp, value]` pairs, so the value itself is `${event}[payload][points][0][1]`.
...                 `tags` is a flat array of strings (`"service:<description>"` for service metrics
...                 only, `"instance:<x>"`/`"subinstance:<x>"` if present) - checked with `Should Contain`.
...
...                 Same `>` vs `>=` flush() off-by-one as most other connectors here - worked around
...                 with max_all_queues_age=0 and max_buffer_size=1 (default 30).
...
...                 No host metric test: this connector crashes on ANY host-level metric.
...                 `format_metric_event` (shared by format_metric_host/format_metric_service) calls
...                 `build_metadata`, which unconditionally does
...                 `if self.sc_event.event.cache.service.description then` to add a "service:..." tag
...                 - but `event.cache.service` is only ever populated by `sc_event.lua`'s
...                 `is_valid_service()`, which `sc_metrics.lua`'s `is_valid_host_metric_event` never
...                 calls (only `is_valid_service_metric_event` does, for actual service metrics).
...                 For a host metric, `event.cache.service` is `nil`, so this line crashes with
...                 "attempt to index a nil value (field 'service')" - confirmed in
...                 central-broker.log's `[lua] [error]` output, not just "no event sent". Every other
...                 metrics connector either never touches `cache.service` for host metrics, or (like
...                 elastic-metrics-apiv2.lua) only references it inside a function called
...                 exclusively for service metrics.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-datadog-metrics.json
...                 connector_logfile=/var/log/centreon-broker/datadog-metrics-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Service Metric Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${metric_event}=    Wait For Sent Event
    Should Be Equal    ${metric_event}[payload][host]    ${HOST}
    Should Be Equal    ${metric_event}[payload][metric]    used
    Should Be Equal As Numbers    ${metric_event}[payload][points][0][1]    95
    Should Contain    ${metric_event}[payload][tags]    service:${SERVICE_1}

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${service_1_event}=    Wait For Sent Event
    Should Contain    ${service_1_event}[payload][tags]    service:${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high    perfdata=used=70;60;90;0;100
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Contain    ${service_2_event}[payload][tags]    service:${SERVICE_2}
