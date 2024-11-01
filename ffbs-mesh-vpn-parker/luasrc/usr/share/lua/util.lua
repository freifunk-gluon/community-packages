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

function util.nslookup(host)
	local ans = posix.sys.socket.getaddrinfo(host, nil, { protocol = posix.sys.socket.IPPROTO_UDP })
	if not ans then
		return nil
	else
		return ans[1].addr
	end
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
			peer["presistent_keepalive"] = tonumber(line[8])
			results[line[1]]["peers"][line[2]] = peer
		end
	end
	return results
end

function util.sleep(n)
	posix.unistd.sleep(n)
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
