# Stream connectors and custom code

- [Stream connectors and custom code](#stream-connectors-and-custom-code)
  - [Introduction](#introduction)
  - [When is it needed?](#when-is-it-needed)
  - [How to configure your stream connector](#how-to-configure-your-stream-connector)
  - [Mandatory code](#mandatory-code)
  - [Available data for your custom code](#available-data-for-your-custom-code)
  - [Macros, templating and custom code](#macros-templating-and-custom-code)
  - [Filter events](#filter-events)
  - [Use all the above chapters](#use-all-the-above-chapters)
    - [Add methods from other modules](#add-methods-from-other-modules)
    - [Add custom macros](#add-custom-macros)

## Introduction

Stream connectors offer the possibility to write custom code. The idea is to let people fully customize how their stream connector behave while still using the Centreon standard stream connector.
Thanks to this feature, you will no longer have a customized stream connector and you will not fear updating it to get access to the latest features.

## When is it needed?

It is needed in two cases (mostly)

- you need more filters than the default one. For example you want to filter out hosts that do not have *notes*
- you need to add data to your event payload

## How to configure your stream connector

In your stream connector configuration (broker output), you can add the following option

| option name      | value                                   | type   |
| ---------------- | --------------------------------------- | ------ |
| custom_code_file | /etc/centreon-broker/my-custom-code.lua | string |

## Mandatory code

Your custom code must respect three rules if you want it to work.

It must starts with

```lua
local self = ...
```

It must ends with a return the self variable and a boolean followed by a new line.

```lua
return self, true
-- new line after true
```

you can't do:

```lua
-- ✘ bad, no space after the coma
return self,true
-- new line after true
```

nor

```lua
-- ✘ bad, no new line after the return line
return self, true -- no new line after true
```

## Available data for your custom code

Everything has been made to grant you access to all the useful information. It means that you can:

- access the [params table](sc_param.md#default-parameters) and the parameters that are dedicated to the stream connector that you are using
- access the [event table](broker_data_structure.md) (you can also take a look at our [broker documentation](https://docs.centreon.com/docs/developer/developer-broker-mapping/))
- access all the methods from: [event module](sc_event.md), [params module](sc_param.md), [logger module](sc_logger.md), [common module](sc_common.md), [broker module](sc_broker.md) and if you are using a metric stream connector [metrics module](sc_metrics.md)
- access all the broker daemon methods that are listed [here](https://docs.centreon.com/docs/developer/developer-broker-stream-connector/#the-broker-table)

## Macros, templating and custom code

Since stream connectors have been thought to be highly customizable, we have made a tool to change the data that you are sending. To do so, you use a custom format file ([documentation](templating.md)). In this file you can use macros ([documentation](sc_macros.md)).

By using custom code you can create your own macros and it is very easy to do! Let's take a look at that.

```lua
local self = ...

self.event.my_custom_macro = "my custom macro value"

return self, true
-- new line after true
```

Thanks to the above code, we are now able to use `{my_custom_macro}` as a new macro. And it will be replaced by the string `my custom macro value`.

To sum up what we have seen. Just add a new entry in the `self.event` table. It is going to be the name of you custom macro and that is it.

## Filter events

As explained [at the beginning](#when-is-it-needed), you can add your own filters to your data. Find below a rundown of the major steps that are done when using a stream connector

1. stream connector init (only done on cbd reload or restart)
2. filter events
3. format event
4. put event in a queue
5. send all events stored in the queue

The second step has a set of filters but they may not be enough for you. This is where a custom code file can be useful.

Let's keep our idea of filtering events with hosts that do not have **notes** and see what it will looks like with real code

```lua
local self = ...

if not self.event.cache.host.notes or self.event.cache.host.notes == "" then
  -- the boolean part of the return is here to tell the stream connector to ignore the event
  return self, false
end

-- if the host has a note then we let the stream connector continue his work on this event
return self, true
-- new line after true
```

## Use all the above chapters

### Add methods from other modules

What if we start logging what our custom code does? To do so, we can use [the warning method](sc_logger.md#warning-method)

```lua
local self = ...

if not self.event.cache.host.notes or self.event.cache.host.notes == "" then
  -- use the warning method of from the logger module 
  self.sc_logger:warning("[custom_code]: host: "
    .. tostring(self.event.cache.host.name) .. " do not have notes, therefore, we drop the event")
  -- the boolean part of the return is here to tell the stream connector to ignore the event
  return self, false
end

-- if the host has a note then we let the stream connector continue his work on this event
return self, true
-- new line after true
```

Maybe you want a closer look at what is inside the `self.event` table. To do so, we can dump it in our logfile using [the Dumper method](sc_common.md#dumper-method)

```lua
local self = ...

-- we dump the event table to have a closer look to all the available data from the event itself 
-- and all the things that are in the cache that we may want to use
self.sc_logger:notice("[custom_code]: self.event table data: " .. self.sc_common:dumper(self.event))

if not self.event.cache.host.notes or self.event.cache.host.notes == "" then
  -- use the warning method from the logger module 
  self.sc_logger:warning("[custom_code]: host: "
    .. tostring(self.event.cache.host.name) .. " do not have notes, therefore, we drop the event")
  -- the boolean part of the return is here to tell the stream connector to ignore the event
  return self, false
end

-- if the host has a note then we let the stream connector continue his work on this event
return self, true
-- new line after true
```

### Add custom macros

```lua
local self = ...

-- we dump the event table to have a closer look to all the available data from the event itself 
-- and all the things that are in the cache that we may want to use
self.sc_logger:notice("[custom_code]: self.event table data: " .. self.sc_common:dumper(self.event))

if not self.event.cache.host.notes or self.event.cache.host.notes == "" then
  -- use the warning method from the logger module 
  self.sc_logger:warning("[custom_code]: host: "
    .. tostring(self.event.cache.host.name) .. " do not have notes, therefore, we drop the event")
  -- the boolean part of the return is here to tell the stream connector to ignore the event
  return self, false
end

-- let say we can extract the origin of our host by using the first three letters of its name
self.event.origin = string.sub(tostring(self.event.cache.host.name), 1, 3)
-- we now have a custom macro called {origin}

-- if the host has a note then we let the stream connector continue his work on this event
return self, true
-- new line after true
```
