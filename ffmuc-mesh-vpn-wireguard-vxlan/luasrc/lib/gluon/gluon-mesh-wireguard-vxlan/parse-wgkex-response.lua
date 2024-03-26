-- check whether an argument was passed
if arg[1] == "" then
    error("Malformed JSON response, no data provided")
end

local json = require 'jsonc'

local input = assert(arg[1])
local data = assert(json.parse(input))

-- v1
if data.Message == "OK" then
        return
end

-- v2
if not data.Endpoint or not data.Endpoint.Address or not data.Endpoint.Port
    or not data.Endpoint.PublicKey or not data.Endpoint.AllowedIPs or not data.Endpoint.AllowedIPs[1] then
    error("Malformed JSON response, missing required value")
end

print(data.Endpoint.Address)
print(data.Endpoint.Port)
print(data.Endpoint.PublicKey)
print(data.Endpoint.AllowedIPs[1])
