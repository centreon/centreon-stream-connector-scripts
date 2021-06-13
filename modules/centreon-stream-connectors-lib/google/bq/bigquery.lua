local bq_send = {}

local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local bq_tables = require("centreon-stream-connectors-lib.google.bq.bq_tables")

local BQSend = {}


function bq_send.new(sc_logger, sc_common, params)
  local self = {}

  self.sc_logger = sc_logger
  if not self.sc_logger then
    self.sc_logger = sc_logger.new()
  end

  self.params = params

  self.bq_tables = bq_tables.new(self.sc_logger, self.sc_common, self.params)
  self.bq_tables:get_tables_schema()

  setmetatable(self, { __index = BQSend })

  return self
end



