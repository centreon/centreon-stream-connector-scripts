----- START OF PARAMETERS -------

-- put your kafka broker address {"host1:port", "host2:port"}
local BROKERS_ADDRESS = { "hhhhhhh:pppp" }
-- change topic depending on your needs
local TOPIC_NAME = "centreon"

local config = require 'centreon-stream-connectors-lib.rdkafka.config'.create()

--  set up your configuration. List of parameters there : https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md
config["security.protocol"] = "sasl_plaintext"
config["sasl.mechanisms"] = "PLAIN"
config["sasl.username"] = "xxxxx"
config["sasl.password"] = "yyyyyyyy"
config["statistics.interval.ms"] =  "1000"

-- this is the message you want to send to kafka
local message = "This is a test message"

------ END OF PARAMETERS ---------



config:set_delivery_cb(function (payload, err) print("Delivery Callback '"..payload.."'") end)
config:set_stat_cb(function (payload) print("Stat Callback '"..payload.."'") end)

local producer = require 'centreon-stream-connectors-lib.rdkafka.producer'.create(config)

for k, v in pairs(BROKERS_ADDRESS) do
    producer:brokers_add(v)
end

local topic_config = require 'centreon-stream-connectors-lib.rdkafka.topic_config'.create()
topic_config["auto.commit.enable"] = "true"

local topic = require 'centreon-stream-connectors-lib.rdkafka.topic'.create(producer, TOPIC_NAME, topic_config)

local KAFKA_PARTITION_UA = -1

producer:produce(topic, KAFKA_PARTITION_UA, message)


while producer:outq_len() ~= 0 do
    producer:poll(10)
end