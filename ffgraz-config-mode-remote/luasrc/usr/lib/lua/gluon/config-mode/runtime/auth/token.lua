local site = require 'gluon.site'

local SignedRequest = require 'gluon.signed-request'

local charset = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890"

math.randomseed(os.time())

local function randomString(length)
	local ret = {}
	local r
	for _ = 1, length do
		r = math.random(1, #charset)
		table.insert(ret, charset:sub(r, r))
	end
	return table.concat(ret)
end

local function authorize(http)
  local token = http:getquery('token')

  local signed = SignedRequest(site.config_mode_remote.authurl(), site.config_mode_remote.key())

  local challenge = randomString(32)

  local res, err, errmsg = signed:fetch_signed_json('/callback/' .. token .. '/' .. challenge)

  if res.challenge ~= challenge then
    return 'challenge failed'
  end

  if not res or err then
    return errmsg or err or 'failed to fetch from authurl'
  end

  return nil, { identity = res.identity or 'unknown' }
end

local function detect (http)
  return http:hasquery('token') and site.config_mode_remote.authurl()
end

return {
  name = 'token',
  display = 'Token',
  detect = detect,
  authorize = authorize,
}
