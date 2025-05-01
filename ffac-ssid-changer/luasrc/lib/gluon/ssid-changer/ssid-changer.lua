#!/usr/bin/lua

local uci = require('simple-uci').cursor()

-- Safety check functions
local function log_debug(...)
	if uci:get('ssid-changer', 'settings', 'debug_log_enabled') == '1' then
		os.execute('logger -t "ffac-ssid-changer" -p debug "' .. table.concat({...}, ' ') .. '"')
	end
end

local function log(...)
	os.execute('logger -t "ffac-ssid-changer" "' .. table.concat({...}, ' ') .. '"')
end

local function safety_exit(message)
	log_debug(message .. ", exiting with error code 2")
	os.exit(2)
end

-- Check if the script is enabled
if uci:get('ssid-changer', 'settings', 'enabled') == '0' then
	os.exit(0)  -- Exit silently if the script is disabled
end

-- Check for autoupdater running
local function is_autoupdater_running()
	local handle = io.popen('pgrep -f autoupdater')
	local result = handle:read("*a")
	handle:close()
	return result ~= ''
end

if is_autoupdater_running() then
	safety_exit('autoupdater running')
end

-- Read uptime
local function get_uptime()
	local file = io.open('/proc/uptime', 'r')
	local uptime = file:read("*n")  -- Read only the first number (uptime in seconds)
	file:close()
	return uptime
end

local uptime = get_uptime()
local uptime_minutes = math.floor(uptime / 60)
local monitor_duration = tonumber(uci:get('ssid-changer', 'settings', 'switch_timeframe') or 30)
local is_switch_time = uptime_minutes % monitor_duration

if uptime < 60 then
	safety_exit('uptime less than one minute')
end

-- Check for hostapd processes
local function has_hostapd_processes()
	local handle = io.popen('find /var/run -name "hostapd-*.conf" | wc -l')
	local result = handle:read("*a")
	handle:close()
	return tonumber(result) > 0
end

if not has_hostapd_processes() then
	safety_exit('no hostapd-*')
end

-- Generate the offline SSID
local function calculate_offline_ssid()
	local prefix = uci:get('ssid-changer', 'settings', 'prefix') or 'FF_Offline_'
	local settings_suffix = uci:get('ssid-changer', 'settings', 'suffix') or 'nodename'
	local suffix

	if settings_suffix == 'nodename' then
		suffix = io.popen('uname -n'):read("*a"):gsub("%s+", "")
		if #suffix > (30 - #prefix) then
			local max_suffix_length = math.floor((28 - #prefix) / 2)
			local suffix_first_chars = suffix:sub(1, max_suffix_length)
			local suffix_last_chars = suffix:sub(-max_suffix_length)
			suffix = suffix_first_chars .. '...' .. suffix_last_chars
		end
	elseif settings_suffix == 'mac' then
		suffix = io.popen('uci -q get network.bat0.macaddr | sed "s/://g"'):read("*a"):gsub("%s+", "")
	else
		suffix = ''
	end

	return prefix .. suffix
end

local offline_ssid = calculate_offline_ssid()

-- Count offline incidents
local tmp = '/tmp/ssid-changer-count'
local tmp_state = '/tmp/ssid-changer-offline'
local off_count = 0
local file = io.open(tmp, 'r')

local is_offline = 0
local state_file = io.open(tmp_state, 'r')

if state_file then
	is_offline = tonumber(state_file:read("*a")) or 0
	state_file:close()
else
	state_file = io.open(tmp_state, 'w')
	state_file:write("0")
	state_file:close()
end

if file then
	off_count = tonumber(file:read("*a")) or 0
	file:close()
else
	file = io.open(tmp, 'w')
	file:write("0")
	file:close()
end

local function calculate_tq_limit()
	local tq_limit_max = tonumber(uci:get('ssid-changer', 'settings', 'tq_limit_max') or 45)
	local tq_limit_min = tonumber(uci:get('ssid-changer', 'settings', 'tq_limit_min') or 35)
	local gateway_tq

	local handle = io.popen('batctl gwl -H | grep -e "^\\*" | awk -F"[()]" "{print $2}" | tr -d " "')
	gateway_tq = tonumber(handle:read("*a"))
	handle:close()

	if not gateway_tq then
		safety_exit('tq_limit can not be calculated without gateway')
	end
	local is_online

	if gateway_tq >= tq_limit_max then
		is_online = true
	elseif gateway_tq < tq_limit_min then
		is_online = false
	else
		-- in the middle part we consider us offline if there was at least one offline incidents
		-- or we were offline before the current monitor interval
		is_online = off_count > 0
	end

	if is_online then
		return 'online'
	else
		return 'offline'
	end
end

local function has_default_gw4()
	local default_gw4 = io.open('/var/gluon/state/has_default_gw4', 'r')
	if default_gw4 then
		default_gw4:close()
		return true
	end
	return false
end

local status
if has_default_gw4() then
	local tq_limit_enabled = tonumber(uci:get('ssid-changer', 'settings', 'tq_limit_enabled') or 0)

	if tq_limit_enabled == 1 then
		status = calculate_tq_limit()
	else
		status = 'online'
	end
else
	status = 'offline'
end

if status == 'online' then
	log_debug("node is online")
	-- only revert and reconf if we were offline in the current monitoring timeframe or before
	-- to reduce impact
	if off_count > 0 then
		log("reverting offline ssid back to default wireless config")
		uci:revert('wireless')
		os.execute('wifi reconf')
	end
elseif status == 'offline' then
	log_debug("node is considered offline")
	local first = tonumber(uci:get('ssid-changer', 'settings', 'first') or 5)
	-- set SSID offline, only if uptime is less than FIRST or exactly a multiplicative of switch_timeframe
	if uptime_minutes < first or is_switch_time == 0 then

		-- check if off_count is more than half of the monitor duration
		if is_offline == 0 and off_count >= math.floor(monitor_duration / 2) then
			-- if has been offline for at least half checks in monitor duration
			-- set the SSID to the offline SSID
			-- and disable owe client radios
			for i = 0, 2 do
				local client_ssid = uci:get('wireless', 'client_radio' .. i, 'ssid')
				if client_ssid then
					uci:set('wireless', 'client_radio' .. i, 'ssid', offline_ssid)
				end

				local owe_ssid = uci:get('wireless', 'owe_radio' .. i, 'ssid')
				if owe_ssid then
					uci:set('wireless', 'owe_radio' .. i, 'disabled', 1)
				end
				-- save does not commit
				uci:save('wireless')
			end
			log("reconfiguring wifi to offline ssid")
			os.execute('wifi reconf')
		end
	end
	off_count = off_count + 1
	file = io.open(tmp, 'w')
	file:write(tostring(off_count))
	file:close()
end

if is_switch_time == 0 then
	file = io.open(tmp, 'w')
	state_file = io.open(tmp_state, 'w')

	if status == 'offline' then
		file:write("1")
		state_file:write("1")
	else
		file:write("0")
		state_file:write("0")
	end
	file:close()
end
