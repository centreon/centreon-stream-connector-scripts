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

Don't hesitate to propose improvements and/or contact the community through our Slack workspace. 

Here is a list of the available scripts:

* [Elasticsearch](#elasticsearch)
* [InfluxDB](#InfluxDB)
* [Warp 10](#Warp10)
* [Splunk](#Splunk)
* [ServiceNow](#service-now)
* [NDO](#NDO)
* [HP OMI](#OMI)
* [PagerDuty](#PagerDuty)

# Elasticsearch

## Elasticsearch from metrics events: *elasticsearch/elastic-metrics.lua*

This stream connector works with **metric events**. So you need them to be configured in Centreon broker.

Parameters to specify in the stream connector configuration are:

* log-file as **string**: it is the *complete file name* of this script logs.
* elastic-address as **string**: it is the *ip address* of the Elasticsearch server
* elastic-port as **number**: it is the port, if not provided, this value is *9200*.
* max-row as **number**: it is the max number of events before sending them to the elastic server. If not specified, its value is 100

## Elasticsearch from NEB events: *elasticsearch/elastic-neb.lua*

This stream connector is an alternative to the previous one, but works with **neb service\_status events**.
As those events are always available on a Centreon platform, this script should work more often.

To use this script, one need to install the lua-socket and lua-sec libraries.

Parameters to specify in the stream connector configuration are:

* http\_server\_address as **string**: the *(ip) address* of the Elasticsearch server
* http\_server\_port as **number**: the port of the Elasticsearch server, by default *9200*
* http\_server\_protocol as **string**: the connection scheme, by default *http*
* http\_timeout as **number**: the connection timeout, by default *5* seconds
* filter\_type as **string**: filter events to compute, by default *metric,status*
* elastic\_index\_metric as **string**: the index name for metrics, by default *centreon_metric*
* elastic\_index\_status as **string**: the index name for status, by default *centreon_status*
* elastic\_username as **string**: the API username if set
* elastic\_password as **password**: the API password if set
* max\_buffer\_size as **number**: the number of events to stock before the next flush, by default *5000*
* max\_buffer\_age as **number**: the delay to wait before the next flush, by default *30* seconds
* skip\_anon\_events as **number**: skip events without name in broker cache, by default *1*
* log\_level as **number**: log level from 1 to 3, by default *3*
* log\_path as **string**: path to log file, by default */var/log/centreon-broker/stream-connector-elastic-neb.log*

If one of max\_buffer\_size or max\_buffer\_age is reached, events are sent.

Two indices need to be created on the Elasticsearch server:
```
curl -X PUT "http://elasticsearch/centreon_metric" -H 'Content-Type: application/json'
-d '{"mappings":{"properties":{"host":{"type":"keyword"},"service":{"type":"keyword"},
"instance":{"type":"keyword"},"metric":{"type":"keyword"},"value":{"type":"double"},
"min":{"type":"double"},"max":{"type":"double"},"uom":{"type":"text"},
"type":{"type":"keyword"},"timestamp":{"type":"date","format":"epoch_second"}}}}'

curl -X PUT "http://elasticsearch/centreon_status" -H 'Content-Type: application/json'
-d '{"mappings":{"properties":{"host":{"type":"keyword"},"service":{"type":"keyword"},
"output":{"type":"text"},"status":{"type":"keyword"},"state":{"type":"keyword"},
"type":{"type":"keyword"},"timestamp":{"type":"date","format":"epoch_second"}}}}''
```

# InfluxDB

## InfluxDB from metrics events: *influxdb/influxdb-metrics.lua*

This stream connector works with **metric events**. So you need them to be configured in Centreon broker.

To use this script, one need to install the lua-socket library.

Parameters to specify in the stream connector configuration are:

* http\_server\_address as **string**: it is the *ip address* of the InfluxDB server
* http\_server\_port as **number**: it is the port, if not provided, this value is *8086*
* http\_server\_protocol as **string**: by default, this value is *http*
* influx\_database as **string**: The database name, *mydb* is the default value
* max\_buffer\_size as **number**: The number of events to stock before them to be sent to InfluxDB
* max\_buffer\_age as **number**: The delay in seconds to wait before the next flush.

if one of max\_buffer\_size or max\_buffer\_age is reached, events are sent.

## InfluxDB from neb events: *influxdb/influxdb-neb.lua*

This stream connector is an alternative to the previous one, but works with **neb service\_status events**.
As those events are always available on a Centreon platform, this script should work more often.

To use this script, one need to install the lua-socket and lua-sec libraries.

Parameters to specify in the stream connector configuration are:

* measurement as **string**: the InfluxDB *measurement*, overwrites the service description if set
* http\_server\_address as **string**: the *(ip) address* of the InfluxDB server
* http\_server\_port as **number**: the port of the InfluxDB server, by default *8086*
* http\_server\_protocol as **string**: the connection scheme, by default *https*
* http\_timeout as **number**: the connection timeout, by default *5* seconds
* influx\_database as **string**: the database name, by default *mydb*
* influx\_retention\_policy as **string**: the database retention policy, default is database's default
* influx\_username as **string**: the database username, no authentication performed if not set
* influx\_password as **string**: the database password, no authentication performed if not set
* max\_buffer\_size as **number**: the number of events to stock before the next flush, by default *5000*
* max\_buffer\_age as **number**: the delay to wait before the next flush, by default *30* seconds
* skip\_anon\_events as **number**: skip events without name in broker cache, by default *1*
* log\_level as **number**: log level from 1 to 3, by default *3*
* log\_path as **string**: path to log file, by default */var/log/centreon-broker/stream-connector-influxdb-neb.log*

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

# Splunk

There are two ways to use our stream connector with Splunk. The first and probably most common way uses Splunk Universal Forwarder. The second 
method uses Splunk API. 

## The Splunk Universal Forwarder method

In that case, you're going to use "Centreon4Splunk", it comes with:
* A Splunk App. you may find on Splunkbase [here](https://splunkbase.splunk.com/app/4304/)
* The LUA script and documentation [here](https://github.com/lkco/centreon4Splunk)

Thanks to lkco!

## The Splunk API method

There are two Lua scripts proposed here:
1. *splunk-states-http.lua* that sends states to Splunk.
2. *splunk-metrics-http.lua* that sends metrics to Splunk.

In the first case, follow the instructions below:

* Copy them into the */usr/share/centreon-broker/lua/*
* Add a new broker output of type *stream connector*
* Fill it as shown below

![alt text](pictures/splunk-conf1.png "stream connector configuration")

In the second case, follow those instructions:

* Copy them into the */usr/share/centreon-broker/lua/*
* Add a new broker output of type *stream connector*
* Fill it as shown below

![alt text](pictures/splunk-conf2.png "stream connector configuration")

## The Splunk configuration

An HTTP events collector has be configured in data entries.

![alt text](pictures/splunk.png "Splunk configuration")

# Service Now

The stream connector sends the check results received from Centreon Engine to ServiceNow. Only the host and service check results are sent.

This stream connector is in **BETA** version because it has not been used enough time in production environments.

## Installation

This stream connector needs the lua-curl library available for example with *luarocks*:

`luarocks install lua-curl`

## Configuration

In *Configuration  >  Pollers  >  Broker configuration*, you need to modify the Central Broker Master configuration.

Add an output whose type is Stream Connector.
Choose a name for your configuration.
Enter the path to the **connector-servicenow.lua** file.

Configure the *lua parameters* with the following informations:

Name | Type | Description
--- | --- | ---
client\_id | String | The client id for OAuth authentication
client\_secret | String | The client secret for OAuth authentication
username | String | Username for OAuth authentication
password | Password | Password for OAuth authentication
instance | String | The ServiceNow instance
logfile | String | The log file with its full path (optional)

## Protocol description

The following table describes the matching information between Centreon and the
ServiceNow Event Manager.


**Host event**

Centreon | ServiceNow Event Manager field | Description
--- | --- | ---
hostname | node | The hostname
output | description | The Centreon Plugin output
last\_check | time\_of\_event | The time of the event
hostname | resource | The hostname
severity | The level of severity depends on the host status

**Service event**

Centreon | ServiceNow Event Manager field | Description
--- | --- | ---
hostname | node | The hostname
output | description | The Centreon Plugin output
last\_check | time\_of\_event | The time of the event
service\_description | resource | The service name
severity | The level of severity depends on the host status

# NDO

## Send service status events in the historical NDO protocol format : *ndo/ndo-output.lua*
NDO protocol is no longer supported by Centreon Broker. It is now replaced by BBDO (lower network footprint, automatic compression and encryption).
However it is possible to emulate the historical NDO protocol output with this stream connector.

Parameters to specify in the broker output web ui are:

* ipaddr as **string**: the ip address of the listening server
* port as **number**: the listening server port
* max-row as **number**: the number of event to store before sending the data

By default logs are in /var/log/centreon-broker/ndo-output.log

# OMI

## stream connector for HP OMI : *omi/omi_connector.lua*

Create a broker output for HP OMI Connector

Parameters to specify in the broker output web ui are:

# BSM

## Installation

Login as `root` on the Centreon central server using your favorite SSH client.

In case your Centreon central server must use a proxy server to reach the Internet, you will have to export the `https_proxy` environment variable and configure `yum` to be able to install everything.

```bash
export https_proxy=http://my.proxy.server:3128
echo "proxy=http://my.proxy.server:3128" >> /etc/yum.conf
```

Now that your Centreon central server is able to reach the Internet, you can run:

```bash
yum install -y lua-curl
```

These packages are necessary for the script to run. Now let's download the script:

```bash
wget -O /usr/share/centreon-broker/lua/bsm_connector.lua https://raw.githubusercontent.com/centreon/centreon-stream-connector-scripts/master/bsm/bsm_connector.lua
chmod 644 /usr/share/centreon-broker/lua/bsm_connector.lua
```

The BSM StreamConnnector is now installed on your Centreon central server!

## Configuration

Create a broker output for HP BSM Connector. This LUA script has been forked from HP OMI connector and **has not yet been tested on a production environment**, hence the 'WIP' tag.

Parameters to specify in the broker output WUI are:

* `source_ci` (string): Name of the transmiter, usually Centreon server name
* `http_server_url` (string): the full HTTP URL. Default: https://my.bsm.server:30005/bsmc/rest/events/ws-centreon/.
* `http_proxy_string` (string): the full proxy URL if needed to reach the BSM server. Default: empty.
* `log_path` (string): the log file to use
* `log_level` (number): the log level (0, 1, 2, 3) where 3 is the maximum level. 0 logs almost nothing. 1 logs only the beginning of the script and errors. 2 logs a reasonable amount of verbose. 3 logs almost everything possible, to be used only for debug. Recommended value in production: 1.
* `max_buffer_size` (number): how many events to store before sending them to the server.
* `max_buffer_age` (number): flush the events when the specified time (in second) is reached (even if `max_buffer_size` is not reached).

# PagerDuty

## Installation / prerequisites

The `lua-curl` and `luatz` libraries are required by this script:

```bash
yum install -y lua-curl epel-release
yum install -y luarocks
luarocks install luatz
```

Then copy the `pagerduty.lua` script to `/usr/share/centreon-broker/lua`.

## Configuration

### Minimal configuration

Here are the steps to configure your stream connector:

* Add a new "Generic - Stream connector" output to the central broker in the "Configuration / Poller / Broker configuration" menu.
* Name it as wanted and set the right path:

| Name | pagerduty                                    |
| ---- | -------------------------------------------- |
| Path | /usr/share/centreon-broker/lua/pagerduty.lua |

* Add at least one string parameter containing your PagerDuty routing key/token.

| Type              | String               |
| ----------------- | -------------------- |
| `pdy_routing_key` | `<type your key here>` |

Thats all for now!

Then save your configuration, export it and restart the broker daemon:

```bash
systemctl restart cbd
```

### Advanced configuration

#### Proxy

If your Centreon central server has no direct access to PagerDuty but needs a proxy server, you will have to add a new string parameter:

| Type                | String                          |
| ------------------- | ------------------------------- |
| `http_proxy_string` | `http://your.proxy.server:3128` |

#### Centreon URL

In order to have working links/URL in your PagerDuty events, you are encouraged to add this parameter:

| Type               | String                        |
| ------------------ | ----------------------------- |
| `pdy_centreon_url` | `http://your.centreon.server` |

#### Log level / file

The default value of 2 is fine for initial troubleshooting, but generates a huge amount of logs if you have a lot of hosts. In order to get less log messages, you are should add this parameter:

| Type        | Number |
| ----------- | ------ |
| `log_level` | 1      |

The default log file is `/var/log/centreon-broker/stream-connector-pagerduty.log`. If it does not suit you, you can set it with the `log_path` parameter:

| Type       | String                                         |
| ---------- | ---------------------------------------------- |
| `log_path` | `/var/log/centreon-broker/my-custom-logfile.log` |


#### Buffer size / age

In case you want to tune the maximum number of events sent in a row for optimization purpose, you may add this parameter:

| Type              | Number             |
| ----------------- | ------------------ |
| `max_buffer_size` | 10 (default value) |


In case you want to shorten the delay (in seconds) between the reception of an event and its transmission to PagerDuty, you can set this parameter:

| Type             | Number             |
| ---------------- | ------------------ |
| `max_buffer_age` | 30 (default value) |

