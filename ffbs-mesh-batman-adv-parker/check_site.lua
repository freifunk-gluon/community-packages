-- /lib/gluon/radvd/arguments announces prefix6 next to the range of the
-- node, and uradvd always marks a prefix for SLAAC. Only a unique local
-- prefix keeps clients from using that second address as source for
-- internet traffic, which no concentrator routes back.
need(in_domain({ 'prefix6' }), function(prefix)
	return type(prefix) == 'string' and prefix:lower():match('^f[cd]%x%x:') ~= nil
end, false, 'be a unique local prefix (fc00::/7), because the nodes announce it '
	.. 'to their clients next to their routed range')

-- Router lifetime and RA interval of /lib/gluon/radvd/arguments. uradvd
-- refuses to start on values outside the limits of RFC 4861 section 6.2.1,
-- so check them here, together with the fallbacks the script uses for unset
-- keys.
local function is_int(v)
	return type(v) == 'number' and v == math.floor(v)
end

local default_lifetime = need_number_range({ 'radvd', 'default_lifetime' }, 0, 9000, false)
local min_interval = need_number_range({ 'radvd', 'min_interval' }, 3, 1350, false)
local max_interval = need_number_range({ 'radvd', 'max_interval' }, 4, 1800, false)

for _, key in ipairs({ 'default_lifetime', 'min_interval', 'max_interval' }) do
	need({ 'radvd', key }, is_int, false, 'be an integer')
end

local max = max_interval or 50
need({ 'radvd', min_interval and 'min_interval' or 'max_interval' }, function()
	return (min_interval or 20) <= 0.75 * max
end, false, 'leave radvd.min_interval (default 20) at most 0.75 * radvd.max_interval (default 50)')

if default_lifetime and default_lifetime ~= 0 then
	need({ 'radvd', 'default_lifetime' }, function(v) return v >= max end, true,
		'be 0 or at least radvd.max_interval (default 50)')
end
