# How to use triggers

- [How to use triggers](#how-to-use-triggers)
  - [Introduction](#introduction)
  - [The trigger\_file parameter](#the-trigger_file-parameter)
  - [Structure of a trigger file](#structure-of-a-trigger-file)
  - [Available triggers](#available-triggers)
    - [EventQueue:new / on-init](#eventqueuenew--on-init)
    - [EventQueue:add / on-event-add](#eventqueueadd--on-event-add)
    - [sc\_flush:create\_new\_virtual\_queue / on-create](#sc_flushcreate_new_virtual_queue--on-create)
    - [sc\_flush:add\_queue\_metadata / on-add](#sc_flushadd_queue_metadata--on-add)
    - [sc\_flush:reset\_all\_queues / on-reset](#sc_flushreset_all_queues--on-reset)
    - [sc\_flush:flush\_payload / on-success](#sc_flushflush_payload--on-success)
    - [sc\_flush:flush\_payload / on-fail](#sc_flushflush_payload--on-fail)
    - [sc\_storage:set / on-set](#sc_storageset--on-set)
    - [sc\_storage:set\_multiple / on-set](#sc_storageset_multiple--on-set)
    - [sc\_storage:get / on-get](#sc_storageget--on-get)
    - [sc\_storage:get\_multiple / on-get](#sc_storageget_multiple--on-get)
    - [sc\_storage:delete / on-delete](#sc_storagedelete--on-delete)
    - [sc\_storage:delete\_multiple / on-delete](#sc_storagedelete_multiple--on-delete)
    - [sc\_storage:show / on-show](#sc_storageshow--on-show)
    - [sc\_storage:clear / on-clear](#sc_storageclear--on-clear)

## Introduction

Triggers let you run your own Lua code at specific points of a stream connector's lifecycle **without editing the stream connector or the centreon-stream-connectors-lib code**. Since your customization lives in its own file, it will not be overwritten the next time the stream connector or the library is updated.

To use a trigger, you write a **trigger file**: a plain Lua file that registers one or several of your own functions on the [available triggers](#available-triggers) listed below. Each trigger fires automatically at a precise moment of the stream connector's life (when it starts, when an event is queued, when a payload is sent, when data is stored, ...).

## The trigger_file parameter

Set the **trigger_file** parameter, in your stream connector configuration, to the full path of your trigger file (for example `/etc/centreon-broker/my-trigger-file.lua`). Put it in `/etc/centreon-broker` to keep your broker configuration in a single place.

The file is read, compiled and executed **once**, when the stream connector starts. If the file doesn't exist, isn't readable, or doesn't contain valid Lua code, an error is logged in the stream connector's log file and the stream connector keeps running without your customizations (it will not crash).

## Structure of a trigger file

Your trigger file must start with:

```lua
local self = ...
```

`self` is how you receive everything you need. It is the same `self` used internally by the sc_trigger module, which means you have access to:

- `self.params`: the full parameter table of the stream connector (every [default parameter](sc_param.md#default-parameters) plus everything specific to the stream connector you are customizing). You can read any entry from it, for example `self.params.accepted_hostgroups`.
- `self.sc_common`: an instance of the [sc_common module](sc_common.md). You can call any of its methods, for example `self.sc_common:dumper(some_table)` to inspect a table in your logs.
- `self.sc_logger`: an instance of the [sc_logger module](sc_logger.md). You can call any of its methods, for example `self.sc_logger:notice("my message")`, `self.sc_logger:error(...)`, `self.sc_logger:debug(...)`.
- `self:register_trigger(category, event_type, trigger_function)`: the method you call to actually attach one of your functions to a trigger, see below.

You can use anything that is stored in `self` by the sc_trigger module, not just the three entries above, but the ones above are what you will use most of the time.

Once you have `self`, call [**register_trigger**](sc_trigger.md#register_trigger-method) as many times as you want, once per trigger you want to hook into:

```lua
-- content of /etc/centreon-broker/my-trigger-file.lua
local self = ...

-- runs once, right after the stream connector has finished its initialization
self:register_trigger("EventQueue:new", "on-init", function(data)
  self.sc_logger:notice("[my-trigger-file]: stream connector has been initialized")
end)

-- runs every time an event is about to be added to the sending queue
-- data.formatted_event is the event, you can read it or even edit it in place
self:register_trigger("EventQueue:add", "on-event-add", function(data)
  data.formatted_event.my_custom_field = "hello from my trigger file"
end)
```

If one of your registered functions raises an error while it runs, it is caught and logged, it will not crash the stream connector. In that case the [documented default value](#available-triggers) of the trigger is used instead of your function's result.

## Available triggers

Each trigger is identified by a **category** (usually the name of the module/method that fires it) and an **event_type** (the specific moment, within that category, when it fires). Both are the exact strings you must give to [**register_trigger**](sc_trigger.md#register_trigger-method).

### EventQueue:new / on-init

**When triggered:** once, at the very end of every stream connector's constructor, right after the stream connector has finished building its internal state (queues, formatting functions, and so on) and right before the constructor returns.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored. You don't need to return anything, whatever you return is discarded.

**data table:**

| index | type | description |
| - | - | - |
| params | table | the full parameter table of the stream connector (same content as `self.params`) |

**Example:**

```lua
self:register_trigger("EventQueue:new", "on-init", function(data)
  self.sc_logger:notice("stream connector initialized with max_buffer_size: " .. tostring(data.params.max_buffer_size))
end)
```

### EventQueue:add / on-event-add

**When triggered:** every time a stream connector is about to push a freshly formatted event into its sending queue, right before it is actually queued.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected. However both `data.formatted_event` and `data.full_event_data` are given to you by reference: editing their fields in your function directly changes the event that is going to be queued and sent.

**data table:**

| index | type | description |
| - | - | - |
| formatted_event | table | the event as it is going to be sent, already formatted by the stream connector. You can add, edit or remove fields on it |
| full_event_data | table | the full event table used internally by the stream connector: every raw field from the Centreon Broker event, plus `category`, `element`, the broker `cache` data (host, service, hostgroups, ...) gathered while validating the event, and `formatted_event` itself (same table as the `formatted_event` index above, just reachable from here too) |

**Example:**

```lua
self:register_trigger("EventQueue:add", "on-event-add", function(data)
  data.formatted_event.my_custom_field = "hello from my trigger file"
  -- full_event_data grants access to everything, including fields that never made it into formatted_event
  data.formatted_event.host_id = data.full_event_data.host_id
end)
```

### sc_flush:create_new_virtual_queue / on-create

**When triggered:** every time `sc_flush:create_new_virtual_queue` successfully creates a new virtual queue.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| virtual_queue | table | the queue that was just created, it contains an `events` table (empty at this point) and a `queue_metadata` table (with `category_id` and `element_id`) |

**Example:**

```lua
self:register_trigger("sc_flush:create_new_virtual_queue", "on-create", function(data)
  self.sc_logger:notice("a new virtual queue has been created for element_id: " .. tostring(data.virtual_queue.queue_metadata.element_id))
end)
```

### sc_flush:add_queue_metadata / on-add

**When triggered:** once for every metadata key/value pair added to a queue by `sc_flush:add_queue_metadata` (it can fire several times if you call it with several metadata entries at once).

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| name | string | the name of the metadata that was just set |
| value | any | the value the metadata was just set to |

**Example:**

```lua
self:register_trigger("sc_flush:add_queue_metadata", "on-add", function(data)
  self.sc_logger:debug("queue metadata " .. tostring(data.name) .. " has been set to " .. tostring(data.value))
end)
```

### sc_flush:reset_all_queues / on-reset

**When triggered:** every time `sc_flush:reset_all_queues` empties every queue, right after every queue's events have been reset.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| queues | table | the full queues table, right after being reset (indexed by BBDO category id, then element id) |

**Example:**

```lua
self:register_trigger("sc_flush:reset_all_queues", "on-reset", function(data)
  self.sc_logger:debug("all queues have just been reset")
end)
```

### sc_flush:flush_payload / on-success

**When triggered:** every time `sc_flush:flush_payload` has just **successfully** sent a payload (the send function did not raise an error).

**Returned default value:** `true`

**Return value:** **you must return a boolean**. It is not ignored: it becomes the actual return value of `flush_payload`, which the rest of the stream connector uses to decide whether the flush worked. Returning `false` turns this successful send into a reported failure.

**data table:**

| index | type | description |
| - | - | - |
| payload | any | the exact payload that was sent |
| metadata | table | the queue metadata (endpoint, method, ...) that was used to send the payload |

**Example:**

```lua
self:register_trigger("sc_flush:flush_payload", "on-success", function(data)
  self.sc_logger:notice("payload successfully sent")
  return true
end)
```

### sc_flush:flush_payload / on-fail

**When triggered:** every time `sc_flush:flush_payload` **fails** to send a payload (the send function raised an error, caught internally).

**Returned default value:** `false`

**Return value:** **you must return a boolean**. It is not ignored: it becomes the actual return value of `flush_payload`. Returning `true` reports this failed send as a success despite the underlying error (useful if you want to swallow a specific, known-harmless error).

**data table:**

| index | type | description |
| - | - | - |
| payload | any | the payload that failed to be sent |
| metadata | table | the queue metadata (endpoint, method, ...) that was used to try to send the payload |
| error | string | the error message that was caught |

**Example:**

```lua
self:register_trigger("sc_flush:flush_payload", "on-fail", function(data)
  self.sc_logger:error("could not send payload: " .. tostring(data.error))
  return false
end)
```

### sc_storage:set / on-set

**When triggered:** every time `sc_storage:set` is about to write a single property to the storage backend, right before it actually writes it.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object the property belongs to (for example `host_12`) |
| property | string | the name of the property that is about to be set |
| value | string, number or boolean | the value the property is about to be set to |

**Example:**

```lua
self:register_trigger("sc_storage:set", "on-set", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. "." .. tostring(data.property) .. " is about to be set to " .. tostring(data.value))
end)
```

### sc_storage:set_multiple / on-set

**When triggered:** every time `sc_storage:set_multiple` is about to write several properties at once, right before it actually writes them.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object the properties belong to |
| properties | table | the table of property names/values that is about to be written |

**Example:**

```lua
self:register_trigger("sc_storage:set_multiple", "on-set", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. " is about to have several properties set: " .. self.sc_common:dumper(data.properties))
end)
```

### sc_storage:get / on-get

**When triggered:** every time `sc_storage:get` has just read a single property from the storage backend.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object the property belongs to |
| property | string | the name of the property that was read |
| value | string | the value that was retrieved (empty string if the read failed) |
| status | boolean | whether the read succeeded or not |

**Example:**

```lua
self:register_trigger("sc_storage:get", "on-get", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. "." .. tostring(data.property) .. " is: " .. tostring(data.value))
end)
```

### sc_storage:get_multiple / on-get

**When triggered:** every time `sc_storage:get_multiple` has just read several properties from the storage backend.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object the properties belong to |
| properties | table | the list of properties that was requested |
| value | table | the table of properties/values that was retrieved (empty table if the read failed) |
| status | boolean | whether the read succeeded or not |

**Example:**

```lua
self:register_trigger("sc_storage:get_multiple", "on-get", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. " properties have been retrieved, status: " .. tostring(data.status))
end)
```

### sc_storage:delete / on-delete

**When triggered:** every time `sc_storage:delete` is about to delete a single property, right before it actually deletes it.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object the property belongs to |
| property | string | the name of the property that is about to be deleted |

**Example:**

```lua
self:register_trigger("sc_storage:delete", "on-delete", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. "." .. tostring(data.property) .. " is about to be deleted")
end)
```

### sc_storage:delete_multiple / on-delete

**When triggered:** every time `sc_storage:delete_multiple` is about to delete several properties at once, right before it actually deletes them.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object the properties belong to |
| properties | table | the list of properties that is about to be deleted |

**Example:**

```lua
self:register_trigger("sc_storage:delete_multiple", "on-delete", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. " is about to have properties deleted")
end)
```

### sc_storage:show / on-show

**When triggered:** every time `sc_storage:show` is about to print, in the log file, all the stored properties of an object.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

| index | type | description |
| - | - | - |
| object_id | string | the storage object whose properties are about to be shown |

**Example:**

```lua
self:register_trigger("sc_storage:show", "on-show", function(data)
  self.sc_logger:debug(tostring(data.object_id) .. " properties are about to be shown")
end)
```

### sc_storage:clear / on-clear

**When triggered:** every time `sc_storage:clear` is about to wipe the entire storage backend.

**Returned default value:** no default value declared for this trigger

**Return value:** ignored, no return value is expected.

**data table:**

This trigger receives an empty table, there is no contextual data for it.

**Example:**

```lua
self:register_trigger("sc_storage:clear", "on-clear", function(data)
  self.sc_logger:warning("the whole storage is about to be cleared")
end)
```
