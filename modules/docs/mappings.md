# mappings documentation

- [mappings documentation](#mappings-documentation)
  - [Introduction](#introduction)
  - [Categories](#categories)
    - [get category ID from name](#get-category-id-from-name)
    - [get category name from ID](#get-category-name-from-id)
  - [Elements](#elements)
    - [get element ID from name](#get-element-id-from-name)
    - [get element name from ID](#get-element-name-from-id)
    - [get the category ID from an element name](#get-the-category-id-from-an-element-name)
    - [get the category name from an element name](#get-the-category-name-from-an-element-name)
    - [get the element ID from a category ID and an element name](#get-the-element-id-from-a-category-id-and-an-element-name)
  - [States](#states)
    - [get state type name from state type ID](#get-state-type-name-from-state-type-id)
    - [get state name from category ID, element ID and state ID](#get-state-name-from-category-id-element-id-and-state-id)
  - [Tips and tricks](#tips-and-tricks)

## Introduction

Every mappings is made available trough a params table that is only available if you have created an instance of the sc_params module. To create such instance, head over [**the sc_params documentation**](sc_param.md#Module-initialization)

## Categories

Each event is linked to a category. To help you work with that, there are a bunch of mappings available

### get category ID from name

To get the ID of a category based on its name, you can use the following mapping table

```lua
-- get the id of the neb category
local category_id = params_object.params.bbdo.categories["neb"].id
--> category_id is 1

-- you can also get its name from this table but it shouldn't be very useful
local category_name = params_object.params.bbdo.categories["neb"].name
```

### get category name from ID

To get the name of a category based on its ID, you can use the following mapping table

```lua
-- get the name of the category 6
local category_name = params_object.params.reverse_category_mapping[6]
--> category_name is "bam"
```

## Elements

Each event is linked to an element. To help you work with that, there are a bunch of mappings available

### get element ID from name

```lua
-- get the ID of the element host_status
local element_id = params_object.params.bbdo.elements["host_status"].id
--> element_id is 14

-- you can also get its name from this table but it shouldn't be very useful
local element_name = params_object.params.bbdo.elements["host_status"].name
--> element_name is "host_status"
```

### get element name from ID

You can't get a element name from its ID only. You must have its category too. For example, there are many elements that shares the ID 1. Because each category has its own elements and their ID start at 1.
For example, the **acknowledgement** element and the **ba_status** element have 1 as an element ID. The first element is part of the **neb category**, the second one is part of the **bam category**

```lua
-- category is neb
local category_id = params_object.params.bbdo.categories["neb"].id -- it is better to use the mapping instead of hard coding the ID if you know it. 
-- element is service_status
local element_id = 24

local element_name = params_object.params.reverse_element_mapping[category_id][element_id]
--> element_name is "service_status"
```

### get the category ID from an element name

```lua
local category_id = params_object.params.bbdo.elements["host_status"].category_id
--> category_id is 1
```

### get the category name from an element name

```lua
local category_name = params_object.params.bbdo.elements["host_status"].category_name
--> category_name is neb
```

### get the element ID from a category ID and an element name

This one is a bit redundant with the [**get the category ID from an element name**](#get-the-category-ID-from-an-element-name) mapping. It should be deprecated but in a world where two elements from different categories could share the same name, it is better to keep this possibility

```lua
local category_id = params_object.params.bbdo.categories["neb"].id -- it is better to use the mapping instead of hard coding the ID if you know it. 
local element_name = "host_status"

local element_id = params_object.params.element_mapping[category_id][element_name]
--> element_id is 14
```

## States

### get state type name from state type ID

```lua
local state_type_name = params_object.state_type_mapping[0]
--> state_type_name is "SOFT"

state_type_name = params_object.state_type_mapping[1]
--> state_type_name is "HARD"
```

### get state name from category ID, element ID and state ID

```lua
local category_id = local category_id = params_object.params.bbdo.categories["neb"].id -- it is better to use the mapping instead of hard coding the ID if you know it. 
local element_id = params_object.params.bbdo.elements["host_status"].id -- it is better to use the mapping instead of hard coding the ID if you know it. 

local state_name = params_object.params.status_mapping[category_id][element_id][1]
--> state_name is "DOWN"
```

## Tips and tricks

- When you want to use the ID of the neb category for example

```lua
-- ✘ bad
local neb_category_id = 1

-- ✓ good
local neb_category_id = params_object.params.bbdo.categories.neb.id
```

- When you want to use the ID of the host_status element for example

```lua
-- ✘ bad
local host_status_element_id = 14

-- ✓ good
local host_status_element_id = params_object.params.bbdo.elements.host_status.id
```

- When working on a downtime event, you can get the human readable state using a hidden mapping table. Because this event is shared between services and hosts you don't know if the ID 1 means DOWN or WARNING

```lua
local categories = params_object.params.bbdo.categories
local elements = params_object.params.bbdo.elements

-- 2 = host, 1 is the ID code of the state
local host_state_downtime = params.status_mapping[categories.neb.id][elements.downtime.id][2][1]
--> host_state_downtime is "DOWN"

-- 1 = service, 2 is the ID code the state
local service_state_downtime = params.status_mapping[categories.neb.id][elements.downtime.id][1][2]
--> service_state_downtime is "CRITICAL"
```
