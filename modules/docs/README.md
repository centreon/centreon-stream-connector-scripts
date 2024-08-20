# Stream Connectors lib documentation

- [Stream Connectors lib documentation](#stream-connectors-lib-documentation)
  - [Libraries list](#libraries-list)
  - [sc\_common methods](#sc_common-methods)
  - [sc\_logger methods](#sc_logger-methods)
  - [sc\_broker methods](#sc_broker-methods)
  - [sc\_param methods](#sc_param-methods)
  - [sc\_event methods](#sc_event-methods)
  - [sc\_macros methods](#sc_macros-methods)
  - [sc\_flush methods](#sc_flush-methods)
  - [sc\_metrics methods](#sc_metrics-methods)
  - [google.bigquery.bigquery methods](#googlebigquerybigquery-methods)
  - [google.auth.oauth methods](#googleauthoauth-methods)
  - [Additionnal documentations](#additionnal-documentations)

## Libraries list

| Lib name                 | Content                                          | Usage                                                                     | Documentation                                |
| ------------------------ | ------------------------------------------------ | ------------------------------------------------------------------------- | -------------------------------------------- |
| sc_common                | basic methods for lua                            | you can use it when you want to simplify your code                        | [Documentation](sc_common.md)                |
| sc_logger                | methods that handle logging with centreon broker | When you want to log a message from your stream connector                 | [Documentation](sc_logger.md)                |
| sc_broker                | wrapper methods for broker cache                 | when you need something from the broker cache                             | [Documentation](sc_broker.md)                |
| sc_param                 | handles parameters for stream connectors         | when you want to initiate a stream connector with all standard parameters | [Documentation](sc_param.md)                 |
| sc_event                 | methods to help you interact with a broker event | when you want to check event data                                         | [Documentation](sc_event.md)                 |
| sc_macros                | methods to help you convert macros               | when you want to use macros in your stream connector                      | [Documentation](sc_macros.md)                |
| sc_flush                 | methods to help you handle queues of event       | when you want to flush queues of various kind of events                   | [Documentation](sc_flush.md)                 |
| sc_metrics               | methods to help you handle metrics               | when you want to send metrics and not just events                         | [Documentation](sc_metrics.md)               |
| google.bigquery.bigquery | methods to help you handle bigquery data         | when you want to generate tables schema for bigquery                      | [Documentation](google/bigquery/bigquery.md) |
| google.auth.oauth        | methods to help you authenticate to google api   | when you want to authenticate yourself on the google api                  | [Documentation](google/auth/oauth.md)        |

## sc_common methods

| Method name                        | Method description                                                                                              | Link                                                                    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| ifnil_or_empty                     | check if a variable is empty or nil and replace it with a default value if it is the case                       | [Documentation](sc_common.md#ifnil_or_empty-method)                     |
| if_wrong_type                      | check the type of a variable, if it is wrong, replace the variable with a default value                         | [Documentation](sc_common.md#if_wrong_type-method)                      |
| boolean_to_number                  | change a true/false boolean to a 1/0 value                                                                      | [Documentation](sc_common.md#boolean_to_number-method)                  |
| number_to_boolean                  | change a 0/1 number to a false/true value                                                                       | [Documentation](sc_common.md#number_to_boolean-method)                  |
| check_boolean_number_option_syntax | make sure that a boolean is 0 or 1, if that's not the case, replace it with a default value                     | [Documentation](sc_common.md#check_boolean_number_option_syntax-method) |
| split                              | split a string using a separator (default is ",") and store each part in a table                                | [Documentation](sc_common.md#split-method)                              |
| compare_numbers                    | compare two numbers using the given mathematical operator and return true or false                              | [Documentation](sc_common.md#compare_numbers-method)                    |
| generate_postfield_param_string    | convert a table of parameters into a URL encoded parameter string                                             | [Documentation](sc_common.md#generate_postfield_param_string-method)    |
| load_json_file                     | the method loads a json file and parses it                                                                           | [Documentation](sc_common.md#load_json_file-method)                     |
| json_escape                        | escape json characters in a string                                                                              | [Documentation](sc_common.md#json_escape-method)                        |
| xml_escape                         | escape xml characters in a string                                                                               | [Documentation](sc_common.md#xml_escape-method)                         |
| lua_regex_escape                   | escape lua regex special characters in a string                                                                 | [Documentation](sc_common.md#lua_regex_escape-method)                   |
| dumper                             | dump any variable for debug purposes                                                                             | [Documentation](sc_common.md#dumper-method)                             |
| trim                               | trim spaces (or provided character) at the beginning and the end of a string                                    | [Documentation](sc_common.md#trim-method)                               |
| get_bbdo_version                   | returns the first digit of the bbdo protocol version                                                            | [Documentation](sc_common.md#get_bbdo_version-method)                   |
| is_valid_pattern                   | check if a Lua pattern is valid                                                                                 | [Documentation](sc_common.md#is_valid_pattern-method)                   |
| sleep                              | wait a given number of seconds                                                                                  | [Documentation](sc_common.md#sleep-method)                              |
| create_sleep_counter_table         | create a table to handle sleep counters. Useful when you want to log something less often after some repetitions | [Documentation](sc_common.md#create_sleep_counter_table-method)         |

## sc_logger methods

| Method name      | Method description                                    | Link                                                  |
| ---------------- | ----------------------------------------------------- | ----------------------------------------------------- |
| error            | write an error message in the log file                | [Documentation](sc_logger.md#error-method)            |
| warning          | write a warning message in the log file               | [Documentation](sc_logger.md#warning-method)          |
| notice           | write a notice/info message in the log file           | [Documentation](sc_logger.md#notice-method)           |
| info             | write an info message in the log file                 | [Documentation](sc_logger.md#info-method)             |
| debug            | write a debug message in the log file                 | [Documentation](sc_logger.md#debug-method)            |
| log_curl_command | creates and log a curl command using given parameters | [Documentation](sc_logger.md#log_curl_command-method) |

## sc_broker methods

| Method name           | Method description                                                               | Link                                                       |
| --------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| get_host_all_infos    | retrieve all informations about a host from the broker cache                     | [Documentation](sc_broker.md#get_host_all_infos-method)    |
| get_service_all_infos | retrieve all informations about a service from the broker cache                  | [Documentation](sc_broker.md#get_service_all_infos-method) |
| get_host_infos        | retrieve one or more specific informations about a host from the broker cache    | [Documentation](sc_broker.md#get_host_infos-method)        |
| get_service_infos     | retrieve one or more specific informations about a service from the broker cache | [Documentation](sc_broker.md#get_service_infos-method)     |
| get_hostgroups        | retrieve the hostgroups linked to a host from the broker cache                   | [Documentation](sc_broker.md#get_hostgroups-method)        |
| get_servicegroups     | retrieve the servicegroups linked to a service from the broker cache             | [Documentation](sc_broker.md#get_servicegroups-method)     |
| get_severity          | retrieve the severity of a host or a service from the broker cache               | [Documentation](sc_broker.md#get_severity-method)          |
| get_instance          | retrieve the name of the poller using the instance id from the broker cache      | [Documentation](sc_broker.md#get_instance-method)          |
| get_ba_infos          | retrieve the name and description of a BA from the broker cache                  | [Documentation](sc_broker.md#get_ba_infos-method)          |
| get_bvs_infos         | retrieve the name and description of all BV linked to a BA                       | [Documentation](sc_broker.md#get_bvs_infos-method)         |

## sc_param methods

| Method name                        | Method description                                                                                                                            | Link                                                                   |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| param_override                     | replace default values of params with the ones provided by users in the web configuration of the stream connector                             | [Documentation](sc_param.md#param_override-method)                     |
| check_params                       | make sure that the default stream connector params provided by the user from the web configuration are valid. If not, uses the default value | [Documentation](sc_param.md#check_params-method)                       |
| is_mandatory_config_set            | check that all mandatory parameters for a stream connector are set                                                                            | [Documentation](sc_param.md#is_mandatory_config_set-method)            |
| get_kafka_params                   | retreive Kafka dedicated parameters from the parameter list and put them in the provided kafka_config object                                  | [Documentation](sc_param.md#get_kafka_params-method)                   |
| load_event_format_file             | load a file that serves as a template for formatting events                                                                                   | [Documentation](sc_param.md#load_event_format_file-method)             |
| build_accepted_elements_info       | build a table that store information about accepted elements                                                                                  | [Documentation](sc_param.md#build_accepted_elements_info-method)       |
| validate_pattern_param             | check if a parameter has a valid Lua pattern as a value                                                                                       | [Documentation](sc_param.md#validate_pattern_param-method)             |
| build_and_validate_filters_pattern | build a table that stores information about patterns for compatible parameters                                                                | [Documentation](sc_param.md#build_and_validate_filters_pattern-method) |

## sc_event methods

| Method name                        | Method description                                                                                                                                           | Link                                                                   |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| is_valid_category                  | check if the category of the event is accepted according to the stream connector params                                                                      | [Documentation](sc_event.md#is_valid_category-method)                  |
| is_valid_element                   | check if the element of the event is accepted according to the stream connector params                                                                       | [Documentation](sc_event.md#is_valid_element-method)                   |
| is_valid_event                     | check if the event is valid according to the stream connector params                                                                                         | [Documentation](sc_event.md#is_valid_event-method)                     |
| is_valid_neb_event                 | check if the neb event is valid according to the stream connector params                                                                                     | [Documentation](sc_event.md#is_valid_neb_event-method)                 |
| is_valid_host_status_event         | check the "host status" event is valid according to the stream connector params                                                                              | [Documentation](sc_event.md#is_valid_host_status_event-method)         |
| is_valid_service_status_event      | check the "servce status" event is valid according to the stream connector params                                                                            | [Documentation](sc_event.md#is_valid_service_status_event-method)      |
| is_valid_host                      | check if the host name and/or ID are valid according to the stream connector params                                                                          | [Documentation](sc_event.md#is_valid_host-method)                      |
| is_valid_service                   | check if the service description and/or ID are are valid according to the stream connector params                                                            | [Documentation](sc_event.md#is_valid_service-method)                   |
| is_valid_event_states              | check if the state (HARD/SOFT), acknowledgement state and downtime state are valid according to the stream connector params                                  | [Documentation](sc_event.md#is_valid_event_states-method)              |
| is_valid_event_status              | check if the status (OK, DOWN...) of the event is valid according to the stream connector params                                                             | [Documentation](sc_event.md#is_valid_event_status-method)              |
| is_valid_event_state_type          | check if the state (HARD/SOFT) of the event is valid according to the stream connector params                                                                | [Documentation](sc_event.md#is_valid_event_state_type-method)          |
| is_valid_event_acknowledge_state   | check if the acknowledgement state of the event is valid according to the stream connector params                                                            | [Documentation](sc_event.md#is_valid_event_acknowledge_state-method)   |
| is_valid_event_downtime_state      | check if the downtime state of the event is valid according to the stream connector params                                                                   | [Documentation](sc_event.md#is_valid_event_downtime_state-method)      |
| is_valid_event_flapping_state      | check if the flapping state of the event is valid according to the stream connector params                                                                   | [Documentation](sc_event.md#is_valid_event_flapping_state-method)      |
| is_valid_hostgroup                 | check if the host is in an accepted hostgroup according to the stream connector params                                                                       | [Documentation](sc_event.md#is_valid_hostgroup-method)                 |
| find_hostgroup_in_list             | check if one of the hostgroups of the event is in the list of accepted hostgroups provided in the stream connector configuration. Stops at first match       | [Documentation](sc_event.md#find_hostgroup_in_list-method)             |
| is_valid_servicegroup              | check if the service is in an accepted servicegroup according to the stream connector params                                                                 | [Documentation](sc_event.md#is_valid_servicegroup-method)              |
| find_servicegroup_in_list          | check if one of the servicegroups of the event is in the list of accepted servicegroups provided in the stream connector configuration. Stops at first match | [Documentation](sc_event.md#find_servicegroup_in_list-method)          |
| is_valid_bam_event                 | check if the BAM event is valid according to the stream connector params                                                                                     | [Documentation](sc_event.md#is_valid_bam_event-method)                 |
| is_valid_ba                        | check if the BA name and/or ID are are valid according to the stream connector params                                                                        | [Documentation](sc_event.md#is_valid_ba-method)                        |
| is_valid_ba_status_event           | check if the "ba status" (OK, WARNING, CRITICAL) event is valid according to the stream connector params                                                     | [Documentation](sc_event.md#is_valid_ba_status_event-method)           |
| is_valid_ba_downtime_state         | check if the BA downtime state is valid according to the stream connector params                                                                             | [Documentation](sc_event.md#is_valid_ba_downtime_state-method)         |
| is_valid_ba_acknowledge_state      | DOES NOTHING                                                                                                                                                 | [Documentation](sc_event.md#is_valid_ba_acknowledge_state-method)      |
| is_valid_bv                        | check if the BA is in an accepted BV according to the stream connector params                                                                                | [Documentation](sc_event.md#is_valid_bv-method)                        |
| find_bv_in_list                    | check if one of the BV of the event is in the list of accepted BV provided in the stream connector configuration. Stops at first match                       | [Documentation](sc_event.md#find_bv_in_list-method)                    |
| is_valid_poller                    | check if the host is monitored from an accepted poller according to the stream connector params                                                              | [Documentation](sc_event.md#is_valid_poller-method)                    |
| find_poller_in_list                | check if the poller that monitores the host is in the list of accepted pollers provided in the stream connector configuration. Stops at first match          | [Documentation](sc_event.md#find_poller_in_list-method)                |
| is_valid_host_severity             | check if a host has a valid severity                                                                                                                         | [Documentation](sc_event.md#is_valid_host_severity-method)             |
| is_valid_service_severity          | check if a service has a valid severity                                                                                                                      | [Documentation](sc_event.md#is_valid_service_severity-method)          |
| is_valid_acknowledgement_event     | check if the acknowledgement event is valid                                                                                                                  | [Documentation](sc_event.md#is_valid_acknowledgement_event-method)     |
| is_valid_author                    | check if the author of a comment is accepted                                                                                                                 | [Documentation](sc_event.md#is_valid_author-method)                    |
| is_valid_downtime_event            | check if the downtime event is valid                                                                                                                         | [Documentation](sc_event.md#is_valid_downtime_event-method)            |
| is_host_status_event_duplicated    | check if the host_status event is duplicated                                                                                                                 | [Documentation](sc_event.md#is_host_status_event_duplicated-method)    |
| is_service_status_event_duplicated | check if the service_status event is duplicated                                                                                                              | [Documentation](sc_event.md#is_service_status_event_duplicated-method) |
| is_downtime_event_useless          | checks if the downtime event is a usefull one. Meaning that it carries valuable data regarding the actual end or start of the downtime                       | [Documentation](sc_event.md#is_downtime_event_useless-method)          |
| is_valid_downtime_event_start      | checks that the downtime event is about the actual start of the downtime                                                                                     | [Documentation](sc_event.md#is_valid_downtime_event_start-method)      |
| is_valid_downtime_event_end        | checks that the downtime event is about the actual end of the downtime                                                                                       | [Documentation](sc_event.md#is_valid_downtime_event_end-method)        |
| is_valid_storage_event             | DO NOTHING (deprecated, you should use neb event to send metrics)                                                                                            | [Documentation](sc_event.md#is_valid_storage_event-method)             |

## sc_macros methods

| Method name                                      | Method description                                                                      | Link                                                                                  |
| ------------------------------------------------ | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| replace_sc_macro                                 | replace a stream connector macro with its value                                         | [Documentation](sc_macros.md#replace_sc_macro-method)                                 |
| get_cache_macro                                  | retrieve a macro value in the cache                                                     | [Documentation](sc_macros.md#get_cache_macro-method)                                  |
| get_event_macro                                  | retrieve a macro value in the event                                                     | [Documentation](sc_macros.md#get_event_macro-method)                                  |
| get_group_macro                                  | retrieve a macro from groups (hostgroups, servicegroups, business views)                | [Documentation](sc_macros.md#get_group_macro-method)                                  |
| convert_centreon_macro                           | replace a Centreon macro with its value                                                 | [Documentation](sc_macros.md#convert_centreon_macro-method)                           |
| get_centreon_macro                               | transform a Centreon macro into a stream connector macro                                | [Documentation](sc_macros.md#get_centreon_macro-method)                               |
| get_transform_flag                               | try to find a transformation flag in the macro name                                     | [Documentation](sc_macros.md#get_transform_flag-method)                               |
| transform_date                                   | transform a timestamp into a human readable format                                      | [Documentation](sc_macros.md#transform_date-method)                                   |
| transform_short                                  | keep the first line of a string                                                         | [Documentation](sc_macros.md#transform_short-method)                                  |
| transform_type                                   | convert 0 or 1 into SOFT or HARD                                                        | [Documentation](sc_macros.md#transform_type-method)                                   |
| transform_state                                  | convert a status code into its matching human readable status (OK, WARNING...)          | [Documentation](sc_macros.md#transform_state-method)                                  |
| transform_number                                 | convert a string into a number                                                          | [Documentation](sc_macros.md#transform_number-method)                                 |
| transform_string                                 | convert anything into a string                                                          | [Documentation](sc_macros.md#transform_string-method)                                 |
| get_hg_macro                                     | retrieves hostgroup information and make it available as a macro                        | [Documentation](sc_macros.md#get_hg_macro-method)                                     |
| get_sg_macro                                     | retrieves servicegroup information and make it available as a macro                     | [Documentation](sc_macros.md#get_sg_macro-method)                                     |
| get_bv_macro                                     | retrieves business view information and make it available as a macro                    | [Documentation](sc_macros.md#get_bv_macro-method)                                     |
| build_group_macro_value                          | build the value that must replace the macro (it will also put it in the desired format) | [Documentation](sc_macros.md#build_group_macro_value-method)                          |
| group_macro_format_table                         | transforms the given macro value into a table                                           | [Documentation](sc_macros.md#group_macro_format_table-method)                         |
| group_macro_format_inline                        | transforms the give macro value into a string with values separated using comas         | [Documentation](sc_macros.md#group_macro_format_inline-method)                        |
| build_converted_string_for_cache_and_event_macro | replace event or cache macro in a string that may contain them                          | [Documentation](sc_macros.md#build_converted_string_for_cache_and_event_macro-method) |

## sc_flush methods

| Method name               | Method description                                                     | Link                                                          |
| ------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------- |
| add_queue_metadata        | add specific metadata to a queue                                       | [Documentation](sc_flush.md#add_queue_metadata-method)        |
| flush_all_queues          | try to flush all queues according to accepted elements                 | [Documentation](sc_flush.md#flush_all_queues-method)          |
| reset_all_queues          | put all queues back to their initial state after flushing their events | [Documentation](sc_flush.md#reset_all_queues-method)          |
| get_queues_size           | get the number of events stored in all the queues                      | [Documentation](sc_flush.md#get_queues_size-method)           |
| flush_mixed_payload       | flush a payload that contains various type of events                   | [Documentation](sc_flush.md#flush_mixed_payload-method)       |
| flush_homogeneous_payload | flush a payload that contains a single type of events                  | [Documentation](sc_flush.md#flush_homogeneous_payload-method) |
| flush_payload             | flush a payload                                                        | [Documentation](sc_flush.md#flush_payload-method)             |

## sc_metrics methods

| Method name                   | Method description                                                                                        | Link                                                                |
| ----------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| is_valid_bbdo_element         | checks if the event is in an accepted category and is an appropriate element                              | [Documentation](sc_metrics.md#is_valid_bbdo_element-method)         |
| is_valid_metric_event         | makes sure that the metric event is valid if it is a **host, service, service_status or kpi_event** event | [Documentation](sc_metrics.md#is_valid_metric_event-method)         |
| is_valid_host_metric_event    | makes sure that the metric event is valid host metric event                                               | [Documentation](sc_metrics.md#is_valid_host_metric_event-method)    |
| is_valid_service_metric_event | makes sure that the metric event is valid service metric event                                            | [Documentation](sc_metrics.md#is_valid_service_metric_event-method) |
| is_valid_kpi_metric_event     | makes sure that the metric event is valid KPI metric event                                                | [Documentation](sc_metrics.md#is_valid_kpi_metric_event-method)     |
| is_valid_perfdata             | makes sure that the performance data is valid                                                             | [Documentation](sc_metrics.md#is_valid_perfdata-method)             |
| build_metric                  | use the stream connector format method to parse every metric in the event                                 | [Documentation](sc_metrics.md#build_metric-method)                  |

## google.bigquery.bigquery methods

| Method name                  | Method description                                         | Link                                                                             |
| ---------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------- |
| get_tables_schema            | create all tables schema depending on the configuration    | [Documentation](google/bigquery/bigquery.md#get_tables_schema-method)            |
| default_host_table_schema    | create the default table schema for host_status events     | [Documentation](google/bigquery/bigquery.md#default_host_table_schema-method)    |
| default_service_table_schema | create the default table schema for service_status events  | [Documentation](google/bigquery/bigquery.md#default_service_table_schema-method) |
| default_ack_table_schema     | create the default table schema for acknowledgement events | [Documentation](google/bigquery/bigquery.md#default_ack_table_schema-method)     |
| default_dt_table_schema      | create the default table schema for downtime events        | [Documentation](google/bigquery/bigquery.md#default_dt_table_schema-method)      |
| default_ba_table_schema      | create the default table schema for ba_status events       | [Documentation](google/bigquery/bigquery.md#default_ba_table_schema-method)      |
| load_tables_schema_file      | create tables schema based on a json file                  | [Documentation](google/bigquery/bigquery.md#load_tables_schema_file-method)      |
| build_table_schema           | create tables schema based on stream connector parameters  | [Documentation](google/bigquery/bigquery.md#build_table_schema-method)           |

## google.auth.oauth methods

| Method name      | Method description                          | Link                                                          |
| ---------------- | ------------------------------------------- | ------------------------------------------------------------- |
| create_jwt_token | create a jwt token                          | [Documentation](google/auth/oauth.md#create_jwt_token-method) |
| get_key_file     | retrieve information from a key file        | [Documentation](google/auth/oauth.md#get_key_file-method)     |
| create_jwt_claim | create the claim for the jwt token          | [Documentation](google/auth/oauth.md#create_jwt_claim-method) |
| create_signature | create the signature for the jwt token      | [Documentation](google/auth/oauth.md#create_signature-method) |
| get_access_token | get a google access token using a jwt token | [Documentation](google/auth/oauth.md#get_access_token-method) |
| curl_google      | use curl to get an access token             | [Documentation](google/auth/oauth.md#curl_google-method)      |

## Additionnal documentations

| Description                                                   | Link                                                                                                                                |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| learn how to create a custom format using a format file       | [Documentation](./templating.md)                                                                                                    |
| learn how to create custom code for your stream connector     | [Documentation](./custom_code.md)                                                                                                   |
| have a look at all the available mappings and how to use them | [Documentation](./mappings.md)                                                                                                      |
| have a look at the event structure                            | [Documentation](./broker_data_structure.md) and [Documentation](https://docs.centreon.com/docs/developer/developer-broker-mapping/) |
