#!/usr/bin/lua

local uci = require('simple-uci').cursor()
local wireless = require('gluon.wireless')

local function get_uci_section_for_band(band)
	local section_name = nil
	uci:foreach('gluon', 'ffda-rate-limit', function(section)
		if section.band == band then
			section_name = section['.name']
		end
	end)

	return section_name
end

local function get_user_limit(band, limit_type)
	local uci_section = get_uci_section_for_band(band)
	if uci_section then
		return uci:get('gluon', uci_section, limit_type)
	end

	return nil
end

local function wireless_limits_get()
	local output_limits = {}
	wireless.foreach_radio(uci, function(radio, _, site_config)
		local radio_band = radio.band
		local radio_index = radio['.name']:match('^radio(%d+)$')

		local limit_table = {
			client = {
				up = {
					['user'] = get_user_limit(radio_band, 'client_up'),
					['site'] = site_config.rate_limit.client.up(0)
				},
				down = {
					['user'] = get_user_limit(radio_band, 'client_down'),
					['site'] = site_config.rate_limit.client.down(0)
				}
			},
			iface = {
				up = {
					['user'] = get_user_limit(radio_band, 'iface_up'),
					['site'] = site_config.rate_limit.up(0)
				},
				down = {
					['user'] = get_user_limit(radio_band, 'iface_down'),
					['site'] = site_config.rate_limit.down(0)
				}
			}
		}

		output_limits[radio_band] = {
			index = radio_index,
			limits = {
				client = {
					up = limit_table.client.up.user or limit_table.client.up.site,
					down = limit_table.client.down.user or limit_table.client.down.site
				},
				iface = {
					up = limit_table.iface.up.user or limit_table.iface.up.site,
					down = limit_table.iface.down.user or limit_table.iface.down.site
				}
			},
		}
	end)

	return output_limits
end

local function wireless_limits_set(index, limits)
	local limit_applied = false
	for type_key, type_value in pairs(limits) do
		local limit_down = type_value.down
		local limit_up = type_value.up

		for _, iface_type in ipairs({'client', 'owe'}) do
			local section_name = type_key .. '_limit_' .. iface_type .. index

			uci:delete('wireless-rate-limiter', section_name)

			if limit_down ~= 0 or limit_up ~= 0 then
				local section_type = type_key == 'client' and 'limit-client' or 'limit-interface'
				uci:section('wireless-rate-limiter', section_type, section_name, {
					interface = iface_type .. index,
					download = limit_down,
					upload = limit_up,
					disabled = 0
				})

				limit_applied = true
			end
		end
	end

	return limit_applied
end

-- Delete existing config
uci:delete_all('wireless-rate-limiter', 'limit-client')
uci:delete_all('wireless-rate-limiter', 'limit-interface')

-- Apply config
local limits = wireless_limits_get()
local limits_applied = false
for _, value in pairs(limits) do
	if wireless_limits_set(value.index, value.limits) then
		limits_applied = true
	end
end

-- Decide daemon necessity
uci:set('wireless-rate-limiter', 'core', 'disabled', not limits_applied)

-- Save
uci:commit('wireless-rate-limiter')

return 0
