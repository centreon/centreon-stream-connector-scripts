*** Settings ***
Resource          ../../variables.robot
Library           Process
Library           String

*** Variables ***
${CONNECTOR}    ${CONNECTORS_DIR}/datadog/datadog-events-apiv2.lua
${EVENTS_DIR}   ${CURDIR}/events

*** Test Cases ***
Service CRITICAL should produce a valid Datadog payload
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/service_critical.json
    ...    api_key\=fake_key
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    [send_data]:
    Should Contain    ${result.stdout}    CRITICAL

Host DOWN should produce a valid Datadog payload
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/host_down.json
    ...    api_key\=fake_key
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    [send_data]:
    Should Contain    ${result.stdout}    mock-host-1

Service OK should be dropped when service_status filter only accepts CRITICAL
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/service_ok.json
    ...    api_key\=fake_key    service_status\=2
    Should Be Equal As Integers    ${result.rc}    0
    Should Not Contain    ${result.stdout}    [send_data]:
