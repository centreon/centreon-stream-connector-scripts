# Broker data structure documentation

- [Broker data structure documentation](#broker-data-structure-documentation)
  - [Introduction](#introduction)
  - [NEB Category](#neb-category)
    - [Service_status](#service_status)
    - [Host_status](#host_status)
    - [Downtime](#downtime)
      - [Downtime actual start](#downtime-actual-start)
      - [Downtime actual end](#downtime-actual-end)
    - [Acknowledgements](#acknowledgements)
      - [Acknowledgement actual start](#acknowledgement-actual-start)
      - [Acknowledgement actual end](#acknowledgement-actual-end)

## Introduction

The purpose of this documentation is to provide a quick overview of what data structure you should expect from a broker event.
This documentation will not explain the meaning of the structures. It is mostly a guide to help writing centreon lua modules and stream connectors

## NEB Category

### Service_status

[BBDO documentation](https://docs.centreon.com/current/en/developer/developer-broker-mapping.html#service-status)

| index                    | type    |
| ------------------------ | ------- |
| acknowledged             | boolean |
| acknowledgement_type     | number  |
| active_checks            | boolean |
| category                 | number  |
| check_attempt            | number  |
| check_command            | string  |
| check_interval           | number  |
| check_period             | string  |
| check_type               | number  |
| checked                  | boolean |
| element                  | number  |
| enabled                  | boolean |
| event_handler            | string  |
| event_handler_enabled    | boolean |
| execution_time           | number  |
| flap_detection           | boolean |
| flapping                 | boolean |
| host_id                  | number  |
| last_check               | number  |
| last_hard_state          | number  |
| last_hard_state_change   | number  |
| last_state_change        | number  |
| last_time_up             | number  |
| last_update              | number  |
| latency                  | number  |
| max_check_attempts       | number  |
| next_check               | number  |
| no_more_notifications    | boolean |
| notification_number      | number  |
| notify                   | boolean |
| obsess_over_host         | boolean |
| output                   | string  |
| passive_checks           | boolean |
| percent_state_change     | number  |
| perfdata                 | string  |
| retry_interval           | number  |
| scheduled_downtime_depth | number  |
| should_be_scheduled      | boolean |
| state                    | number  |
| state_type               | number  |

### Host_status

[BBDO documentation](https://docs.centreon.com/current/en/developer/developer-broker-mapping.html#host-status)

| index                    | type    |
| ------------------------ | ------- |
| acknowledged             | boolean |
| acknowledgement_type     | number  |
| active_checks            | boolean |
| category                 | number  |
| check_attempt            | number  |
| check_command            | string  |
| check_interval           | number  |
| check_period             | string  |
| check_type               | number  |
| checked                  | boolean |
| element                  | number  |
| enabled                  | boolean |
| event_handler            | string  |
| event_handler_enabled    | boolean |
| execution_time           | number  |
| flap_detection           | boolean |
| flapping                 | boolean |
| host_id                  | number  |
| last_check               | number  |
| last_hard_state          | number  |
| last_hard_state_change   | number  |
| last_state_change        | number  |
| last_time_ok             | number  |
| last_update              | number  |
| latency                  | number  |
| max_check_attempts       | number  |
| next_check               | number  |
| no_more_notifications    | boolean |
| notification_number      | number  |
| notify                   | boolean |
| obsess_over_service      | boolean |
| output                   | string  |
| passive_checks           | boolean |
| percent_state_change     | number  |
| perfdata                 | string  |
| retry_interval           | number  |
| scheduled_downtime_depth | number  |
| service_id               | number  |
| should_be_scheduled      | boolean |
| state                    | number  |
| state_type               | number  |

### Downtime

[BBDO documentation](https://docs.centreon.com/current/en/developer/developer-broker-mapping.html#downtime)

if you are using the [**is_valid_downtime_event method**](sc_event.md#is_valid_downtime_event-method) you'll also have access to a `state` index that will give you the status code of the host or service and a `cache` table.

#### Downtime actual start

| index             | type    |
| ----------------- | ------- |
| actual_start_time | number  |
| author            | string  |
| cancelled         | boolean |
| category          | number  |
| comment_data      | string  |
| duration          | number  |
| element           | number  |
| end_time          | number  |
| entry_time        | number  |
| fixed             | boolean |
| host_id           | number  |
| instance_id       | number  |
| internal_id       | number  |
| service_id        | number  |
| start_time        | number  |
| started           | boolean |
| type              | number  |

#### Downtime actual end

| index             | type    |
| ----------------- | ------- |
| actual_end_time   | number  |
| actual_start_time | number  |
| author            | string  |
| cancelled         | boolean |
| category          | number  |
| comment_data      | string  |
| deletion_time     | number  |
| duration          | number  |
| element           | number  |
| end_time          | number  |
| entry_time        | number  |
| fixed             | boolean |
| host_id           | number  |
| instance_id       | number  |
| internal_id       | number  |
| service_id        | number  |
| start_time        | number  |
| started           | boolean |
| type              | number  |

### Acknowledgements

[BBDO documentation](https://docs.centreon.com/current/en/developer/developer-broker-mapping.html#acknowledgement)

#### Acknowledgement actual start

| index              | type    |
| ------------------ | ------- |
| author             | string  |
| category           | number  |
| comment_data       | string  |
| element            | number  |
| entry_time         | number  |
| host_id            | number  |
| instance_id        | number  |
| notify_contacts    | boolean |
| persistent_comment | boolean |
| service_id         | number  |
| state              | number  |
| sticky             | boolean |
| type               | number  |

#### Acknowledgement actual end

| index              | type    |
| ------------------ | ------- |
| author             | string  |
| category           | number  |
| comment_data       | string  |
| deletion_time      | number  |
| element            | number  |
| entry_time         | number  |
| host_id            | number  |
| instance_id        | number  |
| notify_contacts    | boolean |
| persistent_comment | boolean |
| service_id         | number  |
| state              | number  |
| sticky             | boolean |
| type               | number  |
