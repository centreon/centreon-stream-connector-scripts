#!/usr/bin/lua

--- 
-- oauth module for google 
-- @module oauth
-- @alias oauth

local oauth = {}

local mime = require("mime")
local crypto = require("crypto")
local curl = require("cURL")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local json = require("cjson")



local OAuth = {}

function oauth.new(params, sc_common, sc_logger)
  local self = {}

  -- initiate stream connector logger 
  self.sc_logger = sc_logger
  if not self.sc_logger then
    self.sc_logger = sc_logger.new("/var/log/centreon-broker/gbq.log", 3)
  end

  self.sc_common = sc_common
  self.params = params

  -- initiate standard params for google oauth
  self.jwt_info = {
    project_id = params.project_id,
    scope = params.scope_list,
    api_key = params.api_key,
    key_file = params.key_file_path,
    hash_protocol = "sha256WithRSAEncryption",
    jwt_header = {}
  }

  -- put jwt header in params to be able to override them if needed
  self.jwt_info.jwt_header = {
    alg = "RS256",
    typ = "JWT"
  }
  
  setmetatable(self, { __index = OAuth })

  return self
end

function OAuth:create_jwt_token()

  -- retrieve information that are in the key file
  if not self:get_key_file() then
    self.sc_logger:error("[google.auth.oauth:create_jwt]: an error occured while getting file: "
      .. tostring(self.jwt_info.key_file))
    
      return false
  end

  -- b64 encoded json of the jwt_header
  -- local jwt_header = mime.b64(broker.json_encode(self.jwt_info.jwt_header))
  local jwt_header = mime.b64(broker.json_encode(self.jwt_info.jwt_header))

  -- build the claim part of the jwt
  if not self:create_jwt_claim() then
    self.sc_logger:error("[google.auth.oauth:create_jwt]: an error occured while creating the jwt claim")

    return false
  end

  -- b64 encoded json of the jwt_claim
  local jwt_claim = mime.b64(broker.json_encode(self.jwt_claim))

  local string_to_sign = jwt_header .. "." .. jwt_claim

  -- sign our jwt_header and claim
  if not self:create_signature(string_to_sign) then
    self.sc_logger:error("[google.auth.oauth:create_jwt]: couldn't sign the concatenation of"
      .. " the JWT header and the JWT claim.")
    
    return false
  end

  -- create our jwt_token using the signature
  self.jwt_token = string_to_sign .. "." .. mime.b64(self.signature)

  return true
end


function OAuth:get_key_file()
  local file = io.open(self.jwt_info.key_file, "r")

  -- return false if we can't open the file
  if not file then
    self.sc_logger:error("[google.auth.oauth:get_key_file]: couldn't open file "
      .. tostring(self.jwt_info.key_file) .. ". Make sure your key file is there.")
    
      return false
  end

  local file_content = file:read("*a")
  io.close(file)

  local key_table = broker.json_decode(file_content)

  -- return false if json couldn't be parsed
  if (type(key_table) ~= "table") then
    self.sc_logger:error("[google.auth.oauth:get_key_file]: the key file "
      .. tostring(self.jwt_info.key_file) .. ". Is not a valid json file.")
    
    return false
  end

  self.key_table = key_table
  return true
end

function OAuth:create_jwt_claim()
  -- return false if there is a missing parameter in the key table
  if 
    not self.key_table.client_email or 
    not self.key_table.auth_uri or
    not self.key_table.token_uri or
    not self.key_table.private_key or
    not self.key_table.project_id
  then
    self.sc_logger:error("[google.auth.oauth:create_jwt_claim]: one of the following information wasn't found in the key_file:" 
      .. " client_email, auth_uri, token_uri, private_key or project_id. Make sure that "
      .. tostring(self.key_file) .. " is a valid key file.")
    return false
  end
  
  -- jwt claim time to live
  local iat = os.time()
  self.jwt_expiration_date = iat + 3600

  -- create jwt_claim table
  self.jwt_claim = {
    iss = self.key_table.client_email,
    aud = self.key_table.token_uri,
    scope = self.jwt_info.scope,
    iat = iat,
    exp = self.jwt_expiration_date
  }

  return true
end

function OAuth:create_signature(string_to_sign)
  local private_key_object = crypto.pkey.from_pem(self.key_table.private_key, true)

  if not private_key_object then
    self.sc_logger:error("[google.auth.oauth:create_signature]: couldn't create private key object using crypto lib and"
      .. " private key from key file " .. tostring(self.jwt_info.key_file))

    return false
  end

  local signature = crypto.sign(self.jwt_info.hash_protocol, string_to_sign, private_key_object)

  if not signature then
    self.sc_logger:error("[google.auth.oauth:create_signature]: couldn't sign string using crypto lib and the hash protocol: "
      .. tostring(self.jwt_info.hash_protocol))
    
    return false
  end

  self.signature = signature

  return true
end

function OAuth:get_access_token()
  if not self.access_token or os.time() > self.jwt_expiration_date - 60 then
    self.sc_logger:error("TOKEN : " .. tostring(self.access_token) .. " DATE" .. os.time() .. " EXP " .. tostring(self.jwt_expiration_date))
    self.sc_logger:warning("[google.auth.oauth:get_access_token]: no jwt_token found or jwt token expiration date has been reached."
      .. " Generating a new  JWT token") 
    
    if not self:create_jwt_token() then
      self.sc_logger:error("[google.auth.oauth:get_access_token]: couldn't generate a new JWT token.")

      return false
    end
  else 
    return self.access_token
  end

  local headers = {
    'Content-Type: application/x-www-form-urlencoded'
  }

  self.sc_logger:info("[google.auth.oauth:get_access_token]: sending jwt token " .. tostring(self.jwt_token))

  local data = {
    grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion = self.jwt_token
  }

  local result = broker.json_decode(self:curl_google(self.key_table.token_uri, headers, self.sc_common:generate_postfield_param_string(data)))
  
  if not result or not result.access_token then
    self.sc_logger:error("[google.auth.oauth:get_access_token]: couldn't get access token")
    return false
  end

  self.access_token = result.access_token

  return self.access_token
end

function OAuth:curl_google(url, headers, data)
  local res = ""
  local request = curl.easy()
    :setopt_url(url)
    :setopt_writefunction(function (response) 
      res = res .. response
    end)
  
  if data then
    request:setopt_postfields(data)
  end

  self.sc_logger:error("[google.auth.oauth:curl_google]: URL: " .. tostring(url) .. ". data " .. data)
  
  -- set proxy address configuration
  if (self.params.proxy_address ~= "" and self.params.proxy_address) then
    if (self.params.proxy_port ~= "" and self.params.proxy_port) then
      request:setopt(curl.OPT_PROXY, self.params.proxy_address .. ':' .. self.params.proxy_port)
    else 
      self.sc_logger:error("[google.auth.oauth:curl_google]: proxy_port parameter is not set but proxy_address is used")
    end
  end

  -- set proxy user configuration
  if (self.params.proxy_username ~= '' and self.params.proxy_username) then
    if (self.params.proxy_password ~= '' and self.params.proxy_username) then
      request:setopt(curl.OPT_PROXYUSERPWD, self.params.proxy_username .. ':' .. self.params.proxy_password)
    else
      self.sc_logger:error("[google.auth.oauth:curl_google]: proxy_password parameter is not set but proxy_username is used")
    end
  end

  request:setopt(curl.OPT_HTTPHEADER, headers)

  request:perform()
  local code = request:getinfo(curl.INFO_RESPONSE_CODE)

  if code ~= 200 then
    self.sc_logger:error("[google.auth.oauth:curl_google]: http code is: " .. tostring(code) .. ". Result is: " ..tostring(res))
    return false
  end

  return res

end

return oauth