local dhcp = require("parker.dhcp")
local json = require("jsonc")
local util = require("util")
local uci = require("uci")

local RT_PROTO = "23"

local tmpdir = arg[1]

local DHCP_IFACE = "client"
local CONFIG_FILE = tmpdir .. "/noderoute.json"

-- dnsmasq's name for DHCPv4 option 26 (RFC 2132), the interface MTU.
local MTU_OPTION = "option:mtu"

-- uradvd refuses to advertise a link MTU below the 1280 bytes IPv6 needs
-- and exits.
local MIN_ADV_MTU = 1280

-- Where uradvd picks up the MTU we want it to advertise, see
-- /lib/gluon/radvd/arguments.
local ADV_MTU_FILE = "/tmp/adv_mtu"

-- How long we are willing to wait for netifd to apply a configuration we
-- have just committed, and for the client services afterwards.
local NETWORK_TIMEOUT = 60
local SERVICES_TIMEOUT = 20

util.loggername = "noderoute.lua"

local function dump(foo)
	util.log(json.stringify(foo))
end

local function empty(obj)
	return next(obj) == nil
end

local function get_handshake_ages()
	local result = {}
	local now = os.time()
	local wg = util.get_wg_info()
	for iface, data in pairs(wg) do
		local peers = data["peers"]
		if util.tablelength(peers) == 1 then
			for _, v in pairs(peers) do
				table.insert(result, { now - v["latest_handshake"], iface })
				util.log("wg-handshake age on " .. iface .. ": " .. (now - v["latest_handshake"]))
			end
		end
	end
	return result
end

local function get_wg_routes()
	local result = {}
	local output = util.check_output("ip r show proto " .. RT_PROTO)
	util.log("Checking for wg routes")
	for line in string.gmatch(output, "[^\n]+") do
		util.log("- " .. line)
		if string.find(line, "default via") then
			if not string.find(line, "broadcast") then
				for iface in string.gmatch(line, "dev [a-z0-9-_]+") do
					util.log("Route found")
					table.insert(result, iface:sub(5))
				end
			end
		end
	end
	return result
end

local function set_wg_route(iface, conc)
	local res =
		os.execute("ip -4 r replace default via " .. conc["address4"] .. " dev " .. iface .. " proto " .. RT_PROTO)
	return res
		+ os.execute("ip -6 r replace default via " .. conc["address6"] .. " dev " .. iface .. " proto " .. RT_PROTO)
end

local function link_mtu(iface)
	-- The MTU an interface currently has, or nil if there is no such
	-- interface.
	return tonumber(util.read_file("/sys/class/net/" .. iface .. "/mtu") or "")
end

local function tunnel_mtu(ifaces)
	-- The smallest MTU of the given tunnels, or nil if none is known. Any
	-- of them may carry the default route after the next cycle.
	local result = nil
	for _, iface in ipairs(ifaces) do
		local mtu = link_mtu(iface)
		if mtu ~= nil and (result == nil or mtu < result) then
			result = mtu
		end
	end
	return result
end

local function uci_delete(config, section, option)
	if not uci.delete(config, section, option) then
		util.log(
			"uci.delete(" .. tostring(config) .. ", " .. tostring(section) .. ", " .. tostring(option) .. ") failed"
		)
	end
end

local function uci_set(config, section, option, value)
	local result
	if value == nil then
		result = uci.set(config, section, option)
	else
		result = uci.set(config, section, option, value)
	end
	if not result then
		util.log(
			"uci.set("
				.. tostring(config)
				.. ", "
				.. tostring(section)
				.. ", "
				.. tostring(option)
				.. ", "
				.. tostring(value)
				.. ") failed"
		)
	end
end

local function uci_commit(config)
	if not uci.commit(config) then
		util.log("uci.commit(" .. tostring(config) .. ") failed")
	end
end

local function set_client_option(name, values)
	-- Announce one DHCPv4 option to our clients, or stop announcing it
	-- when there are no values. Returns whether uci has changed, i.e.
	-- whether dnsmasq has to be reloaded.

	local options = dhcp.merge_option(uci.get("dhcp", DHCP_IFACE, "dhcp_option"), name, values)
	if options == nil then
		return false
	end
	if #options > 0 then
		uci_set("dhcp", DHCP_IFACE, "dhcp_option", options)
	else
		-- uci cannot hold an empty list.
		uci_delete("dhcp", DHCP_IFACE, "dhcp_option")
	end
	uci_commit("dhcp")
	return true
end

local function sections_changed()
	return not empty(uci.changes("dhcp")) or not empty(uci.changes("network"))
end

local function iface_status(iface)
	local output = util.check_output("ubus call network.interface." .. iface .. " status 2>/dev/null")
	if output == "" then
		return nil
	end
	return json.parse(output)
end

local function network_applied(conf, target_state)
	-- Has netifd applied the interface configuration we have committed?
	-- On a mode switch the protocol changes, so the state from before the
	-- reload cannot match.
	local status = iface_status(DHCP_IFACE)
	if status == nil then
		return false
	end
	if not target_state then
		return status.proto == "dhcp"
	end
	if status.proto ~= "static" or status.up ~= true then
		return false
	end
	-- The interface may have been up with a different address before.
	for _, addr in ipairs(status["ipv4-address"] or {}) do
		if addr.address == conf.address4 then
			return true
		end
	end
	return false
end

local function services_ready()
	-- Are the services our clients need back up? These are the same
	-- conditions noderoute.sh complains about when they are missing.
	if os.execute("pidof uradvd >/dev/null") ~= 0 then
		return false
	end
	return os.execute("grep -qsF 'dhcp-range=set:" .. DHCP_IFACE .. "' /var/etc/dnsmasq.conf.cfg*") == 0
end

local function apply_network(conf, target_state, mtu)
	if uci.get("dhcp", DHCP_IFACE) == nil then
		uci_set("dhcp", DHCP_IFACE, "dhcp")
	end

	local radvd_config_deleted = false
	local xlat_config_deleted = false
	local first_time_active_since_boot = false
	local dhcp_options_changed = false

	if target_state == true then
		util.log("network: routing state: active")
		local prefix_len = tonumber(util.str_split(conf.range4, "[^/]+")[2])
		-- Offset 1 is our own address and the last one is the broadcast
		-- address, so the pool runs from offset 2 to the one before the
		-- broadcast address.
		local limit = (2 ^ (32 - prefix_len) - 3)
		local prefix6_len = tonumber(util.str_split(conf.range6, "[^/]+")[2])

		uci_set("dhcp", DHCP_IFACE, "interface", DHCP_IFACE)
		uci_set("dhcp", DHCP_IFACE, "leasetime", "3m")
		uci_set("dhcp", DHCP_IFACE, "start", "2")
		uci_set("dhcp", DHCP_IFACE, "limit", limit)
		uci_set("dhcp", DHCP_IFACE, "force", "1")
		util.log("Configuring DHCPD on " .. DHCP_IFACE .. " with up to " .. limit .. " leases")

		uci_set("network", DHCP_IFACE, "proto", "static")
		uci_set("network", DHCP_IFACE, "ipaddr", conf.address4 .. "/" .. prefix_len)
		util.log(DHCP_IFACE .. " ipaddr: " .. conf.address4 .. "/" .. prefix_len)
		uci_set("network", DHCP_IFACE, "ip6addr", conf.address6 .. "/" .. prefix6_len)
		util.log(DHCP_IFACE .. " ip6addr: " .. conf.address6 .. "/" .. prefix6_len)
		if conf.xlat_range6 then
			uci_set("network", DHCP_IFACE, "xlat_range6", conf.xlat_range6)
			util.log(DHCP_IFACE .. " xlat_range6: " .. conf.xlat_range6)
		end
		uci_set("network", "client6", "proto", "static")
		uci_set("network", "gluon_bat0", "gw_mode", "server")
		if not util.check_output("ebtables-tiny -L PARKER_RADV"):find("DROP") then
			os.execute("ebtables-tiny -A PARKER_RADV -j DROP")
		end
		if util.read_file("/tmp/parker_online") == nil then
			os.execute("touch /tmp/parker_online")
			first_time_active_since_boot = true
		end
	else
		-- target_state == false
		util.log("network: routing state: inactive")

		uci_set("network", DHCP_IFACE, "proto", "dhcp")
		-- dnsmasq stops its DHCPD-job when the interface is not 'proto static'

		uci_delete("network", DHCP_IFACE, "ipaddr")
		uci_delete("network", DHCP_IFACE, "ip6addr")
		uci_delete("network", DHCP_IFACE, "xlat_range6")
		uci_set("network", "client6", "proto", "dhcpv6")

		uci_set("network", "gluon_bat0", "gw_mode", "client")

		if util.read_file("/tmp/range6") ~= nil then
			os.execute("rm /tmp/range6 -f")
			os.execute("rm /tmp/addr6 -f")
			radvd_config_deleted = true
		end
		if util.read_file("/tmp/xlat_range6") ~= nil then
			os.execute("rm /tmp/xlat_range6 -f")
			xlat_config_deleted = true
		end

		os.execute("ebtables-tiny -F PARKER_RADV")
	end

	local changed = sections_changed()
	local radvd_stopped = false

	if changed then
		dump(uci.changes())
		uci_commit("dhcp")
		uci_commit("network")
		util.log("Reconfiguring network...")
		util.log("HACK: stopping gluon-radvd")
		os.execute("/etc/init.d/gluon-radvd stop")
		radvd_stopped = true
		util.sleep(1)
		util.log("HACK: continuing with network reload")
		os.execute("/etc/init.d/network reload")
		util.log("Network reload finished. Waiting for " .. DHCP_IFACE .. " to be reconfigured...")
		if util.wait_for(function()
			return network_applied(conf, target_state)
		end, NETWORK_TIMEOUT) then
			util.log("..." .. DHCP_IFACE .. " has been reconfigured.")
		else
			util.log("..." .. DHCP_IFACE .. " did not settle within " .. NETWORK_TIMEOUT .. "s. Continuing anyway.")
		end
		changed = true
	end

	if first_time_active_since_boot then
		util.log("First run since boot. Restarting dnsmasq to generate a valid config")
		os.execute("/etc/init.d/dnsmasq restart")
		changed = true
	end

	-- Our clients reach everything through a tunnel, so announce the
	-- tunnel MTU, for IPv6 in the router advertisements (RFC 4861).
	local adv_mtu_changed = false
	local adv_mtu = util.read_file(ADV_MTU_FILE)
	local want_adv_mtu = nil
	if target_state and mtu ~= nil and mtu >= MIN_ADV_MTU then
		want_adv_mtu = tostring(mtu)
	end
	if want_adv_mtu ~= nil then
		if want_adv_mtu ~= adv_mtu then
			util.write_file(ADV_MTU_FILE, want_adv_mtu)
			adv_mtu_changed = true
			util.log("Announcing an MTU of " .. want_adv_mtu .. " to our clients")
		end
	elseif adv_mtu ~= nil then
		os.execute("rm " .. ADV_MTU_FILE .. " -f")
		adv_mtu_changed = true
		util.log("No longer announcing an MTU to our clients")
	end

	-- Start radvd again after the stop above, also when neither the prefix
	-- nor the MTU has changed.
	local range6 = util.read_file("/tmp/range6")
	if (target_state and range6 ~= conf.range6) or radvd_config_deleted
			or adv_mtu_changed or radvd_stopped then
		if target_state and conf.range6 ~= nil then
			util.write_file("/tmp/range6", conf.range6)
			util.write_file("/tmp/addr6", conf.address6)
			os.execute("/etc/init.d/gluon-radvd restart")
		else
			-- Without a prefix uradvd exits at once, and procd stops
			-- respawning it after a few attempts.
			os.execute("/etc/init.d/gluon-radvd stop")
		end
		changed = true
	end

	-- For IPv4, announce the tunnel MTU in DHCP option 26 (RFC 2132).
	local client_mtu4 = nil
	if target_state and mtu ~= nil then
		client_mtu4 = mtu
	end
	-- { nil } is the empty list, i.e. no such option.
	if set_client_option(MTU_OPTION, { client_mtu4 }) then
		dhcp_options_changed = true
		if client_mtu4 ~= nil then
			util.log("Announcing an IPv4 MTU of " .. client_mtu4 .. " to our clients")
		else
			util.log("No longer announcing an IPv4 MTU to our clients")
		end
	end

	local xlat = target_state and conf ~= nil and conf.xlat_range6 or nil
	local xlat_range6 = util.read_file("/tmp/xlat_range6")
	if xlat ~= nil then
		if xlat_range6 ~= xlat then
			util.write_file("/tmp/xlat_range6", xlat)
			os.execute("/etc/init.d/ebpf-clat start")
			util.log("Started ebpf-clat")
			changed = true
		end
	elseif xlat_range6 ~= nil or xlat_config_deleted then
		os.execute("/etc/init.d/ebpf-clat stop")
		-- The init script does not remove the file. With the file in place
		-- an active node would stop ebpf-clat in every cycle and would not
		-- start it again when the same prefix comes back.
		os.remove("/tmp/xlat_range6")
		util.log("Stopped ebpf-clat")
		changed = true
	end

	if dhcp_options_changed then
		util.log("Reloading dnsmasq to serve our clients the options they now get")
		os.execute("/etc/init.d/dnsmasq reload")
		changed = true
	end

	if changed and target_state then
		util.log("Some network config has changed. Waiting for the client services...")
		if util.wait_for(services_ready, SERVICES_TIMEOUT) then
			util.log("...client services are up.")
		else
			util.log("...client services are not up after " .. SERVICES_TIMEOUT .. "s. Continuing anyway.")
		end
	end

	return true
end

local function update(report)
	-- if there already are changes in uci, abort
	if sections_changed() then
		util.log("UCI is dirty. Refusing to reconfigure node.")
		report:write("dirty")
		return
	end

	local active = {}

	for _, elem in ipairs(get_handshake_ages()) do
		if elem[1] < 180 then
			table.insert(active, elem[2])
		end
	end

	local conf_json = util.read_file(CONFIG_FILE)
	local conf = nil
	if conf_json ~= nil then
		conf = json.parse(conf_json)
	end

	local mtu = tunnel_mtu(active)

	-- update network config
	-- the uci commit will only be executed if there is an actual change.
	-- otherwise this function will simply to nothing
	if #active == 0 then
		util.log("No active tunnels. Deactivating")
		apply_network(conf, false)
	else
		if conf == nil then
			util.log("Network is active but no config present. This is very wrong. Maybe reboot?!")
			report:write("no-config")
			return
		end
		util.log(#active .. " active tunnels: Applying network state.")
		apply_network(conf, true, mtu)
	end

	local current = get_wg_routes()
	assert(#current <= 1, "too many current routes")
	current = current[1]
	if current then
		util.log("Currently " .. current .. " is the selected tunnel")
	end
	util.log("There are " .. #active .. " active tunnels")
	if current and util.has_value(active, current) then
		util.log("current route still active. Doing nothing.")
		report:write("active (idle) via " .. current)
		return
	end
	if current then
		util.log("The current route is on an inactive tunnel. Going to reconfigure")
	end

	if #active == 0 then
		util.log("No active tunnels. Removing default routes via wg_x.")
		local ip4route = util.check_output("ip -4 r show")
		for line in string.gmatch(ip4route, "[^\n]+") do
			if string.find(line, "default via") then
				if string.find(line, "wg_") then
					for gw in string.gmatch(line, "via%s+(%S+)") do
						os.execute("ip -4 r del default via " .. gw)
					end
				end
			end
		end

		local ip6route = util.check_output("ip -6 r show")
		for line in string.gmatch(ip6route, "[^\n]+") do
			if string.find(line, "default via") then
				if string.find(line, "wg_") then
					for gw in string.gmatch(line, "via%s+(%S+)") do
						os.execute("ip -6 r del default via " .. gw)
					end
				end
			end
		end
		report:write("inactive")
		return
	end

	local configured = false
	for _, act in pairs(util.shuffle(active)) do
		util.log("activating route for " .. act)
		local id = tonumber(act:match("[0-9]+"))
		for _, conc in ipairs(conf["concentrators"]) do
			if conc["id"] == id then
				if set_wg_route(act, conc) == 0 then
					configured = true
					break
				else
					util.log("Failed to activate route. Trying next...")
				end
			end
		end
		if configured then
			util.log("Route activated")
			report:write("active")
			break
		else
			report:write("no-route")
			util.log("Out of options. Not activating any route.")
		end
	end
end

util.log("Starting up")
local report = io.open("/tmp/nodeconfig-report.tmp", "w")
update(report)
report:close()
os.execute("mv /tmp/nodeconfig-report.tmp /tmp/nodeconfig-report")
util.log("Done")
