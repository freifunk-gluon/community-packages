-- Send a burst of batman-adv broadcasts after batman-adv starts.
--
-- batman-adv starts the broadcast sequence number of bat0 at 1. Gluon
-- creates bat0 again at each boot and at each change of gw_mode. The other
-- nodes keep the last sequence number of each originator for about 200 s
-- and drop a broadcast with a number up to 64 below that number as a
-- duplicate. Thus they can drop all broadcasts of this node (router
-- advertisements included) until its number passes the old one.
--
-- A burst of COUNT broadcasts that the other nodes receive moves the
-- number past this window at once. batman-adv also gives a number to a
-- broadcast that no neighbour receives, so the burst waits until bat0 has
-- a neighbour.
--
-- When bat0 starts, bridge loop avoidance (BLA) drops all broadcasts for
-- about 30 s (its own backbone gateway waits 3 periods of 10 s). The
-- burst then would have no effect. Thus the node first sends one probe
-- broadcast per second and sends the burst only after a probe is not
-- dropped (tx_dropped of bat0 does not increase). This also works when
-- BLA is off.
--
-- The burst is IPv4 UDP to 255.255.255.255, port 9 (discard), sent
-- directly on bat0: the Ethernet broadcast address always makes a
-- batman-adv broadcast, and no bridge filter is in the path.

local posix = require("posix")
local socket = require("posix.sys.socket")

local bcast = {}

-- BATADV_BCAST_MAX_AGE (64) plus a margin.
bcast.COUNT = 70

local IFACE = "bat0"
local PORT = 9

-- Changed by the tests only.
bcast.SYSFS = "/sys/class/net/"

local function is_up(iface)
	local f = io.open(bcast.SYSFS .. iface .. "/flags")
	if not f then
		return false
	end
	local flags = tonumber(f:read("*l") or "", 16)
	f:close()
	return flags ~= nil and flags % 2 == 1
end

-- batman-adv knows at least one neighbour.
local function has_neighbour()
	local p = io.popen("batctl meshif " .. IFACE .. " n -n -H 2>/dev/null")
	local data = p:read("*a")
	p:close()
	return data:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x") ~= nil
end

local function tx_dropped()
	local f = io.open(bcast.SYSFS .. IFACE .. "/statistics/tx_dropped")
	if not f then
		return nil
	end
	local n = tonumber(f:read("*l") or "")
	f:close()
	return n
end

local function send(fd, n)
	local dest = { family = socket.AF_INET, addr = "255.255.255.255", port = PORT }
	local sent = 0
	for _ = 1, n do
		if socket.sendto(fd, "parker", dest) then
			sent = sent + 1
		end
	end
	return sent
end

-- Send one probe per second until bat0 does not drop it, for up to
-- timeout seconds. Returns true when a probe was not dropped, and the
-- number of seconds waited.
local function wait_not_dropped(fd, timeout)
	local waited = 0
	while true do
		local before = tx_dropped()
		if before == nil then
			return false, waited
		end
		send(fd, 1)
		if tx_dropped() == before then
			return true, waited
		end
		if waited >= timeout then
			return false, waited
		end
		posix.unistd.sleep(1)
		waited = waited + 1
	end
end

-- Wait up to timeout seconds until bat0 is up and has a neighbour, then
-- up to probe_timeout seconds (default 60) until bat0 does not drop a
-- broadcast, then send the burst. After probe_timeout, send the burst
-- anyway.
-- Returns the number of packets sent in the burst, true when a probe
-- was not dropped, and the seconds waited for the probe.
function bcast.burst(timeout, probe_timeout)
	timeout = timeout or 0
	probe_timeout = probe_timeout or 60
	local waited = 0
	while not (is_up(IFACE) and has_neighbour()) do
		if waited >= timeout then
			return 0, false, 0
		end
		posix.unistd.sleep(1)
		waited = waited + 1
	end
	local fd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, 0)
	if not fd then
		return 0, false, 0
	end
	local sent, ok, probed = 0, false, 0
	if socket.setsockopt(fd, socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
			and socket.setsockopt(fd, socket.SOL_SOCKET, socket.SO_BINDTODEVICE, IFACE) then
		ok, probed = wait_not_dropped(fd, probe_timeout)
		sent = send(fd, bcast.COUNT)
	end
	posix.unistd.close(fd)
	return sent, ok, probed
end

return bcast
