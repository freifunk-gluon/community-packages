-- Keep the client-facing IPv4 address of this node out of the way of the
-- other nodes on the same layer 2 segment.
--
-- The config service hands out the same range4 and the same address4 - the
-- first usable address of that range - to every node: there is no per-node
-- IPv4 assignment. Nodes that mesh with each other bridge their clients
-- into one segment, so as soon as more than one of them routes for those
-- clients, all of them claim that single address and ARP on that segment
-- becomes a coin toss.
--
-- A node that finds its address in use by somebody else therefore moves to
-- another address from a small block at the start of range4. Which one it
-- takes is derived from its own MAC, so two nodes that have to move rarely
-- pick the same one, and the choice is remembered in uci so that it
-- survives a reboot.

local uci = require("uci")
local util = require("util")

local clientaddr = {}

-- The first addresses of range4 belong to the nodes routing for the
-- clients: offset 1 is the one the config service hands to everybody,
-- offsets 2..RESERVED are the alternatives a node can move to. Everything
-- above that is the pool we hand out per DHCP.
clientaddr.RESERVED = 16
local ALTERNATIVES = clientaddr.RESERVED - 1
-- Distances we walk the alternatives with. Every one of them is coprime
-- with the number of alternatives, so a node that has to move again and
-- again tries all of them before it comes back to the first one.
local STEPS = { 1, 2, 4, 7, 8, 11, 13, 14 }

-- batman keeps an entry of the distributed ARP table for five minutes.
-- Anything close to that age may well be a node that has moved away long
-- ago, so we only believe the fresh ones.
local DAT_MAX_AGE = 60
-- How long we leave an address to a node that sorts before us before we
-- give up on it moving and move ourselves. Whether a node sees a conflict
-- depends on the ARP traffic that passes it, so we cannot rely on the
-- other one seeing it as well.
local CONFLICT_PATIENCE = 300
-- How long a conflict stays on record without being seen again. Two nodes
-- fighting over an address overwrite each other's entry in the distributed
-- ARP table, so a cycle without a sighting does not mean it is over.
local CONFLICT_MEMORY = 120

local UCI_CONFIG = "parker"
local UCI_SECTION = "client"
local STATE_FILE = "/clientaddr-conflict"

local function uci_set(option, value)
	local result
	if value == nil then
		result = uci.set(UCI_CONFIG, UCI_SECTION, option)
	else
		result = uci.set(UCI_CONFIG, UCI_SECTION, option, value)
	end
	if not result then
		util.log("uci.set(" .. UCI_CONFIG .. ", " .. UCI_SECTION .. ", " .. tostring(option) .. ") failed")
	end
end

local function uci_commit()
	if not uci.commit(UCI_CONFIG) then
		util.log("uci.commit(" .. UCI_CONFIG .. ") failed")
	end
end

local function ip4_to_int(address)
	local octets = { string.match(address or "", "^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
	if #octets ~= 4 then
		return nil
	end
	local result = 0
	for _, octet in ipairs(octets) do
		octet = tonumber(octet)
		if octet > 255 then
			return nil
		end
		result = result * 256 + octet
	end
	return result
end

local function int_to_ip4(value)
	return string.format(
		"%d.%d.%d.%d",
		math.floor(value / 16777216) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 256) % 256,
		value % 256
	)
end

local function router_block(range4)
	-- The network address of range4, or nil if we cannot keep a block of
	-- router addresses out of the client pool in it.
	local address, prefix_len = string.match(range4 or "", "^([%d%.]+)/(%d+)$")
	local network = ip4_to_int(address)
	prefix_len = tonumber(prefix_len)
	if network == nil or prefix_len == nil or prefix_len > 32 then
		return nil
	end
	local size = 2 ^ (32 - prefix_len)
	if size < clientaddr.RESERVED + 2 then
		return nil
	end
	return network - (network % size)
end

local function is_alternative(network, address)
	local value = ip4_to_int(address)
	return value ~= nil and value >= network + 2 and value <= network + clientaddr.RESERVED
end

local function hash(str)
	-- djb2. All we need is something that spreads the nodes evenly over
	-- the alternatives and always gives the same node the same result.
	local result = 5381
	for i = 1, #str do
		result = (result * 33 + string.byte(str, i)) % 2147483647
	end
	return result
end

local function candidate(network, mac, k)
	-- The k-th alternative address this node would take.
	local h = hash(mac)
	local step = STEPS[1 + (math.floor(h / ALTERNATIVES) % #STEPS)]
	return network + 2 + ((h + k * step) % ALTERNATIVES)
end

local function next_alternative(network, mac, address4)
	-- The alternative to take when the current address does not work out.
	local current = ip4_to_int(address4)
	local k = 0
	for i = 0, ALTERNATIVES - 1 do
		if candidate(network, mac, i) == current then
			k = i + 1
			break
		end
	end
	return int_to_ip4(candidate(network, mac, k))
end

local function own_mac()
	-- The MAC our clients see us with. Gluon gives br-client the primary
	-- MAC of the node, which makes this a stable identity as well.
	local address = util.read_file("/sys/class/net/br-client/address")
	if address == nil then
		return nil
	end
	return string.match(string.lower(address), "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
end

local function local_macs()
	local macs = {}
	for mac in string.gmatch(util.check_output("ip -o link show"), "link/ether (%x+:%x+:%x+:%x+:%x+:%x+)") do
		macs[string.lower(mac)] = true
	end
	return macs
end

local function dat_claim(address4)
	-- The MAC batman has last seen using address4, unless that is one of
	-- ours. batctl dc dumps the distributed ARP table, which every node
	-- fills from the ARP traffic it forwards and from the entries it is a
	-- DHT candidate for:
	--
	--   *        10.80.96.1 12:34:56:78:9a:bc   -1      0:12
	--
	-- -n keeps batctl from replacing the MAC with a bat-hosts name and -H
	-- drops the header. Lines we cannot parse are none of our business.
	local macs = nil
	local output = util.check_output("batctl dc -n -H 2>/dev/null")
	for line in string.gmatch(output, "[^\n]+") do
		local address, mac, age_min, age_sec = string.match(
			line,
			"^%s*%*%s+(%d+%.%d+%.%d+%.%d+)%s+(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)%s+%-?%d+%s+(%d+):(%d+)"
		)
		if address == address4 then
			local age = tonumber(age_min) * 60 + tonumber(age_sec)
			mac = string.lower(mac)
			if macs == nil then
				macs = local_macs()
			end
			if not macs[mac] and age <= DAT_MAX_AGE then
				return mac, age
			end
		end
	end
	return nil
end

local function other_gateways()
	-- Is another node routing for the clients on this segment? Only those
	-- announce themselves as a batman gateway, and only those configure
	-- address4 on br-client - the ones that just mesh get their client
	-- address per DHCP and never claim ours.
	local output = util.check_output("batctl gwl -n -H 2>/dev/null")
	return string.match(output, "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") ~= nil
end

local function conflict_age(tmpdir, address4, mac)
	-- For how long we have been seeing this conflict. Keeps its record in
	-- $tmpdir: a conflict that a reboot does not bring back is not one we
	-- have to be impatient about.
	local now = os.time()
	local first = now
	local line = util.read_file(tmpdir .. STATE_FILE)
	if line ~= nil then
		local was_address, was_mac, was_first, was_last = string.match(line, "^(%S+) (%S+) (%d+) (%d+)")
		if was_address == address4 and was_mac == mac and now - tonumber(was_last) <= CONFLICT_MEMORY then
			-- The time is set from the configuration we receive, so it can
			-- jump backwards on us.
			first = math.min(tonumber(was_first), now)
		end
	end
	local file = io.open(tmpdir .. STATE_FILE, "w")
	if file ~= nil then
		file:write(string.format("%s %s %d %d\n", address4, mac, first, now))
		file:close()
	end
	return now - first
end

local function forget_conflict(tmpdir)
	os.remove(tmpdir .. STATE_FILE)
end

local function stored_address(conf, network)
	-- The address we have moved to earlier, if it still belongs to the
	-- range the config service gives us.
	local stored = uci.get(UCI_CONFIG, UCI_SECTION, "address4")
	if stored == nil then
		return nil
	end
	local stored_range = uci.get(UCI_CONFIG, UCI_SECTION, "range4")
	if network ~= nil and stored_range == conf.range4 and is_alternative(network, stored) then
		return stored
	end
	util.log("client address: " .. stored .. " is not an address of " .. tostring(conf.range4) .. " anymore")
	uci.delete(UCI_CONFIG, UCI_SECTION)
	uci_commit()
	return nil
end

function clientaddr.select(conf, tmpdir)
	-- The address to configure on br-client. Only call this while the node
	-- is routing for its clients: a node that only meshes takes its client
	-- address from the node that does and cannot collide with anybody.
	--
	-- Moving is remembered until the config service gives us a different
	-- range: coming back to the default address once a conflict is gone
	-- would only cost us another round of it.

	local network = router_block(conf.range4)
	local address4 = stored_address(conf, network) or conf.address4

	local mac = own_mac()
	if network == nil or mac == nil then
		return address4
	end

	local claim, age = dat_claim(address4)
	if claim == nil then
		forget_conflict(tmpdir)
		return address4
	end
	util.log("client address: " .. address4 .. " has been used by " .. claim .. " " .. age .. "s ago")

	if not other_gateways() then
		-- Nobody else is serving these clients, so this is a node that only
		-- answers ARP for the address without ever using it, or a client
		-- that has taken it. Moving would gain us nothing.
		util.log("client address: no other node is routing here. Keeping " .. address4)
		forget_conflict(tmpdir)
		return address4
	end

	local seen_for = conflict_age(tmpdir, address4, claim)
	if mac < claim then
		-- Only one of us should move, and that is the node with the higher
		-- MAC. But we cannot be sure the other one sees the conflict at
		-- all, so this is not a reason to wait forever.
		if seen_for < CONFLICT_PATIENCE then
			util.log("client address: leaving it to " .. claim .. " to move away from " .. address4)
			return address4
		end
		util.log("client address: " .. claim .. " has not moved away in " .. seen_for .. "s")
	end

	local moved = next_alternative(network, mac, address4)
	util.log("client address: moving from " .. address4 .. " to " .. moved)
	if uci.get(UCI_CONFIG, UCI_SECTION) == nil then
		uci_set(UCI_SECTION)
	end
	uci_set("address4", moved)
	uci_set("range4", conf.range4)
	uci_commit()
	forget_conflict(tmpdir)
	return moved
end

return clientaddr
