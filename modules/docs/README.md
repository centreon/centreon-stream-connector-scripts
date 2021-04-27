# Stream Connectors lib documentation

- [Stream Connectors lib documentation](#stream-connectors-lib-documentation)
  - [Libraries list](#libraries-list)
  - [sc_common methods](#sc_common-methods)
  - [sc_logger methods](#sc_logger-methods)
  - [sc_broker methods](#sc_broker-methods)
  - [sc_param methods](#sc_param-methods)
  - [sc_event methods](#sc_event-methods)

## Libraries list

| Lib name  | Content                                          | Usage                                                                     |
| --------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| sc_common | basic methods for lua                            | you can use it when you want to simplify your code                        |
| sc_logger | methods that handle logging with centreon broker | When you want to log a message from your stream connector                 |
| sc_broker | wrapper methods for broker cache                 | when you need something from the broker cache                             |
| sc_param  | handles parameters for stream connectors         | when you want to initiate a stream connector with all standard parameters |
| sc_event  | methods to help you interact with a broker event | when you to perform a specific action on an event                         |

## sc_common methods

| Method name                        | Method description                                                                          | Link |
| ---------------------------------- | ------------------------------------------------------------------------------------------- | ---- |
| ifnil_or_empty                     | check if a variable is empty or nil and replace it with a default value if it is the case   | link |
| if_wrong_type                      | check the type of a variable, if it is wrong, replace the variable with a default value     | link |
| boolean_to_number                  | change a true/false boolean to a 1/0 value                                                  | link |
| check_boolean_number_option_syntax | make sure that a boolean is 0 or 1, if that's not the case, replace it with a default value | link |
| split                              | split a string using a separator (default is ",") and store each part in a table            | link |
| compare_numbers                    | compare two numbers using the given mathematical operator and return true or false          | link |

## sc_logger methods

| Method name | Method description                          | Link                                           |
| ----------- | ------------------------------------------- | ---------------------------------------------- |
| error       | write an error message in the log file      | [Documentation](./sc_logger.md#error-method)   |
| warning     | write a warning message in the log file     | [Documentation](./sc_logger.md#warning-method) |
| notice      | write a notice/info message in the log file | [Documentation](./sc_logger.md#notice-method)  |
| debug       | write a debug message in the log file       | [Documentation](./sc_logger.md#debug-method)   |

## sc_broker methods

| Method name           | Method description                                                               | Link |
| --------------------- | -------------------------------------------------------------------------------- | ---- |
| get_host_all_infos    | retrieve all informations about a host from the broker cache                     | link |
| get_service_all_infos | retrieve all informations about a service from the broker cache                  | link |
| get_host_infos        | retrieve one or more specific informations about a host from the broker cache    | link |
| get_service_infos     | retrieve one or more specific informations about a service from the broker cache | link |
| get_hostgroups        | retrieve the hostgroups linked to a host from the broker cache                   | link |
| get_servicegroups     | retrieve the servicegroups linked to a service from the broker cache             | link |
| get_severity          | retrieve the severity of a host or a service from the broker cache               | link |
| get_instance          | retrieve the name of the poller using the instance id from the broker cache      | link |
| get_ba_infos          | retrieve the name and description of a BA from the broker cache                  | link |
| get_bv_infos          | retrieve the name and description of all BV linked to a BA                       |

## sc_param methods

| Method name    | Method description                                                                                                                            | Link |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| param_override | replace default values of params with the ones provided by users in the web configuration of the stream connector                             | link |
| check_params   | make sure that the default stream connectors params provided by the user from the web configuration are valid. If not, uses the default value | link |

## sc_event methods

| Method name                      | Method description                                                                                                                                           | Link |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- |
| is_valid_category                | check if the category of the event is accepted according to the stream connector params                                                                      | link |
| is_valid_element                 | check if the element of the event is accepted according to the stream connector params                                                                       | link |
| is_valid_event                   | check if the event is valid according to the stream connector params                                                                                         | link |
| is_valid_neb_event               | check if the neb event is valid according to the stream connector params                                                                                     | link |
| is_valid_host_status_event       | check the "host status" event is valid according to the stream connector params                                                                              | link |
| is_valid_service_status_event    | check the "servce status" event is valid according to the stream connector params                                                                            | link |
| is_host_valid                    | check if the host name and/or ID are valid according to the stream connector params                                                                          | link |
| is_service_valid                 | check if the service description and/or ID are are valid according to the stream connector params                                                            | link |
| are_all_event_states_valid       | check if the state (HARD/SOFT), acknowledgement state and downtime state are valid according to the stream connector params                                  | link |
| is_valid_event_status            | check if the status (OK, DOWN...) of the event is valid according to the stream connector params                                                             | link |
| is_valid_event_state_type        | check if the state (HARD/SOFT) of the event is valid according to the stream connector params                                                                | link |
| is_valid_event_acknowledge_state | check if the acknowledgement state of the event is valid according to the stream connector params                                                            | link |
| is_valid_event_downtime_state    | check if the downtime state of the event is valid according to the stream connector params                                                                   | link |
| is_valid_hostgroup               | check if the host is in an accepted hostgroup according to the stream connector params                                                                       | link |
| find_hostgroup_in_list           | check if one of the hostgroups of the event is in the list of accepted hostgroups provided in the stream connector configuration. Stops at first match       | link |
| is_valid_servicegroup            | check if the service is in an accepted servicegroup according to the stream connector params                                                                 | link |
| find_servicegroup_in_list        | check if one of the servicegroups of the event is in the list of accepted servicegroups provided in the stream connector configuration. Stops at first match | link |
| is_valid_bam_event               | check if the BAM event is valid according to the stream connector params                                                                                     | link |
| is_ba_valid                      | check if the BA name and/or ID are are valid according to the stream connector params                                                                        | link |
| is_valid_ba_status_event         | check if the "ba status" (OK, WARNING, CRITICAL) event is valid according to the stream connector params                                                     | link |
| is_valid_ba_downtime_state       | check if the BA downtime state is valid according to the stream connector params                                                                             | link |
| is_valid_ba_acknowledge_state    | DO NOTHING                                                                                                                                                   | link |
| is_valid_bv                      | check if the BA is in an accepted BV according to the stream connector params                                                                                | link |
| find_bv_in_list                  | check if one of the BV of the event is in the list of accepted BV provided in the stream connector configuration. Stops at first match                       | link |
| is_valid_storage_event           | DO NOTHING (deprecated, you should use neb event to send metrics)                                                                                            | link |

A few methods were made public but their purpose is very specific and may not be useful in you stream connector.

| Method name     | Method description                                                            | Link |
| --------------- | ----------------------------------------------------------------------------- | ---- |
| find_in_mapping | convert an item information using a mapping table and check if it is accepted | link |
