# Centreon Stream Connectors #

Here are several stream connectors for the
[Centreon Broker](https://github.com/centreon/centreon-broker).

The goal is to provide useful scripts to the community.

# Influxdb

## Influxdb from metrics events

This stream connector works with **metric events**. So you need them to be configured in Centreon broker.

To use this script, one need to install the lua-socket library.

Parameters to specify in the stream connector configuration are:

* http\_server\_address as **string**: it is the *ip address* of the Influxdb server
* http\_server\_port as **number**: it is the port, if not provided, this value is *8086*
* http\_server\_protocol as **string**: by default, this value is *http*
* influx\_database as **string**: The database name, *mydb* is the default value
* max\_buffer\_size as **number**: The number of events to stock before them to be sent to influxdb
* max\_buffer\_age as **number**: The delay in seconds to wait before the next flush.

if one of max\_buffer\_size or max\_buffer\_age is reached, events are sent.

## Influxdb from neb events

This stream connector is an alternative to the previous one, but works with **neb service\_status events**.
As those events are always available on a Centreon platform, this script should work more often.

To use this script, one need to install the lua-socket library.

Parameters to specify in the stream connector configuration are:

* measurement as **string**: it is the influxdb *measurement*
* http\_server\_address as **string**: it is the *ip address* of the Influxdb server
* http\_server\_port as **number**: it is the port, if not provided, this value is *8086*
* http\_server\_protocol as **string**: by default, this value is *http*
* influx\_database as **string**: The database name, *mydb* is the default value
* max\_buffer\_size as **number**: The number of events to stock before them to be sent to influxdb
* max\_buffer\_age as **number**: The delay in seconds to wait before the next flush.

if one of max\_buffer\_size or max\_buffer\_age is reached, events are sent.

