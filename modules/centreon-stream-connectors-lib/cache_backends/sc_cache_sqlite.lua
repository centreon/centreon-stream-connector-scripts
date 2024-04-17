---
-- a cache module that is using LuaSqlite3
-- @module sc_cache_sqlite
-- @module sc_cache_sqlite

local sc_cache_sqlite = {}
local ScCacheSqlite = {}

local sqlite = require("lsqlite3")

function sc_cache_sqlite.new(logger, params)
  local self = {}

  self.sc_logger = logger
  self.params = params
  self.sqlite = sqlite.open(params.sqlite_cache_db_file)

  if not self.sqlite:isopen() then
    self.sc_logger:error("[sc_cache_sqlite:new]: couldn't open sqlite database: " .. tostring(params.sqlite_cache_db_file))
  end

  setmetatable(self, { __index = ScCacheSqlite})
  self:check_cache_table()
  return self
end

function ScCacheSqlite:check_cache_table()
  local query = "SELECT name FROM sqlite_master WHERE type='table' AND name='sc_cache'"
  
  if #self.sqlite:nrows(query) == 1 then
    self.sc_logger:debug("[sc_cache_sqlite:check_cache_table]: sqlite table sc_cache exists")
  else
    self.sc_logger:notice("[sc_cache_sqlite:check_cache_table]: sqlite table sc_cache does not exist. We are going to create it")
    self:create_cache_table()
  end
end

function ScCacheSqlite:create_cache_table()
  local query = [[
    CREATE TABLE sc_cache (
      object_id TEXT,
      property TEXT,
      value TEXT,
      PRIMARY KEY (object_id, property)
    )
  ]]

  self.sqlite:exec(query)
end

function ScCacheSqlite:set(object_id, property, value)
end

function ScCacheSqlite:get(object_id, property)
end

function ScCacheSqlite:delete(object_id, property)
end

function ScCacheSqlite:show(object_id)
end

function ScCacheSqlite:clear()
end

return sc_cache_sqlite