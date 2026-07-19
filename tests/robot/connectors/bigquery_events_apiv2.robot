*** Settings ***
Documentation       Functional tests for centreon-certified/google/bigquery-events-apiv2.lua, run
...                 against a real centreon-engine + centreon-broker pair - see
...                 splunk_events_apiv2.robot for the general approach.
...
...                 Unlike every other connector in this harness, this one required a real code
...                 change: it had no `send_data_test` support at all, and its `EventQueue:call` made
...                 an unconditional real Google OAuth token exchange (`self.sc_oauth:get_access_token()`
...                 - a signed JWT via the `openssl` Lua binding, then a real HTTPS call to Google)
...                 *before* ever touching curl for the actual BigQuery insertAll call - untestable
...                 without either real GCP credentials or code changes. Added the same
...                 `send_data_test` short-circuit every other connector already has, right at the top
...                 of `EventQueue:call`, before the OAuth call - logging the payload and returning
...                 `true`, exactly like the rest of this connector family. `EventQueue.new()`'s
...                 `self.sc_bq:get_tables_schema()` call is NOT a network call despite running
...                 unconditionally at init - it just builds schemas from local Lua tables
...                 (`_sc_gbq_use_default_schemas=1` is forced by this connector), so no init-time
...                 workaround was needed there.
...
...                 Needs the `lua-openssl` package (`modules/centreon-stream-connectors-lib/google/
...                 auth/oauth.lua` does `require("openssl")` unconditionally at load time, regardless
...                 of send_data_test) - added to the Dockerfile, published in the same
...                 `rpm-plugins`/`centreon-plugins-unstable` repo as `lua-lsqlite3`.
...
...                 A second, unrelated real bug surfaced immediately after fixing send_data_test:
...                 this connector never called `self.sc_params:build_accepted_elements_info()` (every
...                 other connector does, right after `check_params()`), so `sc_event.lua`'s
...                 constructor crashed on literally every single event with `bad argument #1 to 'for
...                 iterator' (table expected, got nil)` at
...                 `for accepted_element, info in pairs(self.params.accepted_elements_info) do` - this
...                 connector was completely non-functional in production too, not just untestable.
...                 Added the missing call - a one-line fix mirroring what every other apiv2 connector
...                 already does, not a design choice to second-guess.
...
...                 `accepted_categories`/`accepted_elements` are hardcoded by this connector
...                 (`params.accepted_categories = "neb,bam"`, no `or` fallback - any lua_parameter
...                 override is silently ignored) to `"neb,bam"` / "host_status,service_status,
...                 downtime,acknowledgement,ba_status" - broader than every other connector tested so
...                 far, and genuinely supports acknowledgement (no crash risk here: there's a single
...                 generic `format_event()` driven by a per-category/element schema table, not
...                 separate per-element formatting functions like canopsis, so there's no
...                 downtime-specific code path that could crash the way canopsis's did).
...
...                 Payload is a bare object matching BigQuery's real insertAll wire shape:
...                 `{"rows": [{"json": {...columns...}}]}` - `_extract_payload` unwraps `"rows"` (a
...                 one-element array, since max_buffer_size=1) but leaves the inner `"json"` key
...                 as-is, so assertions read `${event}[payload][json][field]`. Every field comes out
...                 of `sc_macros:replace_sc_macro`, which does string substitution - so even
...                 numeric-looking fields like `status`/`host_id` are JSON strings, not numbers.
...
...                 Unlike most other connectors in this harness, this one's own size-based flush
...                 check already uses `>=` (`modules/.../bigquery-events-apiv2.lua`'s `write()`,
...                 not the shared `sc_flush.lua`) - no `max_all_queues_age` workaround needed.

Library             OperatingSystem
Library             ../resources/EngineBroker.py

Suite Setup         Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-bigquery.json
...                 connector_logfile=/var/log/centreon-broker/bigquery-events-test.log
Suite Teardown      Stop Engine And Broker
Test Setup          Clear Connector Log


*** Variables ***
${HOST}              host_1
${SERVICE_1}         service_1
${SERVICE_2}         service_2


*** Test Cases ***
Host Status Is Sent With Correct Content
    Send Host Check Result    ${HOST}    1    DOWN - no response to ping
    ${down_event}=    Wait For Sent Event
    Should Be Equal    ${down_event}[payload][json][host_name]    ${HOST}
    Should Be Equal As Integers    ${down_event}[payload][json][status]    1
    Should Contain    ${down_event}[payload][json][output]    DOWN

    Send Host Check Result    ${HOST}    0    UP - ping ok
    ${up_event}=    Wait For Sent Event    since_line=${down_event}[line]
    Should Be Equal As Integers    ${up_event}[payload][json][status]    0

Service Status Is Sent With Correct Content
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event
    Should Be Equal    ${critical_event}[payload][json][host_name]    ${HOST}
    Should Be Equal    ${critical_event}[payload][json][service_description]    ${SERVICE_1}
    Should Be Equal As Integers    ${critical_event}[payload][json][status]    2
    Should Contain    ${critical_event}[payload][json][output]    disk full

    Send Service Check Result    ${HOST}    ${SERVICE_1}    0    OK - back to normal
    ${ok_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal As Integers    ${ok_event}[payload][json][status]    0

Two Independent Services Report Correctly In The Same Test
    Send Service Check Result    ${HOST}    ${SERVICE_1}    2    CRITICAL - disk full
    ${service_1_event}=    Wait For Sent Event
    Should Be Equal    ${service_1_event}[payload][json][service_description]    ${SERVICE_1}

    Send Service Check Result    ${HOST}    ${SERVICE_2}    1    WARNING - memory high
    ${service_2_event}=    Wait For Sent Event    since_line=${service_1_event}[line]
    Should Be Equal    ${service_2_event}[payload][json][service_description]    ${SERVICE_2}

Acknowledging A Critical Service Produces An Ack Event
    [Documentation]    Unlike most connectors in this harness, acknowledgement is genuinely
    ...                supported here (it's in accepted_elements by default, and the generic
    ...                format_event() has an ack schema) - carries the ack's own author rather than
    ...                the check's output.
    ...
    ...                Not asserting on `output`: `default_ack_table_schema()`
    ...                (modules/.../google/bigquery/bigquery.lua) maps it to the macro `{output}`,
    ...                but real Centreon acknowledgement BBDO events carry the ack comment in
    ...                `event.comment_data`, not `event.output` - so this macro never finds a value
    ...                and comes through as the literal, unsubstituted string `"{output}"` instead of
    ...                the comment. A genuine (if minor, non-crashing) schema inaccuracy in the shared
    ...                library, confirmed empirically - not fixed here, same as datadog-metrics'
    ...                host-metric crash (see that suite).
    Send Service Check Result    ${HOST}    ${SERVICE_2}    2    CRITICAL - disk full
    ${critical_event}=    Wait For Sent Event
    Should Be Equal As Integers    ${critical_event}[payload][json][status]    2

    Acknowledge Service    ${HOST}    ${SERVICE_2}    author=robot    comment=ack from robot test
    ${ack_event}=    Wait For Sent Event    since_line=${critical_event}[line]
    Should Be Equal    ${ack_event}[payload][json][author]    robot
    Should Be Equal    ${ack_event}[payload][json][host_name]    ${HOST}
    Should Be Equal    ${ack_event}[payload][json][service_description]    ${SERVICE_2}
