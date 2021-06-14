# Stream Connectors lib documentation

- [Stream Connectors lib documentation](#stream-connectors-lib-documentation)
  - [Libraries list](#libraries-list)
  - [sc_common methods](#sc_common-methods)
  - [sc_logger methods](#sc_logger-methods)
  - [sc_broker methods](#sc_broker-methods)
  - [sc_param methods](#sc_param-methods)
  - [sc_event methods](#sc_event-methods)
  - [sc_macros methods](#sc_macros-methods)
  - [google.bigquery.bigquery methods](#googlebigquerybigquery-methods)
  - [google.auth.oauth methods](#googleauthoauth-methods)

## Libraries list

| Lib name                 | Content                                          | Usage                                                                     | Documentation                                |
| ------------------------ | ------------------------------------------------ | ------------------------------------------------------------------------- | -------------------------------------------- |
| sc_common                | basic methods for lua                            | you can use it when you want to simplify your code                        | [Documentation](sc_common.md)                |
| sc_logger                | methods that handle logging with centreon broker | When you want to log a message from your stream connector                 | [Documentation](sc_logger.md)                |
| sc_broker                | wrapper methods for broker cache                 | when you need something from the broker cache                             | [Documentation](sc_broker.md)                |
| sc_param                 | handles parameters for stream connectors         | when you want to initiate a stream connector with all standard parameters | [Documentation](sc_param.md)                 |
| sc_event                 | methods to help you interact with a broker event | when you want to check event data                                         | [Documentation](sc_event.md)                 |
| sc_macros                | methods to help you convert macros               | when you want to use macros in your stream connector                      | [Documentation](sc_macros.md)                |
| google.bigquery.bigquery | methods to help you handle bigquery data         | when you want to generate tables schema for bigquery                      | [Documentation](google/bigquery/bigquery.md) |
| google.auth.oauth        | methods to help you authenticate to google api   | when you want to authenticate yourself on the google api                  | [Documentation](google/auth/oauth.md)        |

## sc_common methods

| Method name                        | Method description                                                                          | Link                                                                    |
| ---------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| ifnil_or_empty                     | check if a variable is empty or nil and replace it with a default value if it is the case   | [Documentation](sc_common.md#ifnil_or_empty-method)                     |
| if_wrong_type                      | check the type of a variable, if it is wrong, replace the variable with a default value     | [Documentation](sc_common.md#if_wrong_type-method)                      |
| boolean_to_number                  | change a true/false boolean to a 1/0 value                                                  | [Documentation](sc_common.md#boolean_to_number-method)                  |
| check_boolean_number_option_syntax | make sure that a boolean is 0 or 1, if that's not the case, replace it with a default value | [Documentation](sc_common.md#check_boolean_number_option_syntax-method) |
| split                              | split a string using a separator (default is ",") and store each part in a table            | [Documentation](sc_common.md#split-method)                              |
| compare_numbers                    | compare two numbers using the given mathematical operator and return true or false          | [Documentation](sc_common.md#compare_numbers-method)                    |
| generate_postfield_param_string    | convert a table of parameters into an url encoded parameters string                         | [Documentation](sc_common.md#generate_postfield_param_string-method)    |

## sc_logger methods

| Method name | Method description                          | Link                                         |
| ----------- | ------------------------------------------- | -------------------------------------------- |
| error       | write an error message in the log file      | [Documentation](sc_logger.md#error-method)   |
| warning     | write a warning message in the log file     | [Documentation](sc_logger.md#warning-method) |
| notice      | write a notice/info message in the log file | [Documentation](sc_logger.md#notice-method)  |
| info        | write an info message in the log file       | [Documentation](sc_logger.md#info-method)    |
| debug       | write a debug message in the log file       | [Documentation](sc_logger.md#debug-method)   |

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

| Method name             | Method description                                                                                                                            | Link                                                        |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| param_override          | replace default values of params with the ones provided by users in the web configuration of the stream connector                             | [Documentation](sc_param.md#param_override-method)          |
| check_params            | make sure that the default stream connectors params provided by the user from the web configuration are valid. If not, uses the default value | [Documentation](sc_param.md#check_params-method)            |
| is_mandatory_config_set | check that all mandatory parameters for a stream connector are set                                                                            | [Documentation](sc_param.md#is_mandatory_config_set-method) |
| get_kafka_params        | retrive Kafka dedicated parameters from the parameter list and put them in the provided kafka_config object                                   | [Documentation](sc_param.md#get_kafka_params-method)        |

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

| Method name            | Method description                                                             | Link                                                        |
| ---------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| replace_sc_macro       | replace a stream connector macro with its value                                | [Documentation](sc_macros.md#replace_sc_macro-method)       |
| get_cache_macro        | retrieve a macro value in the cache                                            | [Documentation](sc_macros.md#get_cache_macro-method)        |
| get_event_macro        | retrieve a macro value in the event                                            | [Documentation](sc_macros.md#get_event_macro-method)        |
| convert_centreon_macro | replace a Centreon macro with its value                                        | [Documentation](sc_macros.md#convert_centreon_macro-method) |
| get_centreon_macro     | transform a Centreon macro into a stream connector macro                       | [Documentation](sc_macros.md#get_centreon_macro-method)     |
| get_transform_flag     | try to find a transformation flag in the macro name                            | [Documentation](sc_macros.md#get_transform_flag-method)     |
| transform_date         | transform a timestamp into a human readable format                             | [Documentation](sc_macros.md#transform_date-method)         |
| transform_short        | keep the first line of a string                                                | [Documentation](sc_macros.md#transform_short-method)        |
| transform_type         | convert 0 or 1 into SOFT or HARD                                               | [Documentation](sc_macros.md#transform_type-method)         |
| transform_state        | convert a status code into its matching human readable status (OK, WARNING...) | [Documentation](sc_macros.md#transform_state-method)        |

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
