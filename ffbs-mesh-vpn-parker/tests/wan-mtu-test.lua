-- Test of util.wan_device() and util.wan_mtu() with mock routes and files.
-- luacheck: globals io
-- Run: lua5.1 tests/wan-mtu-test.lua (from the package directory).

package.path = "luasrc/usr/share/lua/?.lua;" .. package.path
package.preload["posix"] = function() return {} end

local routes, files

local real_popen, real_open = io.popen, io.open
io.popen = function(cmd)
	local out = assert(routes[cmd], cmd)
	return { read = function() return out end, close = function() end }
end
io.open = function(path)
	local content = files[path]
	if content == nil then
		return nil
	end
	return { read = function() return content end, close = function() end }
end

local util = require("util")

local V6 = "ip -6 route show table 1"
local V4 = "ip -4 route show table 1"
local UNREACH4 = "unreachable default dev lo proto static scope link metric 65535\n"
local UNREACH6 = "unreachable default dev lo proto static metric 65535 pref medium\n"

local failed = 0
local function check(name, got, want)
	local ok = got == want
	print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": got " .. tostring(got))))
	if not ok then failed = failed + 1 end
end

-- Wired uplink with IPv6 and IPv4.
routes = {
	[V6] = UNREACH6 .. "default from 2001:db8:1::/64 via fe80::1 dev br-wan proto static metric 512 pref medium\n",
	[V4] = UNREACH4 .. "default via 192.0.2.1 dev br-wan proto static src 192.0.2.10\n",
}
files = { ["/proc/sys/net/ipv6/conf/br-wan/mtu"] = "1500\n" }
check("wired: device", util.wan_device(), "br-wan")
check("wired: mtu", util.wan_mtu(), 1500)

-- Cellular uplink (qmi): IPv6 on wwan0, no br-wan.
routes = {
	[V6] = UNREACH6 .. "default from 2001:db8:2::/64 via 2001:db8:2::1 dev wwan0 proto static metric 512 pref medium\n",
	[V4] = UNREACH4 .. "default via 192.0.2.25 dev wwan0 proto static src 192.0.2.26\n",
}
files = { ["/proc/sys/net/ipv6/conf/wwan0/mtu"] = "1430\n" }
check("cellular: device", util.wan_device(), "wwan0")
check("cellular: mtu", util.wan_mtu(), 1430)

-- Cellular uplink with IPv4 only.
routes = {
	[V6] = UNREACH6,
	[V4] = UNREACH4 .. "default via 192.0.2.25 dev wwan0 proto static src 192.0.2.26\n",
}
check("cellular IPv4 only: device", util.wan_device(), "wwan0")
check("cellular IPv4 only: mtu", util.wan_mtu(), 1430)

-- No WAN route: only the unreachable routes.
routes = { [V6] = UNREACH6, [V4] = UNREACH4 }
check("no route: device", util.wan_device(), nil)
check("no route: mtu", util.wan_mtu(), nil)

-- WAN device without an IPv6 conf entry.
routes = {
	[V6] = UNREACH6,
	[V4] = UNREACH4 .. "default via 192.0.2.1 dev eth9 proto static\n",
}
files = {}
check("no ipv6 conf: mtu", util.wan_mtu(), nil)

io.popen, io.open = real_popen, real_open

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("all passed")
