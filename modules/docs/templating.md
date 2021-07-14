# Templating documentation

- [Templating documentation](#templating-documentation)
  - [Introduction](#introduction)
  - [Templating](#templating)
    - [Structure](#structure)
    - [Template and macros](#template-and-macros)
    - [Example: adding new entries to already handled event types](#example-adding-new-entries-to-already-handled-event-types)
    - [Example: adding a not handled event type](#example-adding-a-not-handled-event-type)

## Introduction

Templating with stream connectors is an options that is offered **only for events oriented stream connecotrs**. This means that **you can't use** templating with **metrics oriented stream connectors**

Templating allows you to format your events at your convenience either because the default format doesn't suit your needs or because the stream connector doesn't handle a type of event that you would like to receive.

Stream connectors modules are build to handle the following event types

- acknowledgemnt
- downtime
- host_status
- service_status
- ba_status

It means that if you create a template that is not related to those types, you will not be able to use the built in features of the stream connectors modules. More event types may be handled in the feature. If some important ones come to your mind, feel free to let us know by opening an issue at [https://github.com/centreon/centreon-stream-connector-scripts/issues](https://github.com/centreon/centreon-stream-connector-scripts/issues)

## Templating

### Structure

A template is a json file with the following structure

```json
{
  "<category_name>_<element_name>": {
    "key_1": "value_1",
    "key_2": "value_2"
  },
  "<category_name>_<element_name>": {
    "key_1": "value_1",
    "key_2": "value_2"
  }
}
```

### Template and macros

To make the best use of the template feature, you should take a look at the whole macros system that is implemented in the stream connectors modules. [**Macros documentation**](sc_macros.md#stream-connectors-macro-explanation)

### Example: adding new entries to already handled event types

In order to get a better overview of the system, we are going to work on the Splunk-events-apiv2 stream connector.

This stream connector handles the following event types

- host_status
- service_status

lets take a closer look at the format of a host_status event

```lua
self.sc_event.event.formated_event = {
  event_type = "host",
  state = self.sc_event.event.state,
  state_type = self.sc_event.event.state_type,
  hostname = self.sc_event.event.cache.host.name,
  output = string.gsub(self.sc_event.event.output, "\n", ""),
}
```

In the code, the formated event is made of a string (event_type), the state, state_type, hostname and output. Let say we would like to have the **host_id** and the **address**. The first one needs to be in an index called **"MY_HOST_ID"** and the address stored in an index called **"IP"**

This will result in the following json templating file

```json
{
  "neb_host_status": {
    "event_type": "host",
    "state": "{state}",
    "state_type": "{state_type}",
    "hostname": "{cache.host.name}",
    "outout": "{output_scshort}",
    "MY_HOST_ID": "{host_id}",
    "IP": "{cache.host.address}"
  }
}
```

As you can see, there are a lot of **{text}** those are macros that will be replaced by the value found in the event or linked to the event (like in the cache).

The service_status event type is not in the json file. Therefore, it will use the default format provided by the Splunk stream connector.

### Example: adding a not handled event type

This example will use what has been made in [the previous example](#example-adding-new-entries-to-already-handled-event-types)

As stated before, only **host_status** and **service_status** are handled by the Splunk stream connector. Stream connectors module are able to handle a few others that have been communicated [**in the introduction**](#introduction)

Let say we would like to handle **ba_status** events. To do so, we need to add this kind of event in the json file

```json
{
  "neb_host_status": {
    "event_type": "host",
    "state": "{state}",
    "state_type": "{state_type}",
    "hostname": "{cache.host.name}",
    "outout": "{output_scshort}",
    "MY_HOST_ID": "{host_id}",
    "IP": "{cache.host.address}"
  },
  "bam_ba_status": {
    "event_type": "BA",
    "ba_name": "{cache.ba.ba_name}",
    "ba_id": "{ba_id}",
    "state": "{state}"
  }
}
```

As state in the previous example, the service_status event type is not in the json file. Therefore, it will use the default format provided by the Splunk stream connector.
