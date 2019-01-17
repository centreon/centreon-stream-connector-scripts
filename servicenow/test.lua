local http=require("socket.http");
local ltn12 = require("ltn12")

local request_body = [[login=user&password=123]]
local response_body = {}

local res, code, response_headers = http.request{
    url = "http://httpbin.org/post",
    method = "POST",
    headers =
      {
          ["Content-Type"] = "application/x-www-form-urlencoded";
          ["Content-Length"] = #request_body;
      },
      source = ltn12.source.string(request_body),
      sink = ltn12.sink.table(response_body),
}

print(res)
print(code)

if type(response_headers) == "table" then
  for k, v in pairs(response_headers) do
    print(k, v)
  end
end

print("Response body:")
if type(response_body) == "table" then
  print(table.concat(response_body))
else
  print("Not a table:", type(response_body))
end
