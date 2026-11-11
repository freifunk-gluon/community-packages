local json = require("jsonc")
local posix = require("posix")
local util = require("util")
local uci = require('simple-uci').cursor()

local config_file = arg[1]
local nonce = arg[2]
local tmpdir = arg[3]

local PRIVKEY = "/etc/parker/wg-privkey"

-- The MTU the kernel uses for IPv6 on the WAN. That is the number the
-- config service sizes our tunnels from (see nodeconfig.sh), and with an
-- upstream that announces a smaller MTU in its router advertisements --
-- DS-Lite, most notably -- it is smaller than the link MTU of br-wan.
local WAN_MTU_FILE = "/proc/sys/net/ipv6/conf/br-wan/mtu"

-- What Wireguard puts in front of every packet it sends: 16 bytes of its
-- own header, a 16 byte authentication tag, the UDP header and the IP
-- header of the family the endpoint lives in.
local WG_OVERHEAD = { [4] = 20 + 8 + 32, [6] = 40 + 8 + 32 }

-- IPv6 needs 1280 bytes on every link. Sizing a tunnel below that makes
-- the kernel drop IPv6 from the interface, which is the only thing that
-- travels through it in 464XLAT mode.
local MIN_MTU = 1280

util.loggername = "nodeconfig.lua"

local function prefer_ipv6()
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

local function split_endpoint(endpoint)
	-- Split an endpoint into its host and its port part.
	-- Understands "host:port" as well as "[v6-address]:port".
	-- Returns nil if the endpoint is not in one of these formats.

	local host, port = string.match(endpoint, "^%[(.+)%]:(%d+)$")
	if host == nil then
		host, port = string.match(endpoint, "^([^:]+):(%d+)$")
	end
	return host, port
end

local function join_endpoint(address, port)
	-- Build an endpoint from an address and a port.
	-- Wireguard expects IPv6 addresses to be enclosed in brackets and
	-- reports them the same way.

	if string.find(address, ":", 1, true) ~= nil then
		return "[" .. address .. "]:" .. port
	end
	return address .. ":" .. port
end

local function resolve_endpoint(endpoint, ipv6_first)
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

	local host, port = split_endpoint(endpoint)
	if host == nil then
		return nil
	end
	if string.find(host, ":", 1, true) ~= nil or string.match(host, "^%d+%.%d+%.%d+%.%d+$") ~= nil then
		-- The endpoint already contains an IP address. Nothing to resolve.
		return join_endpoint(host, port)
	end

	local families = { posix.sys.socket.AF_INET, posix.sys.socket.AF_INET6 }
	if ipv6_first then
		families = { posix.sys.socket.AF_INET6, posix.sys.socket.AF_INET }
	end
	for _, family in ipairs(families) do
		local address = util.nslookup(host, family)
		if address ~= nil then
			return join_endpoint(address, port)
		end
	end
	return nil
end

local function endpoint_family(endpoint)
	-- The address family a resolved endpoint lives in. join_endpoint()
	-- puts IPv6 addresses in brackets, the same way wg reports them.

	if string.sub(endpoint, 1, 1) == "[" then
		return 6
	end
	return 4
end

local function wan_mtu()
	-- The MTU our packets have to fit into on their way out, or nil while
	-- the WAN is not up yet.

	return tonumber(util.read_file(WAN_MTU_FILE) or "")
end

local function tunnel_mtu(conf, endpoint)
	-- The MTU a tunnel to this endpoint may use: what is left of the WAN
	-- MTU once Wireguard has added its headers, but never more than the
	-- config service allows.
	--
	-- The config service is only told our WAN MTU, so it cannot know
	-- whether we end up talking to a concentrator over IPv6 or over IPv4,
	-- which differ by the 20 bytes between the two IP headers. Sizing the
	-- interface is therefore ours to finish.
	--
	-- Arguments:
	-- * conf: The configuration received from the config service.
	-- * endpoint: The resolved endpoint of the concentrator.

	local wan = wan_mtu()
	if wan == nil then
		-- Nothing to improve on without a WAN MTU.
		return conf.mtu
	end

	local mtu = math.min(conf.mtu, wan - WG_OVERHEAD[endpoint_family(endpoint)])
	if mtu < MIN_MTU then
		util.log("A tunnel MTU of " .. mtu .. " would not carry IPv6. Using " .. MIN_MTU .. " instead")
		return MIN_MTU
	end
	return mtu
end

local function link_mtu(iface)
	-- The MTU an interface currently has, or nil if there is no such
	-- interface.

	return tonumber(util.read_file("/sys/class/net/" .. iface .. "/mtu") or "")
end

local function set_link_mtu(iface, mtu)
	-- Resize an interface, unless it already has the MTU we want. Every
	-- run of this script would otherwise resize every tunnel it finds.

	if link_mtu(iface) == mtu then
		return
	end
	util.log("Updating MTU on wg-interface " .. iface .. " to " .. mtu)
	os.execute("ip link set dev " .. iface .. " mtu " .. mtu)
end

local function wg_allowed_ips(conf)
	-- Determine the allowed-ips our peers should be configured with.
	--
	-- With 464XLAT enabled all IPv4 traffic is translated to IPv6 before it
	-- reaches Wireguard. Allowing IPv4 on the tunnel would only permit
	-- traffic that cannot occur in that case.
	--
	-- Arguments:
	-- * conf: The configuration received from the config service.

	if conf.xlat_range6 ~= nil then
		return { "::/0" }
	end
	return { "0.0.0.0/0", "::/0" }
end

local function same_allowed_ips(current_ips, target_ips)
	-- Compare two lists of allowed-ips, ignoring their order.
	if util.tablelength(current_ips) ~= util.tablelength(target_ips) then
		return false
	end
	for _, ip in ipairs(target_ips) do
		if not util.has_value(current_ips, ip) then
			return false
		end
	end
	return true
end

local function conf_wg_iface(iface, privkey, peers, keepalive, allowed_ips)
	-- Configure Wireguard parameters on an existing wg-interface
	-- Every peer needs a resolved_endpoint, see resolve_endpoint().
	local cmd = "wg set " .. iface .. " fwmark 1 "
	if privkey ~= nil then
		cmd = cmd .. " private-key " .. privkey
	end
	for _, peer in pairs(peers) do
		cmd = cmd .. " peer " .. peer.pubkey .. " endpoint " .. peer.resolved_endpoint
		cmd = cmd .. " persistent-keepalive " .. keepalive .. " allowed-ips " .. table.concat(allowed_ips, ",")
	end
	os.execute(cmd)
end

local function conf_tc_iface(iface)
	-- Sets traffic limits on this interface.
	-- The traffic limits are defined by the user in config-mode.
	-- So for this script we can assume that these values will not change.
	-- That means it is sufficient to call set these values once
	-- when creating the interface.
	--
	-- Arguments:
	-- * iface: The name of the interface to set the traffic limits on.

	local enabled = uci:get_first("gluon", "mesh_vpn", "limit_enabled")
	local ingress = uci:get_first("gluon", "mesh_vpn", "limit_ingress")
	local egress = uci:get_first("gluon", "mesh_vpn", "limit_egress")

	if enabled == "1" then
		util.log("Enabling traffic shaping for " .. iface .. " with ingress " .. ingress .. " and egress " .. egress)
		os.execute("simple-tc " .. iface .. " " .. ingress .. " " .. egress)
	else
		-- Since the system boots without traffic limits in place there is no
		-- need for us to reset these values, if limit is not enabled.
		util.log("No traffic shaping configured. Skipping setup for " .. iface)
	end
end

local function apply_wg(conf)
	-- Make sure the Wireguard interfaces on this system match
	-- the configuration we've got from the config service.
	--
	-- Arguments:
	-- * conf: The configuration received from the config service.

	local current = util.get_wg_info()
	local target_ifaces = {}
	local allowed_ips = wg_allowed_ips(conf)
	local ipv6_first = prefer_ipv6()

	-- Create wg-interfaces defined in the configuration, if they
	-- do not exist yet.
	for _, conc in pairs(conf.concentrators) do
		local iface = "wg_c" .. conc.id
		conc.resolved_endpoint = resolve_endpoint(conc.endpoint, ipv6_first)
		if conc.resolved_endpoint == nil and current[iface] == nil then
			-- Without an endpoint there is nothing we could configure on a
			-- new interface. Let's try again on the next run.
			util.log("Unable to resolve endpoint " .. conc.endpoint .. ". Not creating wg-interface " .. iface)
		else
			target_ifaces[iface] = conc
			if current[iface] == nil then
				local mtu = tunnel_mtu(conf, conc.resolved_endpoint)
				util.log("Creating wg-interface " .. iface .. " with mtu " .. mtu)
				os.execute("ip link add " .. iface .. " type wireguard")
				os.execute("ip link set dev " .. iface .. " mtu " .. mtu)
				conf_wg_iface(iface, PRIVKEY, { conc }, conf.wg_keepalive, allowed_ips)
				util.log("Setting wg-interface " .. iface .. " up")
				os.execute("ip link set up " .. iface)
				conf_tc_iface(iface)
			elseif conc.resolved_endpoint ~= nil then
				-- An interface is sized for the endpoint it is about to be
				-- configured with. While that endpoint is unresolvable we
				-- keep the peer as it is, so its MTU stays as well.
				set_link_mtu(iface, tunnel_mtu(conf, conc.resolved_endpoint))
			end
		end
	end

	for iface, wg_conf in pairs(current) do
		if target_ifaces[iface] == nil then
			-- Remove interfaces that are not part of the configuration anymore.
			-- This can happen if the config service has decided that we should
			-- connect to other concentrators from now on.
			util.log("Removing wg-interface " .. iface)
			os.execute("ip link del " .. iface)
		else
			-- Update configuration on existing interfaces to what the config
			-- service has told us to use.
			local target = target_ifaces[iface]
			if target.resolved_endpoint == nil then
				-- Never hand an unresolved endpoint to wg. Keep whatever
				-- Wireguard is using at the moment and try again later.
				util.log("wg-iface " .. iface .. ": Unable to resolve endpoint " .. target.endpoint)
				util.log("wg-iface " .. iface .. ": Not reconfiguring this interface.")
			elseif util.tablelength(wg_conf.peers) <= 1 then
				local do_it = false
				-- Check all the configurations of the interface.
				if util.tablelength(wg_conf.peers) == 0 then
					util.log("wg-iface " .. iface .. ": Creating peer " .. target.pubkey)
					do_it = true
				else
					local cur_conf = {}
					for pubkey, peer in pairs(wg_conf.peers) do -- runs only once, just one entry
						cur_conf.pubkey = pubkey
						cur_conf.endpoint = peer.endpoint
						cur_conf.keepalive = peer.persistent_keepalive
						cur_conf.allowed_ips = peer["allowed-ips"]
					end
					if cur_conf.pubkey ~= target.pubkey then
						util.log(
							"wg-iface " .. iface .. ": Replacing peer " .. cur_conf.pubkey .. " with " .. target.pubkey
						)
						os.execute("wg set " .. iface .. " peer " .. cur_conf.pubkey .. " remove")
						do_it = true
					else
						if cur_conf.endpoint ~= target.resolved_endpoint then
							util.log(
								"wg-iface "
									.. iface
									.. ": Reconfiguring peer "
									.. cur_conf.pubkey
									.. ". Endpoint has changed from "
									.. cur_conf.endpoint
									.. " to "
									.. target.resolved_endpoint
							)
							do_it = true
						end
						if cur_conf.keepalive ~= conf.wg_keepalive then
							util.log(
								"wg-iface "
									.. iface
									.. ": Reconfiguring peer "
									.. cur_conf.pubkey
									.. ". Keepalive has changed from "
									.. cur_conf.keepalive
									.. " to "
									.. conf.wg_keepalive
							)
							do_it = true
						end
						if not same_allowed_ips(cur_conf.allowed_ips, allowed_ips) then
							util.log(
								"wg-iface "
									.. iface
									.. ": Reconfiguring peer "
									.. cur_conf.pubkey
									.. ". Allowed IPs have changed from "
									.. table.concat(cur_conf.allowed_ips, ",")
									.. " to "
									.. table.concat(allowed_ips, ",")
							)
							do_it = true
						end
					end
				end
				if do_it then
					-- The active configuration differs from the received configuration.
					-- Let's update it.
					conf_wg_iface(iface, PRIVKEY, { target }, conf.wg_keepalive, allowed_ips)
				end
			else
				-- Our Wireguard interfaces should always only have one peer.
				-- If they have more than one the user has tinkered with the configuation.
				-- Let's keep our hands this system, but still warn the user.
				util.log("wg-iface " .. iface .. ": Has more than one peer configured. Not reconfiguring this interface.")
				util.log("wg-iface " .. iface .. ": This is an error in the local configuration!")
			end
		end
	end

	-- check ip addresses
	for iface, conc in pairs(target_ifaces) do
		local state = util.check_output("ip addr show dev " .. iface)
		-- check ipv4
		if string.find(state, "inet " .. conf.address4 .. " peer " .. conc.address4) == nil then
			util.log("Updating IPv4 addr on wg-iface " .. iface)
			os.execute("ip -4 addr flush dev " .. iface .. " scope global")
			os.execute("ip -4 addr add " .. conf.address4 .. "/32 peer " .. conc.address4 .. " dev " .. iface)
		end
		-- check ipv6
		if string.find(state, "inet6 " .. conf.address6 .. " peer " .. conc.address6) == nil then
			util.log("Updating IPv6 addr on wg-iface " .. iface)
			os.execute("ip -6 addr flush dev " .. iface .. " scope global")
			os.execute("ip -6 addr replace " .. conf.address6 .. "/128 peer " .. conc.address6 .. " dev " .. iface)
		end
	end

	-- reload ebpf-clat, but only when it is already running.
	-- this ensures that clat is also active for any newly added interfaces
	if util.read_file("/etc/init.d/ebpf-clat") ~= nil then
		util.log("Reloading ebpf-clat")
		os.execute("/etc/init.d/ebpf-clat running && /etc/init.d/ebpf-clat reload")
	end

	return true
end

local function apply_time(conf)
	-- Make sure the system time is within 60 s of the time
	-- communicated in the configuration.
	-- (A somewhat correct system time is needed for Wireguard
	-- to work. But we do not want to get in the way if the system
	-- already has a time source.)
	local t = conf.time
	if math.abs(os.time() - t) > 60 then
		util.log("System time set to " .. t)
		os.execute("date -s @" .. t)
	end
	return true
end

util.log("Starting up")

local conf = json.parse(util.read_file(config_file))

if conf.nonce ~= nonce then
	util.log("nonce does not match")
	os.exit(1)
end

if conf.id ~= nil then
	-- we got data, let's do stuff
	apply_time(conf)
	local res_wg = apply_wg(conf)

	-- the config has been validated.
	-- do an atomic replace in $tmpdir where noderoute.lua will
	-- fetch it from.
	os.execute("cp " .. config_file .. " " .. config_file .. ".copy")
	os.execute("mv " .. config_file .. ".copy " .. tmpdir .. "/noderoute.json")
	if not res_wg then
		os.exit(1)
	end
else
	util.log("conf.id not set")
end

util.log("done")
print(conf.retry)
