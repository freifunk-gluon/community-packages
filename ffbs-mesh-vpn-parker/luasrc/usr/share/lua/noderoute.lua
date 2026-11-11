local clientaddr = require("clientaddr")
local dhcp = require("parker.dhcp")
local json = require("jsonc")
local util = require("util")
local uci = require("uci")

local RT_PROTO = "23"

local tmpdir = arg[1]

local DHCP_IFACE = "client"
local CONFIG_FILE = tmpdir .. "/noderoute.json"

-- The IPv4 default route as set_wg_route() has last put it in place, in
-- the notation of ip route. The busybox ip on our nodes prints no route
-- metrics, so this is the only place the MTU on that route can be read
-- back from.
local ROUTE4_FILE = tmpdir .. "/noderoute-route4"

-- dnsmasq's name for the DHCPv4 option of RFC 8925, which tells a client
-- that it may do without IPv4 altogether.
local IPV6_ONLY_OPTION = "option:ipv6-only"

-- dnsmasq's name for DHCPv4 option 26 (RFC 2132), the MTU a client may
-- use on the network it has just been given an address on.
local MTU_OPTION = "option:mtu"

-- What the CLAT adds to an IPv4 packet of a client: 20 bytes between the
-- IPv4 and the IPv6 header, plus the 8 bytes of the fragment header a
-- translator has to insert for a packet that may still be fragmented
-- (RFC 7915). ebpf-clat drops those instead of translating them, so
-- those 8 bytes are headroom for the day it stops doing that.
local CLAT_OVERHEAD = 20 + 8

-- uradvd refuses to advertise a link MTU below the 1280 bytes IPv6 needs
-- and exits over it, which would leave the whole client network without
-- router advertisements.
local MIN_ADV_MTU = 1280

-- Where uradvd picks up the MTU we want it to advertise, see
-- /lib/gluon/radvd/arguments.
local ADV_MTU_FILE = "/tmp/adv_mtu"

-- The NAT64 prefix we announce to our clients, in the notation uradvd
-- expects. Its address part has to stay in sync with the prefix
-- /etc/init.d/ebpf-clat starts ebpf-clat with.
local NAT64_PREFIX = "64:ff9b::/96"

-- How long we are willing to wait for netifd to apply a configuration we
-- have just committed, and for the services serving our clients to catch
-- up with it afterwards.
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

local function recorded_mtu4(line)
	-- The MTU of an IPv4 default route ip has printed without one, as
	-- set_wg_route() has recorded it: nil if it put none on the route, or
	-- false if this is not the route it has recorded and we cannot tell.
	local route = string.match(line, "default via %S+ dev %S+")
	local recorded = util.read_file(ROUTE4_FILE) or ""
	if route == nil or string.match(recorded, "default via %S+ dev %S+") ~= route then
		return false
	end
	return tonumber(string.match(recorded, "mtu (%d+)"))
end

local function get_wg_routes()
	-- The default routes we have installed, as { iface, mtu } pairs. Only
	-- IPv4 routes are listed, and only the IPv4 one carries an MTU, see
	-- set_wg_route(). iproute2 prints that MTU, but busybox ip prints no
	-- route metrics at all, so for a route without one we go by our own
	-- record, and an mtu of false means that we cannot tell.
	local result = {}
	local output = util.check_output("ip r show proto " .. RT_PROTO)
	util.log("Checking for wg routes")
	for line in string.gmatch(output, "[^\n]+") do
		util.log("- " .. line)
		if string.find(line, "default via") then
			if not string.find(line, "broadcast") then
				for iface in string.gmatch(line, "dev [a-z0-9-_]+") do
					util.log("Route found")
					local mtu = tonumber(string.match(line, "mtu (%d+)"))
					if mtu == nil then
						mtu = recorded_mtu4(line)
					end
					table.insert(result, { iface = iface:sub(5), mtu = mtu })
				end
			end
		end
	end
	return result
end

local function set_wg_route(iface, conc, mtu4)
	-- Route our clients through a tunnel. An IPv4 MTU is put on the route
	-- rather than on the interface, which carries IPv6 as well: only the
	-- IPv4 packets have to fit through the CLAT before they reach it.
	local route4 = "default via " .. conc["address4"] .. " dev " .. iface .. " proto " .. RT_PROTO
	if mtu4 ~= nil then
		route4 = route4 .. " mtu " .. mtu4
	end
	-- The record only ever describes a route the kernel has taken: it goes
	-- before the route is touched and comes back once ip has succeeded.
	os.remove(ROUTE4_FILE)
	local res = os.execute("ip -4 r replace " .. route4)
	if res == 0 then
		util.write_file(ROUTE4_FILE, route4)
	end
	return res
		+ os.execute("ip -6 r replace default via " .. conc["address6"] .. " dev " .. iface .. " proto " .. RT_PROTO)
end

local function find_concentrator(conf, iface)
	-- The concentrator a wg-interface belongs to, or nil once the config
	-- service has stopped handing it to us.
	local id = tonumber(iface:match("[0-9]+"))
	for _, conc in ipairs(conf.concentrators or {}) do
		if conc.id == id then
			return conc
		end
	end
	return nil
end

local function link_mtu(iface)
	-- The MTU an interface currently has, or nil if there is no such
	-- interface.
	return tonumber(util.read_file("/sys/class/net/" .. iface .. "/mtu") or "")
end

local function tunnel_mtu(ifaces)
	-- The MTU our clients have to live with. Every cycle may pick another
	-- one of these tunnels, and the clients keep their addresses and their
	-- connections across such a switch, so the smallest of them is the
	-- only answer that holds afterwards. Nil while we know none of them.
	local result = nil
	for _, iface in ipairs(ifaces) do
		local mtu = link_mtu(iface)
		if mtu ~= nil and (result == nil or mtu < result) then
			result = mtu
		end
	end
	return result
end

local function clat_mtu(conf, mtu)
	-- The MTU an IPv4 packet of a client may have while the CLAT is in the
	-- way, or nil when nothing translates it and it travels as it is.
	if mtu == nil or conf == nil or conf.xlat_range6 == nil then
		return nil
	end
	return mtu - CLAT_OVERHEAD
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
	-- when there are no values. The list it lives in is shared with the
	-- upgrade scripts, so only our own entry may be touched. Returns
	-- whether uci has been changed, i.e. whether dnsmasq has to be told.

	local options = dhcp.merge_option(uci.get("dhcp", DHCP_IFACE, "dhcp_option"), name, values)
	if options == nil then
		return false
	end
	uci_set("dhcp", DHCP_IFACE, "dhcp_option", options)
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

local function network_applied(address4, target_state)
	-- Has netifd applied the interface configuration we have committed?
	-- netifd updates the running protocol as part of processing the
	-- reload, so as long as we are switching protocols this cannot be
	-- confused by the state the interface was in before.
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
		if addr.address == address4 then
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

local function apply_network(conf, target_state, address4, mtu)
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
		local start = 2
		local limit = (2 ^ (32 - prefix_len) - 2)
		local prefix6_len = tonumber(util.str_split(conf.range6, "[^/]+")[2])

		if address4 ~= conf.address4 then
			-- We have moved out of the way of another node, so the block of
			-- addresses we may move to has to stay out of the pool. The end
			-- of the pool stays where it is for everybody.
			start = clientaddr.RESERVED + 1
			limit = limit - (start - 2)
		end

		uci_set("dhcp", DHCP_IFACE, "interface", DHCP_IFACE)
		uci_set("dhcp", DHCP_IFACE, "leasetime", "3m")
		uci_set("dhcp", DHCP_IFACE, "start", start)
		uci_set("dhcp", DHCP_IFACE, "limit", limit)
		uci_set("dhcp", DHCP_IFACE, "force", "1")
		util.log("Configuring DHCPD on " .. DHCP_IFACE .. " with up to " .. limit .. " leases")

		uci_set("network", DHCP_IFACE, "proto", "static")
		uci_set("network", DHCP_IFACE, "ipaddr", address4 .. "/" .. prefix_len)
		util.log(DHCP_IFACE .. " ipaddr: " .. address4 .. "/" .. prefix_len)
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
			return network_applied(address4, target_state)
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

	-- A node that translates IPv4 for its clients announces the NAT64 prefix
	-- in its router advertisements (RFC 8781), so clients can translate for
	-- themselves as well. uradvd only reads /tmp/pref64 when it starts, so
	-- the file has to be in place before the restart below; the CLAT itself
	-- is set up further down.
	local pref64_changed = false
	local pref64 = util.read_file("/tmp/pref64")
	if target_state and conf.xlat_range6 ~= nil then
		if pref64 ~= NAT64_PREFIX then
			util.write_file("/tmp/pref64", NAT64_PREFIX)
			pref64_changed = true
			util.log("Announcing NAT64 prefix " .. NAT64_PREFIX .. " to our clients")
		end
	elseif pref64 ~= nil then
		os.execute("rm /tmp/pref64 -f")
		pref64_changed = true
		util.log("No longer announcing a NAT64 prefix to our clients")
	end

	-- Our clients reach everything through the tunnel, so what fits into
	-- it is what they may put on the wire. The IPv6 half of that goes into
	-- the router advertisements (RFC 4861), out of the same file uradvd
	-- reads the NAT64 prefix from.
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

	-- The stop above is not conditional on anything radvd announces, so it
	-- has to be paired with a start here even when none of the announced
	-- values changed: a network reconfiguration that touches neither the
	-- prefix nor the MTU (the duplicate-address move, for example) must not
	-- leave the clients without router advertisements.
	local range6 = util.read_file("/tmp/range6")
	if (target_state and range6 ~= conf.range6) or radvd_config_deleted
			or pref64_changed or adv_mtu_changed or radvd_stopped then
		if target_state and conf.range6 ~= nil then
			util.write_file("/tmp/range6", conf.range6)
			util.write_file("/tmp/addr6", conf.address6)
			os.execute("/etc/init.d/gluon-radvd restart")
		else
			-- Nothing to announce: without a prefix uradvd exits right
			-- away and procd stops respawning it after a few attempts,
			-- so an explicit stop is both quieter and equivalent.
			os.execute("/etc/init.d/gluon-radvd stop")
		end
		changed = true
	end

	-- The IPv4 half goes out with the addresses we lease (RFC 2132). A
	-- client that translates for itself uses its own IPv6 MTU for that and
	-- ignores this one, which is why both are announced.
	local client_mtu4 = nil
	if target_state and mtu ~= nil then
		client_mtu4 = clat_mtu(conf, mtu) or mtu
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

	-- A client of a node that translates IPv4 may do without an address of
	-- its own (RFC 8925). Like the MTU above this follows the state we
	-- want rather than the marker file the CLAT leaves behind: that file
	-- lives in /tmp and is gone after a reboot, while the option we have
	-- committed is still in uci, so a node that comes up without tunnels
	-- would go on announcing it to clients it cannot translate for.
	local xlat = target_state and conf ~= nil and conf.xlat_range6 or nil
	if set_client_option(IPV6_ONLY_OPTION, { xlat and "0" }) then
		dhcp_options_changed = true
		if xlat ~= nil then
			util.log("Announcing IPv6-only Preferred to our clients")
		else
			util.log("No longer announcing IPv6-only Preferred to our clients")
		end
	end

	-- The CLAT that does the translating. Our clients are told about it by
	-- the DHCPv4 option above and by the PREF64 option further up; this is
	-- only about the service, which is as gone as its marker file after a
	-- reboot.
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
		util.log("Stopped ebpf-clat")
		changed = true
	end

	if dhcp_options_changed then
		-- One reload, however many of the options above have changed.
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

	-- What our clients may send, and what the IPv4 default route has to
	-- hold their packets to for the CLAT to get them through.
	local mtu = tunnel_mtu(active)
	local route_mtu4 = clat_mtu(conf, mtu)

	-- update network config
	-- the uci commit will only be executed if there is an actual change.
	-- otherwise this function will simply to nothing
	local note = ""
	if #active == 0 then
		util.log("No active tunnels. Deactivating")
		apply_network(conf, false)
	else
		if conf == nil then
			util.log("Network is active but no config present. This is very wrong. Maybe reboot?!")
			report:write("no-config")
			return
		end
		-- Only a node that routes for its clients claims an address on the
		-- client network, and only that one can be in the way of another.
		local address4 = clientaddr.select(conf, tmpdir)
		if address4 ~= conf.address4 then
			note = " (client ip " .. address4 .. ")"
		end
		util.log(#active .. " active tunnels: Applying network state.")
		apply_network(conf, true, address4, mtu)
	end

	local current = get_wg_routes()
	assert(#current <= 1, "too many current routes")
	current = current[1]
	if current then
		util.log("Currently " .. current.iface .. " is the selected tunnel")
	end
	util.log("There are " .. #active .. " active tunnels")
	if current and util.has_value(active, current.iface) then
		if current.mtu ~= route_mtu4 then
			-- The tunnels have been resized under us, so what our clients
			-- may send through this one has changed as well - or we cannot
			-- tell what the route carries (false, see get_wg_routes()) and
			-- have to put the MTU on it again to be sure.
			local conc = find_concentrator(conf, current.iface)
			if conc ~= nil then
				util.log("Setting the IPv4 MTU of the route via " .. current.iface .. " to " .. tostring(route_mtu4))
				set_wg_route(current.iface, conc, route_mtu4)
			end
		end
		util.log("current route still active. Doing nothing.")
		report:write("active (idle) via " .. current.iface .. note)
		return
	end
	if current then
		util.log("The current route is on an inactive tunnel. Going to reconfigure")
	end

	if #active == 0 then
		util.log("No active tunnels. Removing default routes via wg_x.")
		os.remove(ROUTE4_FILE)
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
		local conc = find_concentrator(conf, act)
		if conc ~= nil then
			if set_wg_route(act, conc, route_mtu4) == 0 then
				configured = true
			else
				util.log("Failed to activate route. Trying next...")
			end
		end
		if configured then
			util.log("Route activated")
			report:write("active" .. note)
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
