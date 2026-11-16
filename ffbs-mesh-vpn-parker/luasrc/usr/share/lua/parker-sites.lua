-- Multi-site operation (active/standby) of a parker node.
--
-- The config service can give a node one /63 from each of two or more
-- sites (PoPs), with a list of the gateways (pgws) of each site and a
-- primary_site. noderoute.json then has these extra fields:
--   primary_site = "muc"
--   sites = { muc = { range6, xlat_range6, address6, dns64, concentrator,
--                     pgws = { { name, pubkey, endpoint, address6 }, ... } },
--             vie = { ... } }
-- Tunnel wg_c<concentrator> goes to one pgw of its site at a time.
-- Without these fields this daemon does nothing.
--
-- One tick is 1 s. Each tick sends one ICMPv6 echo through each tunnel to
-- the current pgw of the site and reads the WireGuard handshakes.
--   * 3 misses in a row: move the tunnel to the next pgw of the same site.
--     The site stays up. After a handshake with the new pgw, tell the
--     config service, so that the old pgw removes the route to the node.
--   * The site is down when each of its pgws missed 3 times. A site goes
--     down at once.
--   * A site is up again after 3 hits, a handshake younger than 180 s and
--     10 s of dwell time.
--   * More than 3 changes in 10 min: the site stays down for a penalty of
--     60 s. The penalty doubles each time, up to 600 s.
--   * The active site is the primary site while it is up, else the first
--     site that is up.
--
-- When a state changes, and every 10 s, the daemon applies:
--   * the address of each site on br-client and as /128 on its tunnel,
--   * source rules: "from <site /64>" and, after them, "to <site DNS64>
--     iif lo" use the table of the site (default dev wg_cX),
--   * the IPv6 and IPv4 default routes on the tunnel of the active site
--     (the IPv4 route selects the CLAT of that tunnel),
--   * ip6tables chain parker_src for packets out of wg_c+: a source from a
--     down site, or from no site of this node, gets ICMPv6 type 1 code 5,
--   * one uradvd (/etc/init.d/parker-radvd) for all prefixes: the active
--     prefix is preferred, the others have preferred lifetime 0. A down
--     prefix is sent for 180 s more, then it is removed,
--   * the DNS64 servers of the sites that are up, active site first.
--
-- Each tick also checks the client path of each site. A netifd reload
-- removes the extra site addresses from br-client. The tick then adds them
-- again and counts path_broken.
--
-- "lua parker-sites.lua pin <config.json>" (from nodeconfig.sh) writes the
-- pgw in use into each fetched config, so that a new config does not undo a
-- pgw switch.

local json = require("jsonc")
local posix = require("posix")
local util = require("util")

local TMPDIR = "/tmp/ff-Ohb0ba0u"
local CONF = TMPDIR .. "/noderoute.json"
-- The IPv4 default route as noderoute.lua has put it in place.
local ROUTE4_FILE = TMPDIR .. "/noderoute-route4"
local STATE = "/tmp/parker-sites"
-- The DNS servers of the node before it went into multi-site operation.
local DNS_SAVED = "/etc/parker/dns-servers"
local CLIENT_IF = "br-client"
local NAT64_PREFIX = "64:ff9b::/96"
local TABLE_BASE = 100
local RULE_MIN, RULE_MAX = 1000, 1199
-- The config service API to report a pgw switch.
local SWITCH_PATH = "/api/v3/switch"

-- Timers in seconds. uci parker.sites.<name> can change them.
local T = {
	handshake_max_age = 180,
	misses_down = 3,
	hits_up = 3,
	dwell = 10,
	flap_window = 600,
	flap_max = 3,
	penalty = 60,
	penalty_max = 600,
	full_every = 10,
	report_retry = 3,
	preferred = 300,
	valid = 600,
	dead_keep = 180,
	keepalive = 25,
	-- Router lifetime and RA interval. After a roam, the old node stays the
	-- router of a client (through the mesh) until the router lifetime ends,
	-- so keep it at or below the preferred lifetime. Android 14 and later
	-- ignore lifetimes below 180 s (accept_ra_min_lft). uradvd sets the
	-- PREF64 lifetime to 3 x max interval, rounded down to 8 s: 296 s.
	-- A state change does not wait for the interval: SIGHUP sends RAs at once.
	ra_lifetime = 300,
	ra_min_interval = 33,
	ra_max_interval = 100,
}

util.loggername = "parker-sites"

local function log(msg)
	util.log("'" .. msg:gsub("'", "") .. "'")
end

local function output(cmd)
	return util.check_output(cmd .. " 2>/dev/null")
end

-- os.execute returns 0 on Lua 5.1 and true on 5.2+.
local function sh(cmd)
	local r = os.execute(cmd .. " >/dev/null 2>&1")
	return r == 0 or r == true
end

-- Write in place and keep the inode. Use this for a file that a jailed
-- daemon reads: ujail bind-mounts the file, so after a rename the jail
-- keeps the old, deleted file.
local function write_in_place(path, data)
	local file = io.open(path, "w")
	if not file then
		return false
	end
	file:write(data)
	file:close()
	return true
end

local function update_file(path, data, write)
	if util.read_file(path) == data then
		return false
	end
	(write or util.write_file)(path, data)
	return true
end

local function net63(range6)
	return (range6:gsub("/64$", "/63"))
end

local function find_by(list, key, value)
	for i, item in ipairs(list or {}) do
		if tostring(item[key]) == tostring(value) then
			return item, i
		end
	end
	return nil
end

local function is_multisite(conf)
	return type(conf) == "table" and type(conf.sites) == "table" and conf.primary_site ~= nil
end

local function site_names(conf)
	local names = {}
	for name in pairs(conf.sites) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function load_tuning()
	local uci = require("simple-uci").cursor()
	for k in pairs(T) do
		local v = tonumber(uci:get("parker", "sites", k) or "")
		if v then
			T[k] = v
		end
	end
end

-- pin <config.json>: write the pgw in use into the concentrator of each site.
local function pin(path)
	local conf = json.parse(util.read_file(path) or "")
	if not is_multisite(conf) then
		return
	end
	local changed = false
	for name, site in pairs(conf.sites) do
		local pinned = util.read_file(STATE .. "/pgw." .. name)
		local pgw = pinned and find_by(site.pgws, "name", pinned)
		local conc = find_by(conf.concentrators, "id", site.concentrator)
		if pgw and conc and conc.pubkey ~= pgw.pubkey then
			for _, k in ipairs({ "address4", "address6", "endpoint", "pubkey" }) do
				if pgw[k] ~= nil then
					conc[k] = pgw[k]
				end
			end
			changed = true
		elseif pinned and not pgw then
			os.remove(STATE .. "/pgw." .. name)
		end
	end
	if changed then
		util.write_file(path, json.stringify(conf))
	end
end

local function is_link(iface)
	return iface ~= nil and util.read_file("/sys/class/net/" .. iface .. "/ifindex") ~= nil
end

-- Probe all tunnels at the same time and read the handshakes. Takes 1 s.
-- Returns ok[iface] = true and wg[iface] = { peer, ts }.
local function probe_all(targets)
	local parts = { "sleep 1 &" }
	for iface, addr in pairs(targets) do
		table.insert(parts, "(ping -c 1 -W 1 -I " .. iface .. " " .. addr
			.. " >/dev/null 2>&1 && echo ok " .. iface .. ") &")
	end
	table.insert(parts, "wg show all latest-handshakes; wait")
	local ok, wg = {}, {}
	for line in output(table.concat(parts, " ")):gmatch("[^\n]+") do
		local i = line:match("^ok (%S+)$")
		if i then
			ok[i] = true
		else
			local w, peer, ts = line:match("^(%S+)%s+(%S+)%s+(%d+)$")
			if w and not wg[w] then
				wg[w] = { peer = peer, ts = tonumber(ts) }
			end
		end
	end
	return ok, wg
end

local function urlencode(v)
	return (tostring(v):gsub("[^%w%-%._~]", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

-- Tell the config service that the site now uses pgw (in the background).
-- As nodeconfig.sh: out over the WAN (packet mark 1), and the name resolves
-- through the WAN resolver.
local function report_switch(name, iface, pgw)
	local server = output("uci -q get parker.nodeconfig.config_server"):match("%S+")
	local key = output("wg show " .. iface .. " public-key"):match("%S+")
	if not server or not key then
		return
	end
	local url = "http://" .. server .. SWITCH_PATH .. "?pubkey=" .. urlencode(key)
		.. "&site=" .. urlencode(name) .. "&pgw=" .. urlencode(pgw)
	local done = STATE .. "/report." .. name
	os.execute("(LIBPACKETMARK_MARK=1 LD_PRELOAD=libpacketmark.so gluon-wan-dns wget -q -T 3"
		.. " -O /dev/null '" .. url .. "' && echo " .. pgw .. " > " .. done .. ") >/dev/null 2>&1 &")
end

-- The pgw names resolve only through the WAN resolver. Thus resolve them
-- in a child process under gluon-wan-dns, with the code of nodeconfig.lua.
local function resolve(endpoint)
	local ep = output("gluon-wan-dns lua /usr/share/lua/parker-sites.lua resolve '"
		.. endpoint:gsub("'", "") .. "'"):match("%S+")
	return ep
end

-- Move the tunnel of a site to another pgw. The prefix stays as it is.
local function switch_pgw(name, iface, pgw)
	local ep = resolve(pgw.endpoint)
	if not ep then
		log("site " .. name .. ": cannot resolve " .. pgw.endpoint)
		return false
	end
	for old in output("wg show " .. iface .. " peers"):gmatch("%S+") do
		sh("wg set " .. iface .. " peer " .. old .. " remove")
	end
	if not sh("wg set " .. iface .. " peer " .. pgw.pubkey .. " endpoint " .. ep
			.. " persistent-keepalive " .. T.keepalive .. " allowed-ips ::/0,0.0.0.0/0") then
		log("site " .. name .. ": wg set failed for " .. pgw.name)
		return false
	end
	util.write_file(STATE .. "/pgw." .. name, pgw.name)
	pin(CONF)
	log("site " .. name .. ": " .. iface .. " now uses pgw " .. pgw.name)
	return true
end

-- The arguments of the stock uradvd without the prefix, RDNSS, lifetime
-- and PREF64 options. This keeps for example the link MTU.
local function stock_radvd_args()
	local skip = {
		["-a"] = true, ["-p"] = true, ["--rdnss"] = true, ["-i"] = true,
		["--preferred-lifetime"] = true, ["--valid-lifetime"] = true, ["--pref64"] = true,
	}
	local result, drop = {}, false
	for tok in output("/lib/gluon/radvd/arguments"):gmatch("%S+") do
		if drop then
			drop = false
		elseif skip[tok] then
			drop = true
		else
			table.insert(result, tok)
		end
	end
	return table.concat(result, " ")
end

local function uradvd_pid()
	for p in output("pidof uradvd"):gmatch("%d+") do
		if (util.read_file("/proc/" .. p .. "/cmdline") or ""):find("state-file", 1, true) then
			return p
		end
	end
	return nil
end

-- One step of the health state machine of a site. st is changed in place.
-- ok: the probe of this tick answered. wg: { peer, ts } of the tunnel.
local function health(name, site, iface, st, now, ok, wg)
	local pgws = site.pgws or {}
	local current = wg and wg.peer
	local pgw = current and find_by(pgws, "pubkey", current)
	local fresh = wg ~= nil and wg.ts > 0 and now - wg.ts < T.handshake_max_age
	if ok then
		st.hits, st.misses = st.hits + 1, 0
	else
		st.hits, st.misses = 0, st.misses + 1
	end
	local good = st.hits >= T.hits_up and fresh
	if good then
		st.tried = 0
	end
	st.good_since = good and (st.good_since or now) or nil

	-- 3 misses on this pgw: try the next pgw of the site.
	if st.misses >= T.misses_down then
		st.tried = st.tried + 1
		st.misses = 0
		if #pgws > 1 then
			local _, i = find_by(pgws, "pubkey", current or "")
			local next_pgw = pgws[((i or 0) % #pgws) + 1]
			if switch_pgw(name, iface, next_pgw) then
				pgw = next_pgw
				st.switched = true
				st.report = { pgw = next_pgw.name, since = now, last = 0 }
				os.remove(STATE .. "/report." .. name)
			end
		end
	end

	-- Report the switch after a handshake with the new pgw.
	if st.report then
		if (util.read_file(STATE .. "/report." .. name) or ""):match("%S+") == st.report.pgw then
			log("site " .. name .. ": config service knows pgw " .. st.report.pgw .. " ("
				.. (now - st.report.since) .. " s)")
			st.report = nil
		elseif wg and pgw and pgw.name == st.report.pgw and wg.ts >= st.report.since
				and now - st.report.last >= T.report_retry then
			st.report.last = now
			report_switch(name, iface, st.report.pgw)
		end
	end

	local function change(to)
		st.state, st.since = to, now
		table.insert(st.changes, now)
		log("site " .. name .. " is " .. to)
	end
	local recent = {}
	for _, t in ipairs(st.changes) do
		if now - t < T.flap_window then
			table.insert(recent, t)
		end
	end
	st.changes = recent
	if #recent == 0 and now >= st.penalty_until then
		st.penalties = 0
	end

	if st.state == "up" and st.tried >= math.max(#pgws, 1) then
		change("down")
	elseif st.state == "down" and st.good_since and now - st.good_since >= T.dwell
			and now >= st.penalty_until then
		if #st.changes >= T.flap_max then
			local hold = math.min(T.penalty * 2 ^ st.penalties, T.penalty_max)
			st.penalties = st.penalties + 1
			st.penalty_until = now + hold
			st.changes = {}
			log("site " .. name .. " flaps: held down for " .. hold .. " s")
		else
			change("up")
		end
	end
	st.fresh = fresh
	st.pgw = pgw and pgw.name or "?"
end

local function apply_rules(want)
	local text = table.concat(want, "\n") .. "\n"
	local found = {}
	for line in output("ip -6 rule show"):gmatch("[^\n]+") do
		local p = tonumber(line:match("^(%d+):"))
		if p and p >= RULE_MIN and p <= RULE_MAX then
			table.insert(found, p)
		end
	end
	if util.read_file(STATE .. "/rules") == text and #found == #want then
		return
	end
	for _, p in ipairs(found) do
		sh("ip -6 rule del pref " .. p)
	end
	for _, r in ipairs(want) do
		if not sh("ip -6 rule add " .. r) then
			log("ip -6 rule add " .. r .. " failed")
		end
	end
	util.write_file(STATE .. "/rules", text)
end

local function apply_firewall(conf, names, up)
	-- The probe goes to the pgw address with the site address as source.
	-- It must pass also while the site is down, else the site cannot come up.
	local want = { "-N parker_src", "-A parker_src -d fe80::/10 -j RETURN" }
	for _, name in ipairs(names) do
		for _, pgw in ipairs(conf.sites[name].pgws or {}) do
			if pgw.address6 then
				table.insert(want, "-A parker_src -d " .. pgw.address6 .. " -j RETURN")
			end
		end
	end
	for _, name in ipairs(names) do
		if not up[name] then
			table.insert(want, "-A parker_src -s " .. net63(conf.sites[name].range6)
				.. " -j REJECT --reject-with icmp6-policy-fail")
		end
	end
	for _, name in ipairs(names) do
		if up[name] then
			table.insert(want, "-A parker_src -s " .. net63(conf.sites[name].range6) .. " -j RETURN")
		end
	end
	table.insert(want, "-A parker_src -s fe80::/10 -j RETURN")
	table.insert(want, "-A parker_src -j REJECT --reject-with icmp6-policy-fail")
	-- Compare with the kernel each time: a firewall reload removes the chain.
	local have = output("ip6tables -S parker_src"):gsub("/128", ""):gsub("%s+\n", "\n")
	if have ~= table.concat(want, "\n") .. "\n" then
		sh("ip6tables -N parker_src")
		sh("ip6tables -F parker_src")
		for i = 2, #want do
			if not sh("ip6tables " .. want[i]) then
				log("ip6tables " .. want[i] .. " failed")
			end
		end
	end
	for _, chain in ipairs({ "FORWARD", "OUTPUT" }) do
		if not sh("ip6tables -C " .. chain .. " -o wg_c+ -j parker_src") then
			sh("ip6tables -I " .. chain .. " 1 -o wg_c+ -j parker_src")
		end
	end
end

-- Does each dnsmasq (in its ujail) see the same file at path as we do?
-- No, when dnsmasq started before the file existed or before a rename.
local function dnsmasq_sees(path)
	local st = posix.stat(path)
	local found = false
	for pid in output("pidof dnsmasq"):gmatch("%d+") do
		local jst = posix.stat("/proc/" .. pid .. "/root" .. path)
		if not st or not jst or jst.dev ~= st.dev or jst.ino ~= st.ino then
			return false
		end
		found = true
	end
	return found
end

-- dnsmasq: use the servers in file, or the saved servers when file is nil.
local function apply_dns(file)
	local current = output("uci -q get dhcp.@dnsmasq[0].serversfile"):match("%S+")
	if file == nil then
		if current ~= STATE .. "/dns-servers" then
			return
		end
		sh("uci -q delete dhcp.@dnsmasq[0].serversfile")
		for s in (util.read_file(DNS_SAVED) or ""):gmatch("%S+") do
			sh("uci add_list dhcp.@dnsmasq[0].server=" .. s)
		end
		os.remove(DNS_SAVED)
	elseif current ~= file then
		util.write_file(DNS_SAVED, output("uci -q get dhcp.@dnsmasq[0].server"))
		sh("uci -q delete dhcp.@dnsmasq[0].server")
		sh("uci set dhcp.@dnsmasq[0].serversfile=" .. file)
	elseif dnsmasq_sees(file) then
		sh("/etc/init.d/dnsmasq reload")
		return
	else
		log("dnsmasq does not see " .. file .. ": restarting dnsmasq")
		sh("/etc/init.d/dnsmasq restart")
		return
	end
	sh("uci commit dhcp")
	sh("/etc/init.d/dnsmasq restart")
end

-- Addresses, rules, firewall, routes, CLAT, RA and DNS for the current state.
local function apply(conf, names, db, iface, tbl, up, active, now)
	local rules = { "pref " .. RULE_MIN .. " lookup main suppress_prefixlength 0" }
	db.addrs = {}
	for i, name in ipairs(names) do
		local site = conf.sites[name]
		sh("ip -6 addr replace " .. site.address6 .. "/64 dev " .. CLIENT_IF .. " nodad")
		table.insert(db.addrs, site.address6)
		if iface[name] then
			-- The site address as /128 on the tunnel: the probe source.
			sh("ip -6 addr replace " .. site.address6 .. "/128 dev " .. iface[name])
			sh("ip -6 route replace fe80::/64 dev " .. iface[name])
			-- Each pgw of the site through the site tunnel, also while the
			-- main default route is on the other tunnel.
			for _, pgw in ipairs(site.pgws or {}) do
				if pgw.address6 then
					sh("ip -6 route replace " .. pgw.address6 .. "/128 dev " .. iface[name])
				end
			end
			sh("ip -6 route replace default dev " .. iface[name] .. " src " .. site.address6
				.. " table " .. tbl[name])
			table.insert(rules, "pref " .. (RULE_MIN + 100 + i) .. " from " .. site.range6
				.. " lookup " .. tbl[name])
			-- After the source rules: a packet with a site source must use
			-- the tunnel of that site, also to the DNS64 of another site.
			if site.dns64 then
				table.insert(rules, "pref " .. (RULE_MIN + 150 + i) .. " to " .. site.dns64
					.. " iif lo lookup " .. tbl[name])
			end
		end
	end
	apply_rules(rules)
	apply_firewall(conf, names, up)

	-- Default routes on the tunnel of the active site. Keep the MTU and the
	-- record of noderoute, so that noderoute takes the route as its own.
	if active and iface[active] then
		sh("ip -6 route replace default dev " .. iface[active] .. " proto 23")
		local conc = find_by(conf.concentrators, "id", conf.sites[active].concentrator)
		local route4 = util.read_file(ROUTE4_FILE)
		if conc and conc.address4 and route4 and not route4:find("dev " .. iface[active] .. " ", 1, true) then
			local new = "default via " .. conc.address4 .. " dev " .. iface[active] .. " proto 23"
			local mtu = route4:match("mtu (%d+)")
			if mtu then
				new = new .. " mtu " .. mtu
			end
			if sh("ip -4 route replace " .. new) then
				util.write_file(ROUTE4_FILE, new)
				log("IPv4 default moved to " .. iface[active])
			end
		end
	end

	-- CLAT: each tunnel translates into the xlat /64 of its own site.
	local clat_changed = false
	for _, name in ipairs(names) do
		local xlat = conf.sites[name].xlat_range6
		if iface[name] and xlat then
			clat_changed = update_file("/tmp/xlat_range6." .. iface[name], xlat) or clat_changed
		end
	end
	if clat_changed then
		sh("/etc/init.d/ebpf-clat restart")
	end

	-- RA state: active site first.
	local order = {}
	if active then
		table.insert(order, active)
	end
	for _, name in ipairs(names) do
		if name ~= active then
			table.insert(order, name)
		end
	end
	local lines, rdnss = {}, {}
	for _, name in ipairs(order) do
		local site, st = conf.sites[name], db.sites[name]
		if up[name] or now - st.since < T.dead_keep then
			local preferred = (name == active) and T.preferred or 0
			table.insert(lines, site.range6 .. "," .. preferred .. "," .. T.valid)
			table.insert(rdnss, "rdnss " .. site.address6)
		end
	end
	for _, r in ipairs(rdnss) do
		table.insert(lines, r)
	end
	local ra_state = table.concat(lines, "\n") .. "\n"
	local stock = stock_radvd_args()
	local ra_args = "-i " .. CLIENT_IF .. (stock ~= "" and (" " .. stock) or "")
		.. " --default-lifetime " .. T.ra_lifetime
		.. " --max-router-adv-interval " .. T.ra_max_interval
		.. " --min-router-adv-interval " .. T.ra_min_interval
	if active then
		ra_args = ra_args .. " --pref64 " .. NAT64_PREFIX
	end
	local restart = update_file(STATE .. "/ra-args", ra_args .. "\n")
	local pid = uradvd_pid()
	if update_file(STATE .. "/ra-state", ra_state) or restart or (active and not pid) then
		if pid and not restart then
			sh("kill -HUP " .. pid)
		elseif active then
			-- With no active site, noderoute makes the node a mesh client.
			-- It must then send no RAs.
			sh("/etc/init.d/parker-radvd restart")
		end
		log("RA: " .. ra_state:gsub("\n", ";") .. " active " .. tostring(active))
	end

	-- dnsmasq: the DNS64 of each up site, active first.
	local servers = {}
	for _, name in ipairs(order) do
		if up[name] and conf.sites[name].dns64 then
			table.insert(servers, "server=" .. conf.sites[name].dns64)
		end
	end
	local servers_file = STATE .. "/dns-servers"
	if update_file(servers_file, table.concat(servers, "\n") .. "\n", write_in_place) then
		apply_dns(servers_file)
		log("DNS servers: " .. table.concat(servers, " "))
	end

	util.write_file(STATE .. "/state.json", json.stringify(db))
end

-- The config has no sites (any more): remove what apply() has set.
local function cleanup(db, conf)
	log("no multi-site config: removing the site state")
	apply_rules({})
	for _, chain in ipairs({ "FORWARD", "OUTPUT" }) do
		sh("ip6tables -D " .. chain .. " -o wg_c+ -j parker_src")
	end
	sh("ip6tables -F parker_src")
	sh("ip6tables -X parker_src")
	for i = 1, util.tablelength(db.sites or {}) do
		sh("ip -6 route flush table " .. (TABLE_BASE + i))
	end
	local keep = conf and conf.address6
	for _, addr in ipairs(db.addrs or {}) do
		if addr ~= keep then
			sh("ip -6 addr del " .. addr .. "/64 dev " .. CLIENT_IF)
		end
	end
	sh("/etc/init.d/parker-radvd stop")
	sh("rm -f /tmp/xlat_range6.*")
	sh("/etc/init.d/ebpf-clat restart")
	apply_dns(nil)
	sh("rm -rf " .. STATE)
end

-- One tick. db is kept in memory by the loop (and in state.json).
local function tick(db)
	sh("mkdir -p " .. STATE)
	local raw = util.read_file(CONF) or ""
	local conf = json.parse(raw)
	if not is_multisite(conf) then
		if db.sites then
			cleanup(db, conf)
			for k in pairs(db) do
				db[k] = nil
			end
		end
		-- After a reboot there is no state, but uci can still point
		-- dnsmasq to the servers file of the multi-site operation.
		apply_dns(nil)
		util.sleep(T.full_every)
		return
	end
	local names = site_names(conf)
	db.sites = db.sites or {}

	local iface, tbl, up, targets = {}, {}, {}, {}
	for i, name in ipairs(names) do
		local site = conf.sites[name]
		tbl[name] = TABLE_BASE + i
		local st = db.sites[name] or {}
		st.state = st.state or "down"
		st.since = st.since or 0
		st.hits, st.misses, st.tried = st.hits or 0, st.misses or 0, st.tried or 0
		st.changes, st.penalty_until = st.changes or {}, st.penalty_until or 0
		st.penalties = st.penalties or 0
		db.sites[name] = st
		local i_name = site.concentrator and ("wg_c" .. tostring(site.concentrator))
		if is_link(i_name) then
			iface[name] = i_name
			local current = output("wg show " .. i_name .. " peers"):match("%S+")
			local pgw = current and find_by(site.pgws, "pubkey", current)
			local conc = find_by(conf.concentrators, "id", site.concentrator)
			targets[i_name] = (pgw and pgw.address6) or (conc and conc.address6) or nil
		end
	end

	local ok, wg = probe_all(targets)
	local now = os.time()
	local changed = raw ~= db.raw or now - (db.full or 0) >= T.full_every
	for _, name in ipairs(names) do
		local st = db.sites[name]
		local before = st.state .. (st.pgw or "")
		if iface[name] then
			health(name, conf.sites[name], iface[name], st, now, ok[iface[name]], wg[iface[name]])
		elseif st.state == "up" then
			st.state, st.since = "down", now
			log("site " .. name .. " is down (no tunnel)")
		end
		if st.switched or before ~= st.state .. (st.pgw or "") then
			changed = true
		end
		st.switched = nil
		up[name] = st.state == "up"
	end

	-- The primary site while it is up, else the active one, else the first
	-- site that is up.
	local active = db.active
	if up[conf.primary_site] then
		active = conf.primary_site
	elseif not up[active or ""] then
		active = nil
		for _, name in ipairs(names) do
			if up[name] then
				active = name
				break
			end
		end
	end
	if active ~= db.active then
		log("active site: " .. tostring(db.active) .. " -> " .. tostring(active))
		db.active = active
		changed = true
	end

	-- A netifd reload removes the site addresses from br-client. Then the
	-- replies to clients go out of the wrong tunnel, but the probe (from the
	-- /128 on wg_cX) still works. Thus check the client path each tick.
	db.path_broken = db.path_broken or 0
	for _, name in ipairs(names) do
		local site, i_name = conf.sites[name], iface[name]
		local base = site.range6:match("^(.*::)/64$")
		if i_name and targets[i_name] and base then
			local route = output("ip -6 route get " .. base .. "5a5a:1234 from " .. targets[i_name]
				.. " iif " .. i_name)
			if not route:find("dev " .. CLIENT_IF .. " ", 1, true) then
				sh("ip -6 addr replace " .. site.address6 .. "/64 dev " .. CLIENT_IF .. " nodad")
				db.path_broken = db.path_broken + 1
				log("client_path_broken site " .. name .. ": " .. route:gsub("\n", " "))
				changed = true
			end
		end
	end

	if changed then
		db.raw, db.full = raw, now
		apply(conf, names, db, iface, tbl, up, active, now)
	end
	local status = { "primary_site=" .. conf.primary_site, "active=" .. tostring(active),
		"path_broken=" .. db.path_broken }
	local ra_state = util.read_file(STATE .. "/ra-state") or ""
	for _, name in ipairs(names) do
		local st = db.sites[name]
		table.insert(status, "site " .. name .. " " .. st.state .. " iface=" .. tostring(iface[name])
			.. " pgw=" .. tostring(st.pgw) .. " hits=" .. st.hits .. " misses=" .. st.misses
			.. " tried=" .. st.tried .. " fresh=" .. tostring(st.fresh)
			.. " penalty=" .. tostring(st.penalty_until > now)
			.. " report=" .. (st.report and "pending" or "none")
			.. " range6=" .. conf.sites[name].range6
			.. " ra=" .. (ra_state:find(conf.sites[name].range6 .. ",", 1, true) and "on" or "off"))
	end
	update_file(STATE .. "/status", table.concat(status, "\n") .. "\n")
end

if arg[1] == "pin" then
	pin(arg[2])
elseif arg[1] == "resolve" then
	print(util.resolve_endpoint(arg[2], util.prefer_ipv6()) or "")
else
	-- "loop": the daemon (/etc/init.d/parker-sites).
	load_tuning()
	local db = json.parse(util.read_file(STATE .. "/state.json") or "") or {}
	db.raw, db.full = nil, nil
	while true do
		local okay, err = pcall(tick, db)
		if not okay then
			log("tick failed: " .. tostring(err))
			util.sleep(1)
		end
	end
end
