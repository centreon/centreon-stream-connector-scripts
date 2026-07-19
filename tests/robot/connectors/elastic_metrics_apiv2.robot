*** Settings ***
Documentation       Functional tests for centreon-certified/elasticsearch/elastic-metrics-apiv2.lua,
...                 run against a real centreon-engine + centreon-broker pair - see
...                 splunk_metrics_apiv2.robot for the general metrics-testing approach (perfdata
...                 embedded in a normal host_status/service_status check result, no separate BBDO
...                 category needed).
...
...                 Same bulk-NDJSON payload shape as elastic-events-apiv2.lua (see that suite's
...                 documentation) - handled generically by EngineBroker.py. Fields are fixed (unlike
...                 splunk-metrics' dynamic `metric_name:<name>` key): `@timestamp`, `host_name`,
...                 `metric_name`, `metric_value`, `metric_instance`, `metric_subinstances`,
...                 `metric_unit`, plus `service_description` for service metrics.
...
...                 Same `>` vs `>=` flush() off-by-one as most other connectors here - worked around
...                 with max_all_queues_age=0 and max_buffer_size=1 (default 30).

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-elastic-metrics.json
...                 connector_logfile=/var/log/centreon-broker/elastic-metrics-test.log
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
    Should Be Equal    ${metric_event}[payload][host_name]    ${HOST}
    Should Be Equal    ${metric_event}[payload][metric_name]    load
    Should Be Equal As Numbers    ${metric_event}[payload][metric_value]    0.5

Service Metric Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${metric_event}=    Wait For Sent Event
    Should Be Equal    ${metric_event}[payload][host_name]    ${HOST}
    Should Be Equal    ${metric_event}[payload][service_description]    ${SERVICE_1}
    Should Be Equal    ${metric_event}[payload][metric_name]    used
    Should Be Equal As Numbers    ${metric_event}[payload][metric_value]    95

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full    perfdata=used=95;80;90;0;100
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][service_description]    ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high    perfdata=used=70;60;90;0;100
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][service_description]    ${SERVICE_2}
