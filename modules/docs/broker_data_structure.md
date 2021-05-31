# Broker data structure documentation

- [Broker data structure documentation](#broker-data-structure-documentation)
  - [Introduction](#introduction)
  - [NEB Category](#neb-category)
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
