-- Test of the upgrade script 251-parker-cellular-ip4table with a mock uci.
-- Run: lua5.1 tests/cellular-ip4table-test.lua (from the package directory).

local SCRIPT = "luasrc/lib/gluon/upgrade/251-parker-cellular-ip4table"

local function run(network)
	local saved = false
	package.loaded['simple-uci'] = {
		cursor = function()
			return {
				get = function(_, conf, section, option)
					assert(conf == 'network')
					local s = network[section]
					if not s then return nil end
					if option == nil then return s['.type'] end
					return s[option]
				end,
				set = function(_, conf, section, option, value)
					assert(conf == 'network')
					assert(network[section], 'set on missing section ' .. section)
					network[section][option] = tostring(value)
				end,
				save = function(_, conf)
					assert(conf == 'network')
					saved = true
				end,
			}
		end,
	}
	assert(loadfile(SCRIPT))()
	return network, saved
end

local failed = 0
local function check(name, cond)
	print((cond and 'PASS ' or 'FAIL ') .. name)
	if not cond then failed = failed + 1 end
end

local n, saved = run({
	wan = { ['.type'] = 'interface', ip4table = '1' },
	cellular = { ['.type'] = 'interface', proto = 'qmi', ip6table = '1' },
})
check('cellular gets ip4table 1', n.cellular.ip4table == '1' and saved)
check('cellular keeps ip6table 1', n.cellular.ip6table == '1')

n, saved = run({ wan = { ['.type'] = 'interface', ip4table = '1' } })
check('node without cellular: no change', n.cellular == nil and not saved)

n, saved = run({ cellular = { ['.type'] = 'route' } })
check('non-interface section named cellular: no change',
	n.cellular.ip4table == nil and not saved)

n = run({ cellular = { ['.type'] = 'interface', ip4table = '1' } })
check('second run keeps ip4table 1', n.cellular.ip4table == '1')

if failed > 0 then
	print(failed .. ' failed')
	os.exit(1)
end
print('all passed')
