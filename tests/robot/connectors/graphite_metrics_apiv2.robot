*** Settings ***
Documentation       Functional tests for centreon-certified/graphite/graphite-metrics-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_metrics_apiv2.robot for the general metrics-testing approach (perfdata
...                 embedded in a normal host_status/service_status check result, no separate BBDO
...                 category needed).
...
...                 Unlike every other metrics connector here, this one talks Graphite's Carbon
...                 plaintext line protocol over a raw TCP socket (luasocket), not HTTP - but
...                 send_data_test=1 still short-circuits before any socket is opened, so the
...                 "address" parameter only has to satisfy the mandatory-parameter check and is
...                 never actually resolved/connected to.
...
...                 Payload shape gotcha: like clickhouse-metrics/influxdb2-metrics, this isn't JSON
...                 or XML - it's a Carbon tagged-metric line
...                 (`<metric_name>;host=<host>;poller=<poller>[;service=<service>];type=metric_value
...                 <value> <timestamp>`, see https://graphite.readthedocs.io/en/stable/tags.html#carbon).
...                 EngineBroker.py's `_parse_send_data_block` falls back to the raw string itself, so
...                 `${event}[payload]` here is a plain string checked with `Should Contain`.
...
...                 add_min_max_mode and add_thresholds_mode are both set to "as_metric" in this
...                 suite's broker config so their dedicated code paths (generate_min_max_metric_event,
...                 generate_thresholds_metric_event) get exercised at all - CTOR-2489 review found
...                 the ".min" line used a "," instead of ";" separator there, which the "Min And Max"
...                 test below asserts against directly. Both only fire when the incoming perfdata
...                 actually carries those fields (warn/crit/min/max), so the baseline tests below use
...                 single-field perfdata (no extra ";") to stay a single event, same as every other
...                 metrics suite. format_metric_event queues min/max/threshold lines *before* the base
...                 value line (see EventQueue:format_metric_event), which fixes the order asserted on
...                 below. add_state_metric is left at its default (0): unlike the other two modes it
...                 is not gated on perfdata content, so enabling it would add a ".state" line to every
...                 single test in this suite instead of just the ones that need it.
...
...                 Same `>` vs `>=` flush() off-by-one as most other connectors here - worked around
...                 with max_all_queues_age=0 and max_buffer_size=1 (default 1000).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-graphite-metrics.json
...                 connector_logfile=/var/log/centreon-broker/graphite-metrics-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Metric Is Sent With Correct Content
    Send Host Check Result    ${HOST}    0    OK - ping ok    perfdata=load=0.5
    ${metric_event}=    Wait For Sent Event
    Should Contain    ${metric_event}[payload]    load;host=${HOST}
    Should Contain    ${metric_event}[payload]    ;type=metric_value 0.5

Service Metric Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95
    ${metric_event}=    Wait For Sent Event
    Should Contain    ${metric_event}[payload]    used;host=${HOST}
    Should Contain    ${metric_event}[payload]    service=${SERVICE_1}
    Should Contain    ${metric_event}[payload]    ;type=metric_value 95

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95
    ${service_1_event}=    Wait For Sent Event
    Should Contain    ${service_1_event}[payload]    service=${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high    perfdata=used=70
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Contain    ${service_2_event}[payload]    service=${SERVICE_2}

Min And Max Metrics Are Sent As Separate Events When Enabled
    Send Host Check Result    ${HOST}    0    OK - ping ok    perfdata=load=0.5;;;0;5
    ${min_event}=    Wait For Sent Event
    Should Contain    ${min_event}[payload]    load.min;host=${HOST}
    Should Contain    ${min_event}[payload]    ;type=metric_min 0

    ${max_event}=    Wait For Sent Event    since_line=${min_event}[line]
    Should Contain    ${max_event}[payload]    load.max;host=${HOST}
    Should Contain    ${max_event}[payload]    ;type=metric_max 5

    ${value_event}=    Wait For Sent Event    since_line=${max_event}[line]
    Should Contain    ${value_event}[payload]    load;host=${HOST}
    Should Contain    ${value_event}[payload]    ;type=metric_value 0.5

Warning And Critical Threshold Metrics Are Sent As Separate Events When Enabled
    Send Host Check Result    ${HOST}    0    OK - ping ok    perfdata=load=0.5;1;2
    ${warning_event}=    Wait For Sent Event
    Should Contain    ${warning_event}[payload]    load.warning_threshold;host=${HOST}
    Should Contain    ${warning_event}[payload]    ;type=metric_warning_threshold 1

    ${critical_event}=    Wait For Sent Event    since_line=${warning_event}[line]
    Should Contain    ${critical_event}[payload]    load.critical_threshold;host=${HOST}
    Should Contain    ${critical_event}[payload]    ;type=metric_critical_threshold 2

    ${value_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Contain    ${value_event}[payload]    load;host=${HOST}
    Should Contain    ${value_event}[payload]    ;type=metric_value 0.5
