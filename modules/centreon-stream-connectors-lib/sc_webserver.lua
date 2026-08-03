#!/usr/bin/lua

---
-- HTTP server module for centreon stream connectors standalone mode
-- Handles incoming GET and POST requests and routes them to registered handlers.
-- Depends on luasocket (require "socket").
-- @module sc_webserver
-- @alias sc_webserver

local sc_webserver = {}
local ScWebserver = {}

local socket = require("socket")

--- sc_webserver.new: sc_webserver constructor
-- @param params (table) configuration table
-- @param sc_logger (table) instance of the sc_logger module
-- @param sc_common (table) instance of the sc_common module
function sc_webserver.new(params, sc_logger, sc_common)
  local self = {}

  self.params = params
  self.params.webserver_port = self.params.webserver_port or 8086
  self.params.webserver_listen_address = self.params.webserver_listen_address or "127.0.0.1"
  self.sc_logger = sc_logger
  self.sc_common = sc_common
  self.server = nil
  self.routes = {
    GET = {},
    POST = {}
  }

  setmetatable(self, { __index = ScWebserver })
  return self
end

--- add_get_route: register a handler for GET requests on a given path
-- @param path (string) URL path to match (e.g. "/events")
-- @param handler (function) called as handler(request) and must return a response table:
--   { status (number), status_text (string), body (string), content_type (string) }
function ScWebserver:add_get_route(path, handler)
  self.routes.GET[path] = handler
end

--- add_post_route: register a handler for POST requests on a given path
-- @param path (string) URL path to match (e.g. "/events")
-- @param handler (function) called as handler(request) and must return a response table:
--   { status (number), status_text (string), body (string), content_type (string) }
function ScWebserver:add_post_route(path, handler)
  self.routes.POST[path] = handler
end

--- start: bind the socket and begin listening
-- Must be called before process() or run().
-- @return true on success, nil + error string on failure
function ScWebserver:start()
  local srv = socket.tcp()
  srv:setoption("reuseaddr", true)

  local ok, bind_err = srv:bind(self.params.webserver_listen_address, self.params.webserver_port)
  local try = 1
  local err

  -- address may still be bound from previous execution. We do 60 retry before giving up
  while not ok and try < 60 do
    err = "sc_webserver: failed to bind to " .. self.params.webserver_listen_address .. ":" .. tostring(self.params.webserver_port) .. " - " .. tostring(bind_err)
    self.sc_logger:error("[sc_webserver:start]: " .. err)
    self.sc_common:sleep(1)
    ok, bind_err = srv:bind(self.params.webserver_listen_address, self.params.webserver_port)
    try = try + 1
  end

  if not ok then
    err = "sc_webserver: failed to bind to " .. self.params.webserver_listen_address .. ":" .. tostring(self.params.webserver_port) .. " - " .. tostring(bind_err)
    self.sc_logger:error("[sc_webserver:start]: " .. err)
    srv:close()
    return nil, err
  end

  local listen_ok, listen_err = srv:listen(10)
  if not listen_ok then
    err = "sc_webserver: failed to listen - " .. tostring(listen_err)
    self.sc_logger:error("[sc_webserver:start]: " .. err)
    srv:close()
    return nil, err
  end

  -- non-blocking accept so process() can be used in an external loop
  srv:settimeout(0)
  self.server = srv
  self.sc_logger:notice("[sc_webserver:start]: listening on " .. self.params.webserver_listen_address .. ":" .. tostring(self.params.webserver_port))
  return true
end

--- parse_request: read and parse an HTTP request from a connected client socket
-- @param client (socket) connected TCP client
-- @return request table on success, nil + error string on failure
-- Request table fields:
--   method (string), path (string), query_string (string),
--   http_version (string), headers (table), body (string)
function ScWebserver:parse_request(client)
  local line, err = client:receive("*l")
  if not line then
    return nil, "failed to read request line: " .. tostring(err)
  end

  -- strip trailing CR if present (luasocket strips LF but not CR)
  line = line:gsub("\r$", "")

  local method, raw_path, http_version = line:match("^(%u+) (%S+) HTTP/(%S+)$")
  if not method then
    return nil, "malformed request line: " .. tostring(line)
  end

  local path, query_string = raw_path:match("^([^?]*)%??(.*)")

  local headers = {}
  local content_length = 0
  while true do
    local hline, herr = client:receive("*l")
    if not hline or hline == "" or hline == "\r" then
      break
    end
    hline = hline:gsub("\r$", "")
    local name, value = hline:match("^([^:]+):%s*(.-)%s*$")
    if name then
      local lower_name = name:lower()
      headers[lower_name] = value
      if lower_name == "content-length" then
        content_length = tonumber(value) or 0
      end
    end
  end

  local body = ""
  if content_length > 0 then
    local received, recv_err = client:receive(content_length)
    body = received or ""
  end

  return {
    method = method,
    path = path,
    query_string = query_string,
    http_version = http_version,
    headers = headers,
    body = body
  }
end

--- send_response: write an HTTP response to a client socket
-- @param client (socket) connected TCP client
-- @param status_code (number) HTTP status code
-- @param status_text (string) HTTP status text
-- @param body (string) response body
-- @param content_type (string) Content-Type header value (default: "application/json")
function ScWebserver:send_response(client, status_code, status_text, body, content_type)
  content_type = content_type or "application/json"
  body = body .. "\n" or "\n"
  local response = table.concat({
    "HTTP/1.1 " .. tostring(status_code) .. " " .. tostring(status_text),
    "Content-Type: " .. content_type,
    "Content-Length: " .. tostring(#body),
    "Connection: close",
    "",
    body
  }, "\r\n")
  client:send(response)
end

--- handle_connection: parse one HTTP request and dispatch it to the matching route handler
-- @param client (socket) connected TCP client
function ScWebserver:handle_connection(client)
  client:settimeout(5)

  local request, parse_err = self:parse_request(client)
  
  if not request then
    self.sc_logger:warning("[sc_webserver:handle_connection]: failed to parse request: " .. tostring(parse_err))
    self:send_response(client, 400, "Bad Request", '{"error":"bad request"}')
    return
  end

  self.sc_logger:debug("[sc_webserver:handle_connection]: " .. tostring(request.method) .. " " .. tostring(request.path))

  if request.method ~= "GET" and request.method ~= "POST" then
    self.sc_logger:warning("[sc_webserver:handle_connection]: method not allowed. Received method: " .. tostring(parse_err))
    self:send_response(client, 405, "Method Not Allowed", '{"error":"method not allowed"}')
    return
  end

  local handler = self.routes[request.method][request.path]
  if not handler then
    self.sc_logger:warning("[sc_webserver:handle_connection]: 404 not found. Path: " .. tostring(request.path))
    self:send_response(client, 404, "Not Found", '{"error":"not found"}')
    return
  end

  local ok, result = pcall(handler, request)
  if not ok then
    self.sc_logger:error("[sc_webserver:handle_connection]: Internal server error: " .. tostring(result))
    self:send_response(client, 500, "Internal Server Error", '{"error":"internal server error ' .. tostring(result) .. '"}')
    return
  end

  self:send_response(
    client,
    result.status or 200,
    result.status_text or "OK",
    result.body .. "\n" or "\n",
    result.content_type or "application/json"
  )
end

--- process: accept and handle one pending connection without blocking
-- Returns immediately when no connection is waiting.
-- Use this inside an external event loop (e.g. sc_standalone's main loop).
-- start() must be called before process().
-- @return true on success, nil + error string if the server is not started
function ScWebserver:process()
  if not self.server then
    return nil, "sc_webserver: server not started, call start() first"
  end

  local client = self.server:accept()
  if client then
    self:handle_connection(client)
    client:close()
  end

  return true
end

--- run: start the server (if not already started) and block in an accept loop
-- Calls start() internally when needed.
-- @return nil + error string if startup fails; otherwise never returns
function ScWebserver:run()
  if not self.server then
    local ok, err = self:start()
    if not ok then
      return nil, err
    end
  end

  -- switch to a 1-second timeout so the loop can react to signals
  self.server:settimeout(1)
  self.sc_logger:notice("[sc_webserver:run]: entering run loop")

  while true do
    local client, accept_err = self.server:accept()
    if client then
      self:handle_connection(client)
      client:close()
    elseif accept_err ~= "timeout" then
      self.sc_logger:error("[sc_webserver:run]: accept error: " .. tostring(accept_err))
    end
  end
end

--- stop: close the listening socket
function ScWebserver:stop()
  if self.server then
    self.server:close()
    self.server = nil
    self.sc_logger:notice("[sc_webserver:stop]: server stopped")
  end
end

return sc_webserver
