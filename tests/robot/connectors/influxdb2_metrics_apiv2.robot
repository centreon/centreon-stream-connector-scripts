*** Settings ***
Documentation       Functional tests for centreon-certified/influxdb/influxdb2-metrics-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair - see
...                 splunk_metrics_apiv2.robot for the general metrics-testing approach (perfdata
...                 embedded in a normal host_status/service_status check result, no separate BBDO
...                 category needed).
...
...                 Payload shape gotcha: like clickhouse-metrics, this isn't JSON or XML - it's raw
...                 InfluxDB line-protocol text (`<metric_name>,type=host,host.name=<host>,
...                 poller=<poller> value=<value> <timestamp>`, or with `type=service,
...                 service.name=<service>` added, for service metrics). EngineBroker.py's
...                 `_parse_send_data_block` falls back to the raw string itself, so
...                 `${event}[payload]` here is a plain string checked with `Should Contain`.
...
...                 Same `>` vs `>=` flush() off-by-one as most other connectors here - worked around
...                 with max_all_queues_age=0 and max_buffer_size=1 (default 5000).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-influxdb2.json
...                 connector_logfile=/var/log/centreon-broker/influxdb2-metrics-test.log
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
    Should Contain    ${metric_event}[payload]    load,type=host
    Should Contain    ${metric_event}[payload]    host.name=${HOST}
    Should Contain    ${metric_event}[payload]    value=0.5

Service Metric Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${metric_event}=    Wait For Sent Event
    Should Contain    ${metric_event}[payload]    used,type=service
    Should Contain    ${metric_event}[payload]    service.name=${SERVICE_1}
    Should Contain    ${metric_event}[payload]    host.name=${HOST}
    Should Contain    ${metric_event}[payload]    value=95

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${service_1_event}=    Wait For Sent Event
    Should Contain    ${service_1_event}[payload]    service.name=${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high    perfdata=used=70;60;90;0;100
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Contain    ${service_2_event}[payload]    service.name=${SERVICE_2}
