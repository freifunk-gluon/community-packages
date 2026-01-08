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
	if not file then return 0 end
	local uptime = file:read("*n")
	file:close()
	return uptime or 0
end

local uptime = get_uptime()
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

-- Read State
local tmp_count = '/tmp/ssid-changer-count'
local tmp_state = '/tmp/ssid-changer-offline'

local offline_minutes = 0
local count_file = io.open(tmp_count, 'r')
if count_file then
	offline_minutes = tonumber(count_file:read("*a")) or 0
	count_file:close()
end

local ssid_state = 'ONLINE'
local state_file = io.open(tmp_state, 'r')
if state_file then
	local content = state_file:read("*a")
	if (tonumber(content) or 0) == 1 then
		ssid_state = 'OFFLINE'
	end
	state_file:close()
end

-- Determine Link State
local function has_default_gw4()
	local default_gw4 = io.open('/var/gluon/state/has_default_gw4', 'r')
	if default_gw4 then
		default_gw4:close()
		return true
	end
	return false
end

local function get_gateway_tq()
	local handle = io.popen('batctl gwl -H | grep -e "^\\*" | awk -F"[()]" "{print $2}" | tr -d " "')
	local result = handle:read("*a")
	handle:close()
	return tonumber(result)
end

local link_state = 'OFFLINE'

if has_default_gw4() then
	local tq_limit_enabled = tonumber(uci:get('ssid-changer', 'settings', 'tq_limit_enabled') or 0)

	if tq_limit_enabled == 1 then
		local gateway_tq = get_gateway_tq()
		if not gateway_tq then
			safety_exit('tq_limit can not be calculated without gateway')
		end

		local tq_limit_max = tonumber(uci:get('ssid-changer', 'settings', 'tq_limit_max') or 45)
		local tq_limit_min = tonumber(uci:get('ssid-changer', 'settings', 'tq_limit_min') or 35)

		if gateway_tq >= tq_limit_max then
			link_state = 'ONLINE'
		elseif gateway_tq < tq_limit_min then
			link_state = 'OFFLINE'
		else
			-- Hysteresis: keep previous link state
			if offline_minutes > 0 then
				link_state = 'OFFLINE'
			else
				link_state = 'ONLINE'
			end
		end
	else
		link_state = 'ONLINE'
	end
end

-- State Machine Logic
local monitor_duration = tonumber(uci:get('ssid-changer', 'settings', 'switch_timeframe') or 30)
local threshold = math.floor(monitor_duration / 2)

if link_state == 'ONLINE' then
	log_debug("node is online")
	if offline_minutes > 0 then
		offline_minutes = offline_minutes - 1
	end

	if ssid_state == 'OFFLINE' and offline_minutes == 0 then
		log("reverting offline ssid back to default wireless config")
		uci:revert('wireless')
		os.execute('wifi reconf')
		ssid_state = 'ONLINE'
	end
else
	log_debug("node is considered offline")
	if offline_minutes < monitor_duration then
		offline_minutes = offline_minutes + 1
	end

	if ssid_state == 'ONLINE' and offline_minutes >= threshold then
		log("reconfiguring wifi to offline ssid")

		for i = 0, 2 do
			local client_ssid = uci:get('wireless', 'client_radio' .. i, 'ssid')
			if client_ssid then
				uci:set('wireless', 'client_radio' .. i, 'ssid', offline_ssid)
			end

			local owe_ssid = uci:get('wireless', 'owe_radio' .. i, 'ssid')
			if owe_ssid then
				uci:set('wireless', 'owe_radio' .. i, 'disabled', 1)
			end
		end
		-- save does not commit
		uci:save('wireless')
		os.execute('wifi reconf')
		ssid_state = 'OFFLINE'
	end
end

-- Save State
count_file = io.open(tmp_count, 'w')
if count_file then
	count_file:write(tostring(offline_minutes))
	count_file:close()
end

state_file = io.open(tmp_state, 'w')
if state_file then
	if ssid_state == 'OFFLINE' then
		state_file:write("1")
	else
		state_file:write("0")
	end
	state_file:close()
end
