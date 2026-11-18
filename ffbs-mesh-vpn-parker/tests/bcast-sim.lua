-- Simulation of parker/bcast.lua with mock posix modules and a mock sysfs.
-- Run: lua5.1 tests/bcast-sim.lua (from the package directory).
-- The mock bat0 drops all broadcasts for the first DROP_WINDOW seconds
-- (as bridge loop avoidance does) and counts them in tx_dropped.

package.path = "luasrc/usr/share/lua/?.lua;" .. package.path

local sim = {}
local sysfs = os.tmpname()
os.remove(sysfs)
os.execute("mkdir -p " .. sysfs .. "/bat0/statistics")

local function write(path, value)
	local f = assert(io.open(sysfs .. "/bat0/" .. path, "w"))
	f:write(value .. "\n")
	f:close()
end

local function reset(drop_window, neighbour_at, stats)
	sim.now, sim.dropped, sim.accepted = 0, 0, 0
	sim.drop_window, sim.neighbour_at = drop_window, neighbour_at
	sim.burst_accepted = nil
	write("flags", "0x1003")
	if stats then
		write("statistics/tx_dropped", 0)
	else
		os.remove(sysfs .. "/bat0/statistics/tx_dropped")
	end
	sim.stats = stats
end

package.preload["posix"] = function()
	return { unistd = {
		sleep = function(n) sim.now = sim.now + n end,
		close = function() end,
	} }
end
package.preload["posix.sys.socket"] = function()
	return {
		AF_INET = 2, SOCK_DGRAM = 2, SOL_SOCKET = 1, SO_BROADCAST = 6, SO_BINDTODEVICE = 25,
		socket = function() return 3 end,
		setsockopt = function() return 0 end,
		sendto = function()
			if sim.now < sim.drop_window then
				sim.dropped = sim.dropped + 1
				if sim.stats then
					write("statistics/tx_dropped", sim.dropped)
				end
			else
				sim.accepted = sim.accepted + 1
			end
			return 6
		end,
	}
end

local real_popen = io.popen
io.popen = function(cmd) -- luacheck: ignore 122
	if cmd:match("^batctl") then
		local out = sim.now >= sim.neighbour_at and "aa:bb:cc:dd:ee:01 0.1s\n" or ""
		return { read = function() return out end, close = function() end }
	end
	return real_popen(cmd)
end

local bcast = require("parker.bcast")
bcast.SYSFS = sysfs .. "/"

local failed = 0
local function check(name, cond)
	print((cond and "  ok:   " or "  FAIL: ") .. name)
	if not cond then failed = failed + 1 end
end

local function run(title, drop_window, neighbour_at, stats, probe_timeout)
	print(title)
	reset(drop_window, neighbour_at, stats)
	local sent, ok, probed = bcast.burst(120, probe_timeout)
	local burst_accepted = sim.accepted - (ok and 1 or 0)
	print(("  sent=%d ok=%s probed=%d s, t=%d s, dropped=%d, accepted=%d")
		:format(sent, tostring(ok), probed, sim.now, sim.dropped, sim.accepted))
	return { sent = sent, ok = ok, probed = probed, acc = burst_accepted }
end

local r = run("1. BLA drops broadcasts for 33 s, neighbour after 2 s", 33, 2, true)
check("probe passes", r.ok)
check("burst starts after the drop window", sim.now >= 33 and sim.now <= 34)
check("bat0 drops no packet of the burst", r.acc == bcast.COUNT and r.sent == bcast.COUNT)

r = run("2. No drop window (BLA off)", 0, 2, true)
check("probe passes at once", r.ok and r.probed == 0)
check("burst sent without delay", sim.now == 2 and r.acc == bcast.COUNT)

r = run("3. Drops do not stop within the probe timeout", 1000, 2, true)
check("probe fails", not r.ok)
check("burst sent anyway after 60 s", r.sent == bcast.COUNT and r.probed == 60 and sim.now == 62)

r = run("4. tx_dropped cannot be read", 33, 2, false)
check("burst sent anyway without waiting", r.sent == bcast.COUNT and not r.ok and sim.now == 2)

r = run("5. No neighbour within the timeout", 0, 1000, true)
check("nothing sent", r.sent == 0 and sim.dropped + sim.accepted == 0)

os.execute("rm -rf " .. sysfs)
if failed > 0 then
	print("Some tests failed.")
	os.exit(1)
end
print("All tests passed.")
