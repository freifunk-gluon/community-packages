local posix = require("posix")

local util = {}

function util.read_file(path)
	local file = io.open(path, "rb") -- r read mode and b binary mode
	if not file then
		return nil
	end
	local content = file:read("*a") -- *a or *all reads the whole file
	file:close()
	return content
end

function util.write_file(path, content)
	-- Replace a file in one step, so that a service reading it while we
	-- write never gets to see half of it.
	local tmp = path .. ".tmp"
	local file = io.open(tmp, "w")
	if not file then
		return false
	end
	file:write(content)
	file:close()
	return os.rename(tmp, path) ~= nil
end

function util.str_split(str, pattern)
	local res = {}
	for i in string.gmatch(str, pattern) do
		table.insert(res, i)
	end
	return res
end

function util.has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

function util.check_output(cmd)
	local f = assert(io.popen(cmd, "r"))
	local s = assert(f:read("*a"))
	f:close()
	return s
end

function util.tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

function util.nslookup(host, family)
	-- Resolve a hostname to the first address the resolver returns.
	--
	-- Arguments:
	-- * host: The hostname to resolve.
	-- * family: Optional address family (posix.sys.socket.AF_INET or
	--   posix.sys.socket.AF_INET6) to restrict the lookup to.

	local hints = { protocol = posix.sys.socket.IPPROTO_UDP }
	if family ~= nil then
		hints.family = family
	end
	local ans = posix.sys.socket.getaddrinfo(host, nil, hints)
	if not ans or not ans[1] then
		return nil
	else
		return ans[1].addr
	end
end

function util.prefer_ipv6()
	-- Check whether the WAN has an IPv6 default route. If it has, we want to
	-- reach our concentrators over IPv6, otherwise over IPv4.
	-- This mirrors what checkuplink of ffmuc-mesh-vpn-wireguard-vxlan does.

	for line in string.gmatch(util.check_output("ip -6 route show table 1"), "[^\n]+") do
		if string.find(line, "^default") then
			return true
		end
	end
	return false
end

function util.split_endpoint(endpoint)
	-- Split an endpoint into its host and its port part.
	-- Understands "host:port" as well as "[v6-address]:port".
	-- Returns nil if the endpoint is not in one of these formats.

	local host, port = string.match(endpoint, "^%[(.+)%]:(%d+)$")
	if host == nil then
		host, port = string.match(endpoint, "^([^:]+):(%d+)$")
	end
	return host, port
end

function util.join_endpoint(address, port)
	-- Build an endpoint from an address and a port.
	-- Wireguard expects IPv6 addresses to be enclosed in brackets and
	-- reports them the same way.

	if string.find(address, ":", 1, true) ~= nil then
		return "[" .. address .. "]:" .. port
	end
	return address .. ":" .. port
end

function util.resolve_endpoint(endpoint, ipv6_first)
	-- Resolve the host part of an endpoint to an IP address.
	--
	-- Wireguard resolves an endpoint once, when it is configured, and from
	-- then on only reports the resolved address. Resolving the endpoint
	-- ourselves keeps the comparison with the running configuration a
	-- comparison of two IP addresses.
	--
	-- Returns nil if the endpoint can neither be parsed nor resolved.
	--
	-- Arguments:
	-- * endpoint: The endpoint as received from the config service.
	-- * ipv6_first: Whether to prefer IPv6 over IPv4 addresses.

	local host, port = util.split_endpoint(endpoint)
	if host == nil then
		return nil
	end
	if string.find(host, ":", 1, true) ~= nil or string.match(host, "^%d+%.%d+%.%d+%.%d+$") ~= nil then
		-- The endpoint already contains an IP address. Nothing to resolve.
		return util.join_endpoint(host, port)
	end

	local families = { posix.sys.socket.AF_INET, posix.sys.socket.AF_INET6 }
	if ipv6_first then
		families = { posix.sys.socket.AF_INET6, posix.sys.socket.AF_INET }
	end
	for _, family in ipairs(families) do
		local address = util.nslookup(host, family)
		if address ~= nil then
			return util.join_endpoint(address, port)
		end
	end
	return nil
end

function util.get_wg_info()
	local output = util.check_output("wg show all dump")
	local results = {}
	for lineRaw in string.gmatch(output, "[^\n]+") do
		local line = util.str_split(lineRaw, "%S+")
		if not results[line[1]] then
			local device = {}
			device["private_key"] = line[2]
			device["public_key"] = line[3]
			device["listen_port"] = tonumber(line[4])
			device["peers"] = {}
			results[line[1]] = device
		else
			local peer = {}
			if line[3] ~= "(none)" then
				peer["preshared_key"] = line[3]
			end
			peer["endpoint"] = line[4]
			peer["allowed-ips"] = util.str_split(line[5], "[^,]+")
			peer["latest_handshake"] = tonumber(line[6])
			peer["transfer_rx"] = tonumber(line[7])
			peer["transfer_tx"] = tonumber(line[8])
			peer["persistent_keepalive"] = tonumber(line[9])
			results[line[1]]["peers"][line[2]] = peer
		end
	end
	return results
end

function util.sleep(n)
	posix.unistd.sleep(n)
end

function util.wait_for(condition, timeout)
	-- Wait until condition() returns true.
	-- Gives up after timeout seconds and returns whether the condition
	-- has been met.
	for _ = 1, timeout do
		if condition() then
			return true
		end
		util.sleep(1)
	end
	return condition()
end

local random_seeded = false
function util.shuffle(tbl)
	if not random_seeded then
		local urandom = assert(io.open("/dev/urandom", "rb"))
		local a, b, c = urandom:read(3):byte(1, 3)
		urandom:close()
		math.randomseed(a * 0x10000 + b * 0x100 + c)
		random_seeded = true
	end
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

util.loggername = "lua"
function util.log(s)
	os.execute("logger -s -t" .. util.loggername .. " " .. s)
end

return util
