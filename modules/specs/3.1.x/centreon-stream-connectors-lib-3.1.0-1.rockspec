package = "centreon-stream-connectors-lib"
version = "3.1.0-1"
source = {
   url = "git+https://github.com/centreon/centreon-stream-connector-scripts",
   tag = "3.1.0-1"
}
description = {
   summary = "Centreon stream connectors lua modules",
   detailed = [[
      Those modules provides helpful methods to create
      stream connectors for Centreon
   ]],
   license = ""
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "luasocket >= 3.0rc1-2"
}
build = {
   type = "builtin",
   modules = {
     ["centreon-stream-connectors-lib.sc_broker"] = "modules/centreon-stream-connectors-lib/sc_broker.lua",
     ["centreon-stream-connectors-lib.sc_common"] = "modules/centreon-stream-connectors-lib/sc_common.lua",
     ["centreon-stream-connectors-lib.sc_event"] = "modules/centreon-stream-connectors-lib/sc_event.lua",
     ["centreon-stream-connectors-lib.sc_logger"] = "modules/centreon-stream-connectors-lib/sc_logger.lua",
     ["centreon-stream-connectors-lib.sc_params"] = "modules/centreon-stream-connectors-lib/sc_params.lua",
     ["centreon-stream-connectors-lib.sc_test"] = "modules/centreon-stream-connectors-lib/sc_test.lua",
     ["centreon-stream-connectors-lib.sc_macros"] = "modules/centreon-stream-connectors-lib/sc_macros.lua",
     ["centreon-stream-connectors-lib.sc_flush"] = "modules/centreon-stream-connectors-lib/sc_flush.lua",
     ["centreon-stream-connectors-lib.sc_metrics"] = "modules/centreon-stream-connectors-lib/sc_metrics.lua",
     ["centreon-stream-connectors-lib.rdkafka.config"] = "modules/centreon-stream-connectors-lib/rdkafka/config.lua",
     ["centreon-stream-connectors-lib.rdkafka.librdkafka"] = "modules/centreon-stream-connectors-lib/rdkafka/librdkafka.lua",
     ["centreon-stream-connectors-lib.rdkafka.producer"] = "modules/centreon-stream-connectors-lib/rdkafka/producer.lua",
     ["centreon-stream-connectors-lib.rdkafka.topic_config"] = "modules/centreon-stream-connectors-lib/rdkafka/topic_config.lua",
     ["centreon-stream-connectors-lib.rdkafka.topic"] = "modules/centreon-stream-connectors-lib/rdkafka/topic.lua",
     ["centreon-stream-connectors-lib.google.auth.oauth"] = "modules/centreon-stream-connectors-lib/google/auth/oauth.lua",
     ["centreon-stream-connectors-lib.google.bigquery.bigquery"] = "modules/centreon-stream-connectors-lib/google/bigquery/bigquery.lua"
   }
}
