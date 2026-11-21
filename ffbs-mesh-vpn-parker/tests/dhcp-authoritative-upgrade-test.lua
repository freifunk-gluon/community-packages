-- Test of the upgrade script 905-dhcp-not-authoritative with a mock
-- gluon.site and a mock uci.
-- luacheck: globals os
-- Run: lua5.1 tests/dhcp-authoritative-upgrade-test.lua (from the package directory).

local SCRIPT = "luasrc/lib/gluon/upgrade/905-dhcp-not-authoritative"

-- Like gluon.site: a missing key gives a value that returns the default
-- when it is called.
local function site_value(v)
	return setmetatable({}, {
		__index = function(_, k)
			if type(v) ~= 'table' then
				return site_value(nil)
			end
			return site_value(v[k])
		end,
		__call = function(_, default)
			if v == nil then return default end
			return v
		end,
	})
end

-- The script ends with os.exit(0) when it has nothing to do.
local real_exit = os.exit
local EXIT = {}
os.exit = function(code)
	assert(code == 0, 'exit code ' .. tostring(code))
	error(EXIT, 0)
end

-- sections: list of { name, type, options }, in the order of the config file.
local function run(parker, sections)
	local committed = false
	package.loaded['gluon.site'] = site_value({ parker = parker })
	package.loaded['simple-uci'] = {
		cursor = function()
			return {
				get_first = function(_, conf, stype)
					assert(conf == 'dhcp')
					for _, s in ipairs(sections) do
						if s.type == stype then return s.name end
					end
					return nil
				end,
				set = function(_, conf, section, option, value)
					assert(conf == 'dhcp')
					if type(value) == 'boolean' then
						value = value and '1' or '0'
					end
					for _, s in ipairs(sections) do
						if s.name == section then
							s.options[option] = value
							return
						end
					end
					error('set on missing section ' .. section)
				end,
				commit = function(_, conf)
					assert(conf == 'dhcp')
					committed = true
				end,
			}
		end,
	}
	local ok, err = pcall(assert(loadfile(SCRIPT)))
	if not ok and err ~= EXIT then
		error(err, 0)
	end
	return sections, committed
end

local function dhcp_config()
	return {
		{ name = 'cfg01411c', type = 'dnsmasq', options = { authoritative = '1' } },
		{ name = 'client', type = 'dhcp', options = {} },
		{ name = 'second', type = 'dnsmasq', options = { authoritative = '1' } },
	}
end

local failed = 0
local function check(name, cond)
	print((cond and 'PASS ' or 'FAIL ') .. name)
	if not cond then failed = failed + 1 end
end

local s, committed = run({}, dhcp_config())
check('key unset: no change', s[1].options.authoritative == '1' and not committed)

s, committed = run({ dhcp_authoritative = true }, dhcp_config())
check('true: no change', s[1].options.authoritative == '1' and not committed)

s, committed = run({ dhcp_authoritative = false }, dhcp_config())
check('false: first dnsmasq section gets authoritative 0',
	s[1].options.authoritative == '0' and committed)
check('false: other sections unchanged',
	s[3].options.authoritative == '1' and next(s[2].options) == nil)

s, committed = run({ dhcp_authoritative = false }, { { name = 'client', type = 'dhcp', options = {} } })
check('false without dnsmasq section: no change', next(s[1].options) == nil and not committed)

s, committed = run(nil, dhcp_config())
check('no parker table: no change', s[1].options.authoritative == '1' and not committed)

os.exit = real_exit
if failed > 0 then
	print(failed .. ' failed')
	os.exit(1)
end
print('all passed')
