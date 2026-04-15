-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_storage = require("centreon-stream-connectors-lib.sc_storage")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_logger and sc_common module
local test_logger = sc_logger.new(logfile, severity)
local test_common = sc_common.new(test_logger)

-- create the required table of parameters

local params = {
  storage_backend = "sqlite"
}

-- create a new instance of the sc_common module
local test_storage = sc_storage.new(test_common, test_logger, params)

