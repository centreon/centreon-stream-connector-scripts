*** Settings ***
Documentation       Functional tests for centreon-certified/splunk/splunk-metrics-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair.
...
...                 Unlike splunk-events-apiv2.lua, this connector reads performance data, not
...                 status changes - but there is no separate BBDO category for metrics: it still
...                 reads host_status/service_status events (accepted_categories/elements default to
...                 "neb"/"host_status,service_status", same as every events connector), and pulls
...                 metrics out of the SAME event's embedded Nagios-style perfdata string via
...                 `broker.parse_perfdata()` (modules/centreon-stream-connectors-lib/sc_metrics.lua).
...                 `Send Host/Service Check Result`'s optional `perfdata` argument appends
...                 `|perfdata` to the check output, matching what engine expects at the end of any
...                 check result line. `process_performance_data=1` in centengine.cfg is required for
...                 this to reach broker at all - flipped from the default 0 (harmless for every
...                 other suite, which doesn't use perfdata).
...
...                 Payload is Splunk HEC format like splunk-events-apiv2.lua, but nests under a
...                 `"fields"` key instead of `"event"` - handled by `_extract_payload` alongside the
...                 other known wrapper shapes. Inside `fields`, the metric name/value pair is a
...                 *dynamic* key: `"metric_name:<name>"` (e.g. `metric_name:load`), not a fixed field
...                 - so assertions here index `${event}[payload][metric_name:<name>]` rather than a
...                 stable key name.
...
...                 Same `>` vs `>=` off-by-one in this connector's own hand-rolled flush() as most
...                 *-events-apiv2.lua connectors (see their suites' documentation) - worked around
...                 with max_all_queues_age=0. max_buffer_size is also lowered to 1 (default 30) so
...                 each metric flushes as its own event instead of batching several together.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-splunk-metrics.json
...                 connector_logfile=/var/log/centreon-broker/splunk-metrics-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Metric Is Sent With Correct Content
    Send Host Check Result    ${HOST}    0    OK - ping ok    perfdata=load=0.5;1;2;0;5
    ${metric_event}=    Wait For Sent Event
    Should Be Equal    ${metric_event}[payload][event_type]    host
    Should Be Equal    ${metric_event}[payload][hostname]    ${HOST}
    Should Be Equal As Integers    ${metric_event}[payload][state]    0
    Should Be Equal As Numbers    ${metric_event}[payload][metric_name:load]    0.5

Service Metric Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${metric_event}=    Wait For Sent Event
    Should Be Equal    ${metric_event}[payload][event_type]    service
    Should Be Equal    ${metric_event}[payload][hostname]    ${HOST}
    Should Be Equal    ${metric_event}[payload][service_description]    ${SERVICE_1}
    Should Be Equal As Integers    ${metric_event}[payload][state]    2
    Should Be Equal As Numbers    ${metric_event}[payload][metric_name:used]    95

Multiple Metrics In One Check Are Each Sent As A Separate Event
    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - normal    perfdata=metric_a=1;;;; metric_b=2;;;;
    ${first_metric}=    Wait For Sent Event
    Should Be True    "metric_name:metric_a" in ${first_metric}[payload] or "metric_name:metric_b" in ${first_metric}[payload]

    ${second_metric}=    Wait For Sent Event    since_line=${first_metric}[line]
    Should Not Be Equal    ${first_metric}[payload]    ${second_metric}[payload]

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][service_description]    ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high    perfdata=used=70;60;90;0;100
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][service_description]    ${SERVICE_2}
