--[[
	Let the gluon-provisioning proxy open this node's config mode.

	The proxy attaches a capability naming this node and expiring in a minute,
	signed with a key the node was given when it provisioned itself. The node
	checks it here and lets the request through - nothing is called back.

	That is the point. The scheme this replaces asked an auth server "is this
	token good?" and trusted a signed yes, which meant the server had to be
	reachable exactly when the mesh was in the state that made someone want to
	log in. Worse, the answer named no node, so a token minted for one node
	opened every node. A capability that names this node and this node only,
	verified offline, fixes both.
]]

local json = require 'luci.jsonc'
local openssl = require 'openssl'
local uci = require('simple-uci').cursor()
local util = require 'gluon.util'

--[[
	The capability travels in Authorization, not a header of our own: uhttpd
	hands a CGI a fixed list of headers (proc.c) and anything outside it never
	arrives at all - so a header of ours would simply be absent, and this would
	answer "no auth method could be used" with nothing to say why.
]]
local HEADER = 'AUTHORIZATION'
local BEARER = 'Bearer '
local VERSION = 'v1'

-- A node with no battery can boot believing it is 1970, so a capability from
-- "the future" is tolerated by this much before it is called a forgery.
local CLOCK_SKEW = 300

local function pubkey()
	return uci:get('gluon-config-mode-remote', 'remote', 'pubkey')
end

-- base64url, as the capability travels in a header
local function b64url_decode(value)
	local padded = value:gsub('-', '+'):gsub('_', '/')
	padded = padded .. string.rep('=', (4 - #padded % 4) % 4)
	return openssl.base64(padded, false)
end

local function verify(capability)
	local pem = pubkey()

	if not pem or pem == '' then
		return 'this node has not been given a config access key yet'
	end

	local version, payload, signature = capability:match('^(v%d+)%.([%w%-_]+)%.([%w%-_]+)$')

	if version ~= VERSION then
		return 'not a ' .. VERSION .. ' capability'
	end

	local key = openssl.pkey.read(pem)
	if not key then
		return 'the config access key is not readable'
	end

	--[[
		Signed over the encoded payload rather than what it decodes to, so both
		ends agree byte for byte with nobody having to canonicalise JSON.

		No digest argument: lua-openssl sees an Ed25519 key, passes NULL for the
		digest and takes OpenSSL's one-shot path. Versions before 0.11.1 have no
		such case and answer "invalid digest" instead, which is why the package
		depends on lua-openssl rather than taking whatever is on the image.
	]]
	if not key:verify(payload, b64url_decode(signature)) then
		return 'the capability is not signed by the key this node trusts'
	end

	local claim = json.parse(b64url_decode(payload))

	if type(claim) ~= 'table' then
		return 'the capability carries no claim'
	end

	if claim.node ~= util.node_id() then
		return string.format('the capability is for %s, this is %s',
			tostring(claim.node), util.node_id())
	end

	local now = os.time()

	if type(claim.exp) ~= 'number' or claim.exp < now then
		return 'the capability has expired'
	end

	if type(claim.iat) == 'number' and claim.iat > now + CLOCK_SKEW then
		return 'the capability is from the future; this node\'s clock may be wrong'
	end

	return nil, { identity = claim.identity or 'unknown' }
end

local function presented(http)
	local value = http:getheader(HEADER)

	if not value or value:sub(1, #BEARER) ~= BEARER then
		return nil
	end

	return value:sub(#BEARER + 1)
end

local function authorize(http)
	local capability = presented(http)

	if not capability then
		return 'no capability was presented'
	end

	local ok, err, res = pcall(verify, capability)

	if not ok then
		-- a malformed capability must read as refused, not as a crash
		return 'the capability could not be checked: ' .. tostring(err)
	end

	return err, res
end

local function detect(http)
	return presented(http) ~= nil and pubkey() ~= nil
end

return {
	name = 'proxy',
	display = 'Config proxy',
	detect = detect,
	authorize = authorize,
}
