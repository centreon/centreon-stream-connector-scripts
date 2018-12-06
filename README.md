# Centreon Stream Connectors #

Here are several stream connectors for the
[Centreon Broker](https://github.com/centreon/centreon-broker).

# Stream connectors

The goal is to provide useful scripts to the community to extend the open source solution Centreon.

You can find Lua scripts written to export Centreon data to several outputs.

If one script is the good one for you, it is recommended to copy it on the Centreon central server
into the **/usr/share/centreon-broker/lua** directory. If it does not exist, you can create it. This
directory must be readable by the *centreon-broker* user.

When the script is copied, you have to configure it through the centreon web interface.

Stream connector documentation are provided here:
* https://documentation.centreon.com/docs/centreon/en/latest/developer/writestreamconnector.html
* https://documentation.centreon.com/docs/centreon-broker/en/latest/exploit/stream_connectors.html

# Elasticsearch

## Elasticsearch from metrics events: *elasticsearch/elastic-metrics.lua*

This stream connector works with **metric events**. So you need them to be configured in Centreon broker.

Parameters to specify in the stream connector configuration are:

* log-file as **string**: it is the *complete file name* of this script logs.
* elastic-address as **string**: it is the *ip address* of the Elasticsearch server
* elastic-port as **number**: it is the port, if not provided, this value is *9200*.
* max-row as **number**: it is the max number of events before sending them to the elastic server. If not specified, its value is 100

# Influxdb

## Influxdb from metrics events: *influxdb/influxdb-metrics.lua*

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

## Influxdb from neb events: *influxdb/influxdb-neb.lua*

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

# Warp10

## Warp10 from neb events: *warp10/export-warp10.lua*

This stream connector works with **neb service\_status events**.

This stream connector need at least centreon-broker-18.10.1.

To use this script, one need to install the lua-curl library.

Parameters to specify in the stream connector configuration are:

* ipaddr as **string**: the ip address of the Warp10 server
* logfile as **string**: the log file
* port as **number**: the Warp10 server port
* token as **string**: the Warp10 write token
* max\_size as **number**: how many queries to store before sending them to the Warp10 server.

