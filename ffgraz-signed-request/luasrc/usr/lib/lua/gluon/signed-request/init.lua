local fetch = require 'luci.httpclient'
local json = require 'luci.jsonc'
local ecdsa = require 'ecdsa'
local util = require 'gluon.web.util'

local Signed = util.class()

function Signed:__init__(remote, key, tswindow)
	assert(remote)
	assert(key)
	self.tswindow = tswindow or 5 * 60
	self.remote = remote
	self.key = key
end

function Signed:fetch_signed_json(url)
	local code, res, result = fetch.request_raw(self.remote .. url)

	if code < 1 then
		return nil, code, 'failed to fetch'
	end

	if code == 404 then
		return nil, code, url .. ' does not exist'
	end

	if code ~= 200 then
		return nil, code, 'got status code ' .. code
	end

	-- cloudflare's reverse proxies send http chunked responses with chunk sizes
	-- for whatever reasons the chunk size gets smashed into the result
	-- this is a hack to fish it out, it is irrelevant on unaffected reverse proxies
	if result:find("{") > 1 then
		result = result:sub(result:find("{"), result:len())
	end
	if (result:reverse()):find("}") > 1 then
		result = result:sub(0, result:len() - (result:reverse()):find("}") + 1)
	end
	-- sometimes it also ends up in the result (it's usually a \n and another \n - will never mess with json as json escapes it)
	if result:find("\n") then
		result = result:sub(0, result:find("\n")) .. result:sub((result:reverse()):find("\n") + 1, result:len())
	end

	local sig = res.headers['x-ecdsa']
	local ts = res.headers['x-ecdsa-ts']

	if not sig or not ts then
		return nil, -1, 'provided response is not signed'
	end

	local tsi = tonumber(ts)
	local now = os.time()

	if now - tsi > self.tswindow then
		return nil, -1, 'response is too old'
	end

	if tsi > now then
		io.stderr:write(string.format('W: our clock is behind %s seconds\n', tsi - now))
	end

	local data = ts .. '@' .. result
	if not ecdsa.verify(data, sig, self.key) then
		return nil, -1, 'signature invalid or not signed with expected key'
	end

	local obj = json.parse(result)

	if obj == nil then
		return nil, -1, 'failed to parse json data'
	end

	return obj
end

function Signed:fetch_signed_text(url)
	local code, res, result = fetch.request_raw(self.remote .. url)

	if code < 1 then
		return nil, code, 'failed to fetch'
	end

	if code == 404 then
		return nil, code, url .. ' does not exist'
	end

	if code ~= 200 then
		return nil, code, 'got status code ' .. code
	end

	local sig = res.headers['x-ecdsa']
	local ts = res.headers['x-ecdsa-ts']

	if not sig or not ts then
		return nil, -1, 'provided response is not signed'
	end

	local tsi = tonumber(ts)
	local now = os.time()

	if now - tsi > self.tswindow then
		return nil, -1, 'response is too old'
	end

	if tsi > now then
		io.stderr:write(string.format('W: our clock is behind %s seconds\n', tsi - now))
	end

	local data = ts .. '@' .. result
	if not ecdsa.verify(data, sig, self.key) then
		return nil, -1, 'signature invalid or not signed with expected key'
	end

	return result
end

local function _instantiate(class, ...)
	local inst = setmetatable({}, {__index = class})

	if inst.__init__ then
		inst:__init__(...)
	end

	return inst
end

return Signed
