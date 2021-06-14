# Documentation of the google oauth module

- [Documentation of the google oauth module](#documentation-of-the-google-oauth-module)
  - [Introduction](#introduction)
  - [Module initialization](#module-initialization)
    - [Module constructor](#module-constructor)
    - [constructor: Example](#constructor-example)
  - [create_jwt_token method](#create_jwt_token-method)
    - [create_jwt_token: returns](#create_jwt_token-returns)
    - [create_jwt_token: example](#create_jwt_token-example)
  - [get_key_file method](#get_key_file-method)
    - [get_key_file: returns](#get_key_file-returns)
    - [get_key_file: example](#get_key_file-example)
  - [create_jwt_claim method](#create_jwt_claim-method)
    - [create_jwt_claim: returns](#create_jwt_claim-returns)
    - [create_jwt_claim: example](#create_jwt_claim-example)
  - [create_signature method](#create_signature-method)
    - [create_signature: returns](#create_signature-returns)
    - [create_signature: example](#create_signature-example)
  - [get_access_token method](#get_access_token-method)
    - [get_access_token: returns](#get_access_token-returns)
    - [get_access_token: example](#get_access_token-example)
  - [curl_google method](#curl_google-method)
    - [curl_google: parameters](#curl_google-parameters)
    - [curl_google: returns](#curl_google-returns)
    - [curl_google: example](#curl_google-example)

## Introduction

The google oauth module provides methods to help with google api authentication. It has been made in OOP (object oriented programming)

## Module initialization

Since this is OOP, it is required to initiate your module

### Module constructor

Constructor can be initialized with three parameters, if the third one is not provided it will use a default value

- params. This is a table of all the stream connectors parameters
- sc_common. This is an instance of the sc_common module
- sc_logger. This is an instance of the sc_logger module

If you don't provide the sc_logger parameter it will create a default sc_logger instance with default parameters ([sc_logger default params](./sc_logger.md#module-initialization))

### constructor: Example

```lua
-- load modules
local sc_logger = require("centreon-stream-connectors-lib.sc_logger")
local sc_common = require("centreon-stream-connectors-lib.sc_common")
local oauth = require("centreon-stream-connecotrs-lib.google.auth.oauth")

-- initiate "mandatory" informations for the logger module
local logfile = "/var/log/test_logger.log"
local severity = 1

-- create a new instance of the sc_common and sc_logger module
local test_logger = sc_logger.new(logfile, severity)
local test_common = sc_common.new(test_logger)

-- some stream connector params
local params = {
  my_param = "my_value"
}

-- create a new instance of the google oauth param module
local test_oauth = oauth.new(params, test_common, test_logger)
```

## create_jwt_token method

The **create_jwt_token** method create a jwt token. More information about the google JWT token [here](https://developers.google.com/identity/protocols/oauth2/service-account#authorizingrequests)

head over the following chapters for more information

- [get_key_file](#get_key_file-method)
- [create_jwt_claim](#create_jwt_claim-method)
- [create_signature](#create_signature-method)

### create_jwt_token: returns

| return        | type    | always | condition                                     |
| ------------- | ------- | ------ | --------------------------------------------- |
| true or false | boolean | yes    | true if jwt token is created, false otherwise |

### create_jwt_token: example

```lua

local result = test_oauth:create_jwt_token()
--> result is true or false
--> jwt token is stored in test_oauth.jwt_token if result is true
```

## get_key_file method

The **get_key_file** method get information set in the key file. To do so, the **key_file_path** parameter must be set.

### get_key_file: returns

| return        | type    | always | condition                                                  |
| ------------- | ------- | ------ | ---------------------------------------------------------- |
| true or false | boolean | yes    | true if key file information is retrieved, false otherwise |

### get_key_file: example

```lua

local result = test_oauth:get_key_file()
--> result is true or false
--> key file data  is stored in test_oauth.key_table if result is true
```

## create_jwt_claim method

The **create_jwt_claim** method create the claim for a jwt token. To do so, the **scope_list** and **project_id** paramters must be set. More information about the google JWT token and claim [here](https://developers.google.com/identity/protocols/oauth2/service-account#authorizingrequests)

### create_jwt_claim: returns

| return        | type    | always | condition                                     |
| ------------- | ------- | ------ | --------------------------------------------- |
| true or false | boolean | yes    | true if jwt claim is created, false otherwise |

### create_jwt_claim: example

```lua

local result = test_oauth:create_jwt_claim()
--> result is true or false
--> jwt token is stored in test_oauth.jwt_claim if result is true
```

## create_signature method

The **create_signature** method create the signature of the JWT claim and JWT header. To match google needs, the hash protocol used is **sha256WithRSAEncryption**. More information about the google JWT token [here](https://developers.google.com/identity/protocols/oauth2/service-account#authorizingrequests)

### create_signature: returns

| return        | type    | always | condition                                            |
| ------------- | ------- | ------ | ---------------------------------------------------- |
| true or false | boolean | yes    | true if the signature has been done, false otherwise |

### create_signature: example

```lua

local result = test_oauth:create_signature()
--> result is true or false
--> signature is stored in test_oauth.signature if result is true
```

## get_access_token method

The **get_access_token** method get an access token from the google api using a jwt token. It will use an existing one if it founds one. Access token life span is one hour. This method will generate a new one if the access token is at least 59 minutes old. To generate a new access token, this method will need to create a new jwt token.

head over the following chapters for more information

- [get_jwt_token](#get_jwt_token-method)

### get_access_token: returns

| return       | type    | always | condition                       |
| ------------ | ------- | ------ | ------------------------------- |
| false        | boolean | no     | if it can't get an access token |
| access_token | string  | no     | if it can get an access token   |

### get_access_token: example

```lua

local result = test_oauth:get_access_token()
--> result is "dzadz93213daznc321OGRK" or false if access token is not retrieved
```

## curl_google method

The **curl_google** method send data to the google api for authentication.

### curl_google: parameters

| parameter                    | type   | optional | default value |
| ---------------------------- | ------ | -------- | ------------- |
| the url of the google api    | string | no       |               |
| the curl headers             | table  | no       |               |
| data that needs to be posted | string | yes      |               |

### curl_google: returns

| return          | type    | always | condition                                                                |
| --------------- | ------- | ------ | ------------------------------------------------------------------------ |
| false           | boolean | no     | if it can't get an access token http code 200 or can't access google api |
| result from api | string  | no     | if the query went well                                                   |

### curl_google: example

```lua
-- set up headers
local headers = {
  'Content-Type: application/x-www-form-urlencoded'
}

-- set up data 
local data = {
  grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
  assertion = test_oauth.jwt_token
}

-- set up url
local url = test_oauth.key_table.uri

-- convert data so it can be sent as url parameters
local url_encoded_data = test_common:generate_postfield_param_string(data)

local result = test_oauth:curl_google()
--> result false or data (should be json most of the time)
```
