local glob = require 'posix.glob'

local http = {}

function http:getenv(env)
	return os.getenv(env)
end

function http:hasenv(env)
	return self:getenv(env) ~= nil
end

function http:getheader(header)
	return self:getenv('HTTP_' .. header)
end

function http:hasheader(header)
	return self:getheader(header) ~= nil
end

function http:getquery(varname)
	local value = nil

	local query = self:getenv('QUERY_STRING')

	if query ~= nil then
		query = '&' .. query
		varname = '&' .. varname .. '='
		local _, q = string.find(query, varname)
		if q ~= nil then
			local p = string.find(query, '&', q)
			if p == nil then p = -1 else p = p - 1 end
			value = string.sub(query, q + 1, p)
		end
	end

	return value
end

function http:hasquery(query)
	return self:getquery(query) ~= nil
end

local methods = {}

for _, path in ipairs(glob.glob('/usr/lib/lua/gluon/config-mode/runtime/auth/*.lua', 0) or {}) do
	local fnc = assert(loadfile(path))

	local method = assert(fnc())

	methods[method.name] = method
end

local function authenticate()
	-- returns (null or error), info
	for name, method in pairs(methods) do
		if method.detect(http) then
			local err, res = method.authorize(http)

			if err then
				return string.format('%s: %s', name, err)
			end

			assert(res)

			res.method = method

			return nil, res
		end
	end

	return 'auth: no auth method could be used'
end

return authenticate
