local json = require("jsonc")
local util = require("util")
local uci = require("uci")

local RT_PROTO = "23"

local tmpdir = arg[1]

local DHCP_IFACE = "client"
local CONFIG_FILE = tmpdir .. "/noderoute.json"

util.loggername = "noderoute.lua"

function dump(foo)
	util.log(json.stringify(foo))
end

local function empty(obj)
	return next(obj) == nil
end

function get_wg_info()
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
			peer["presistent_keepalive"] = tonumber(line[8])
			results[line[1]]["peers"][line[2]] = peer
		end
	end
	return results
end

function get_handshake_ages()
	local result = {}
	local now = os.time()
	local wg = get_wg_info()
	for iface, data in pairs(wg) do
		local peers = data["peers"]
		if util.tablelength(peers) == 1 then
			for k, v in pairs(peers) do
				table.insert(result, { now - v["latest_handshake"], iface })
				util.log("wg-handshake age on " .. iface .. ": " .. (now - v["latest_handshake"]))
			end
		end
	end
	return result
end

function get_wg_routes()
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

function set_wg_route(iface, conc)
	local res =
		os.execute("ip -4 r replace default via " .. conc["address4"] .. " dev " .. iface .. " proto " .. RT_PROTO)
	return res
		+ os.execute("ip -6 r replace default via " .. conc["address6"] .. " dev " .. iface .. " proto " .. RT_PROTO)
end

function uci_delete(config, section, option)
	if not uci.delete(config, section, option) then
		util.log(
			"uci.delete(" .. tostring(config) .. ", " .. tostring(section) .. ", " .. tostring(option) .. ") failed"
		)
	end
end

function uci_set(config, section, option, value)
	local result = false
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

function uci_commit(config)
	if not uci.commit(config) then
		util.log("uci.commit(" .. tostring(config) .. ") failed")
	end
end

function apply_network(conf, target_state)
	if uci.get("dhcp", DHCP_IFACE) == nil then
		uci_set("dhcp", DHCP_IFACE, "dhcp")
	end

	local radvd_config_deleted = false
	local first_time_active_since_boot = false

	if target_state == true then
		util.log("network: routing state: active")
		local prefix_len = tonumber(util.str_split(conf.range4, "[^/]+")[2])
		local limit = (2 ^ (32 - prefix_len) - 2)
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
		uci_set("network", "client6", "proto", "dhcpv6")

		uci_set("network", "gluon_bat0", "gw_mode", "client")

		if util.read_file("/tmp/range6") ~= nil then
			os.execute("rm /tmp/range6 -f")
			os.execute("rm /tmp/addr6 -f")
			radvd_config_deleted = true
		end

		os.execute("ebtables-tiny -F PARKER_RADV")
	end

	local changes = uci.changes()
	local changed = false

	if not empty(changes) then
		dump(changes)
		uci_commit("dhcp")
		uci_commit("network")
		uci_commit("batman-adv")
		util.log("Reconfiguring network...")
		util.log("HACK: stoppping gluon-radvd")
		os.execute("/etc/init.d/gluon-radvd stop")
		util.sleep(1)
		util.log("HACK: continuing with network reload")
		os.execute("/etc/init.d/network reload")
		util.log("Network reload finished. Wait another 60s for the config to settle...")
		util.sleep(60)
		util.log("...done sleeping for 60s.")
		changed = true
	end

	if first_time_active_since_boot then
		util.log("First run since boot. Restarting dnsmasq to generate a valid config")
		os.execute("/etc/init.d/dnsmasq restart")
		changed = true
	end

	local range6 = util.read_file("/tmp/range6")
	if (target_state and range6 ~= conf.range6) or radvd_config_deleted then
		if conf.range6 ~= nil and target_state then
			f = io.open("/tmp/range6", "w")
			f:write(conf.range6)
			f:close()

			f = io.open("/tmp/addr6", "w")
			f:write(conf.address6)
			f:close()
		end
		os.execute("/etc/init.d/gluon-radvd restart")
		changed = true
	end

	if changed then
		util.log("Some network config has changed. Wait another 20s for everything to sette...")
		util.sleep(20)
		util.log("... done sleeping for 20s")
	end

	return true
end

function update()
	-- if there already are changes in uci, abort
	if not empty(uci.changes()) then
		util.log("UCI is dirty. Refusing to reconfigure node.")
		report:write("dirty")
		return
	end

	local active = {}
	local state_to_apply = false

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
		apply_network(conf, true)
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
		local output = util.check_output("ip -4 r show")
		for line in string.gmatch(output, "[^\n]+") do
			if string.find(line, "default via") then
				if string.find(line, "wg_") then
					for gw in string.gmatch(line, "via%s+(%S+)") do
						os.execute("ip -4 r del default via " .. gw)
					end
				end
			end
		end

		local output = util.check_output("ip -6 r show")
		for line in string.gmatch(output, "[^\n]+") do
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
report = io.open("/tmp/nodeconfig-report.tmp", "w")
update()
report:close()
os.execute("mv /tmp/nodeconfig-report.tmp /tmp/nodeconfig-report")
util.log("Done")
