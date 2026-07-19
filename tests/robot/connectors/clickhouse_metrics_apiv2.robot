*** Settings ***
Documentation       Functional tests for centreon-certified/clickhouse/clickhouse-metrics-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair - see
...                 splunk_metrics_apiv2.robot for the general metrics-testing approach (perfdata
...                 embedded in a normal host_status/service_status check result, no separate BBDO
...                 category needed).
...
...                 Payload shape gotcha: this connector's payload isn't JSON or XML at all - it's a
...                 raw SQL string (`INSERT INTO centreon_stream.metrics (host, timestamp, metric_name,
...                 metric_value, service, hostgroups, metric_id, metric_unit, metric_min, metric_max)
...                 VALUES ('host_1',...),(...)`). EngineBroker.py's `_parse_send_data_block` falls
...                 back to the raw string itself when a block parses as neither JSON nor XML, so
...                 `${event}[payload]` here is a plain string - assertions use `Should Contain`
...                 instead of dict-key access. `metric_id` (the column, not a BBDO concept) is
...                 `<host_id>-<metric_name>` for host metrics, `<host_id>-<service_id>-<metric_name>`
...                 for service metrics (host_1/service_1/service_2 have host_id=1/service_id=1/2 per
...                 tests/robot/config/engine/{hosts,services}.cfg's _HOST_ID/_SERVICE_ID).
...
...                 Same `>` vs `>=` flush() off-by-one as most other connectors here - worked around
...                 with max_all_queues_age=0 and max_buffer_size=1 (default 1000).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-clickhouse.json
...                 connector_logfile=/var/log/centreon-broker/clickhouse-metrics-test.log
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
    Should Contain    ${metric_event}[payload]    INSERT INTO centreon_stream.metrics
    Should Contain    ${metric_event}[payload]    '${HOST}',
    Should Contain    ${metric_event}[payload]    'load',0.5
    Should Contain    ${metric_event}[payload]    '1-load'

Service Metric Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${metric_event}=    Wait For Sent Event
    Should Contain    ${metric_event}[payload]    '${HOST}',
    Should Contain    ${metric_event}[payload]    'used',95
    Should Contain    ${metric_event}[payload]    '${SERVICE_1}'
    Should Contain    ${metric_event}[payload]    '1-1-used'

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${service_1_event}=    Wait For Sent Event
    Should Contain    ${service_1_event}[payload]    '1-1-used'

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high    perfdata=used=70;60;90;0;100
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Contain    ${service_2_event}[payload]    '1-2-used'
