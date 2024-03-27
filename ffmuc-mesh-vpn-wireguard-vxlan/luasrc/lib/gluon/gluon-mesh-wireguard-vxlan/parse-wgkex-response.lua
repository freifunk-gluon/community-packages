local json = require 'jsonc'

local input = assert(arg[1], "Malformed JSON response, no data provided")
local data = assert(json.parse(input), "Malformed JSON response, wrong JSON format")

-- v1
if data.Message == "OK" then
        return
end

-- v2
assert(data.Endpoint, "Malformed JSON response, missing required value: Endpoint")
local address = assert(data.Endpoint.Address, "Malformed JSON response, missing required value: Address")
local port = assert(data.Endpoint.Port, "Malformed JSON response, missing required value: Port")
local publicKey = assert(data.Endpoint.PublicKey, "Malformed JSON response, missing required value: PublicKey")
assert(data.Endpoint.AllowedIPs, "Malformed JSON response, missing required value: AllowedIPs")
local allowedIPs1 = assert(data.Endpoint.AllowedIPs[1], "Malformed JSON response, missing required value: AllowedIPs1")

print(address)
print(port)
print(publicKey)
print(allowedIPs1)
