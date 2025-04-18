local json = require("jsonc")
local util = require("util")
local uci = require('simple-uci').cursor()

local config_file = arg[1]
local nonce = arg[2]
local tmpdir = arg[3]

local PRIVKEY = "/etc/parker/wg-privkey"

util.loggername = "nodeconfig.lua"

local function conf_wg_iface(iface, privkey, peers, keepalive)
	-- Configure Wireguard parameters on an existing wg-interface
	local cmd = "wg set " .. iface .. " fwmark 1 "
	if privkey ~= nil then
		cmd = cmd .. " private-key " .. privkey
	end
	for _, peer in pairs(peers) do
		cmd = cmd .. " peer " .. peer.pubkey .. " endpoint " .. peer.endpoint
		cmd = cmd .. " persistent-keepalive " .. keepalive .. " allowed-ips 0.0.0.0/0,::/0"
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

	-- Create wg-interfaces defined in the configuration, if they
	-- do not exist yet.
	for _, conc in pairs(conf.concentrators) do
		local iface = "wg_c" .. conc.id
		target_ifaces[iface] = conc
		if current[iface] == nil then
			util.log("Creating wg-interface " .. iface .. " with mtu " .. conf.mtu)
			os.execute("ip link add " .. iface .. " type wireguard")
			os.execute("ip link set dev " .. iface .. " mtu " .. conf.mtu)
			conf_wg_iface(iface, PRIVKEY, { conc }, conf.wg_keepalive)
			util.log("Setting wg-interface " .. iface .. " up")
			os.execute("ip link set up " .. iface)
			conf_tc_iface(iface)
		else
			util.log("Updating MTU on wg-interface " .. iface .. " to " .. conf.mtu)
			os.execute("ip link set dev " .. iface .. " mtu " .. conf.mtu)
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
			if util.tablelength(wg_conf.peers) <= 1 then
				local target = target_ifaces[iface]
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
					end
					if cur_conf.pubkey ~= target.pubkey then
						util.log(
							"wg-iface " .. iface .. ": Replacing peer " .. cur_conf.pubkey .. " with " .. target.pubkey
						)
						os.execute("wg set " .. iface .. " peer " .. cur_conf.pubkey .. " remove")
						do_it = true
					else
						if cur_conf.endpoint ~= target.endpoint then
							util.log(
								"wg-iface "
									.. iface
									.. ": Reconfiguring peer "
									.. cur_conf.pubkey
									.. ". Endpoint has changed from "
									.. cur_conf.endpoint
									.. " to "
									.. target.endpoint
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
					end
				end
				if do_it then
					-- The active configuration differs from the received configuration.
					-- Let's update it.
					conf_wg_iface(iface, PRIVKEY, { target }, conf.wg_keepalive)
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
