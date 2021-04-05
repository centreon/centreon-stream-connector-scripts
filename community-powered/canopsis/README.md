**Canopsis**

- https://doc.canopsis.net/guide-developpement/struct-event/

## Description

This script use the stream-connector mechanism of Centreon to get events from 
the pollers. The event is then translated to a Canopsis event and sent to the
HTTP REST API.

## Technical description

This connector follow the best practices of the Centreon documentation 
(see the listed links in the first section).

The script is in lua language as imposed by the stream-connector specification.

It get all the events from Centreon and convert these events in 
a Canopsis compatible json format.

Filtered events are sent to HTTP API of Canopsis by chunk to reduce the number of
connections.

The filtered events are :

- acknowledgment events (category 1, element 1)
- downtime events (category 1, element 5)
- host events (category 1, element 14)
- service events (category 1, element 24)

Extra informations are added to the host and services as bellow :

- action_url
- notes_url
- hostgroups
- servicegroups (for service events)

### Acknowledgment

Two kinds of ack are sent to Canopsis :

- Ack creation
- Ack deletion

An ack is positioned on the resource/component reference

### Downtime

Two kinds of downtime are sent to Canopsis as "pbehavior" :

- Downtime creation
- Downtime cancellation

A uniq ID is generated from the informations of the downtime carried by Centreon.

*Note : The recurrent downtimes are not implemented by the stream connector yet.*

### Host status

All HARD events with a state changed from hosts are sent to Canopsis.

Take care of the state mapping as below :

```
-- CENTREON // CANOPSIS
-- ---------------------
--       UP    (0) // INFO     (0)
--     DOWN    (1) // CRITICAL (3)
-- UNREACHABLE (2) // MAJOR    (2)
```

### Service status

All HARD events with a state changed from services are sent to Canopsis.

Take care of the state mapping as below :

```
-- CENTREON // CANOPSIS
-- ---------------------
--       OK (0) // INFO     (0)
--  WARNING (1) // MINOR    (1)
-- CRITICAL (2) // CRITICAL (3)
-- UNKNOWN  (3) // MAJOR    (2)
```

## Howto

### Prerequisites

* lua version >= 5.1.4
* install lua-socket library (http://w3.impa.br/~diego/software/luasocket/)
    * >= 3.0rc1-2 ( from sources, you have to install also gcc + lua-devel packages  ) available into canopsis repository
* centreon-broker version 19.10.5 or >= 20.04.2

### Installation

**Software deployment from sources (centreon-broker 19.10.5 or >= 20.04.2) :**

1. Copy the lua script `bbdo2canopsis.lua` from `canopsis` dir to `/usr/share/centreon-broker/lua/bbdo2canopsis.lua`
2. Change the permissions to this file `chown centreon-engine:centreon-engine /usr/share/centreon-broker/lua/bbdo2canopsis.lua`

**Software deployment from packages (centreon-broker >= 20.04.2) :**

1. Install canopsis repository first

```
echo "[canopsis]
name = canopsis
baseurl=https://repositories.canopsis.net/pulp/repos/centos7-canopsis/
gpgcheck=0
enabled=1" > /etc/yum.repos.d/canopsis.repo
```

2. install connector with Yum
```
yum install canopsis-connector-centreon-stream-connector
```

**Enable the connector :**

1. add a new "Generic - Stream connector" output on the central-broker-master (see the official documentation)
2. export the poller configuration (see the official documentation)
3. restart services 'systemctl restart cbd centengine gorgoned'

If you modify this script in development mode ( directly into the centreon host ), 
you will need to restart the Centreon services (at least the centengine service).

### Configuration

All the configuration can be made througt the Centreon interface as described in
the official documentation.

**The main parameters you have to set are :**

```
connector_name         = "your connector source name"
canopsis_user          = "your Canopsis API user"
canopsis_password      = "your Canopsis API password"
canopsis_host          = "your Canopsis host"
```

**If you want to customize your queue parameters (optional) :**

```
max_buffer_age         = 60     -- retention queue time before sending data
max_buffer_size        = 10     -- buffer size in number of events
```

**The init spread timer (optional) :**

```
init_spread_timer      = 360   -- time to spread events in seconds at connector starts
```

This timer is needed for the start of the connector.

During this time, the connector send all HARD state events (with state change or 
not) to update the events informations from Centreon to Canopsis. In that way
the level of information tends to a convergence.

*This implies a burst of events and a higher load for the server during this time.*

**On the Centreon WUI you can set these parameters as below :**

In Configuration > Pollers > Broker configuration > central-broker-master > 
Output > Select "Generic - Stream connector" > Add 

![centreon-configuration-screenshot](pictures/centreon-configuration-screenshot.png)

### Check the output

By default the connector use the HTTP REST API of Canopsis to send events.

Check your alarm view to see the events from Centreon.

All logs are dumped into the default log file "/var/log/centreon-broker/debug.log"

#### Advanced usage

You can also use a raw log file to dump all Canopsis events and manage your
own way to send events (by example with logstash) by editing the "sending_method"
variable en set the "file" method.