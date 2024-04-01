local json = require 'jsonc'
local util = require 'gluon.util'
local info = require 'gluon.info'

-- Get System Infos
local data = assert(json.parse(util.exec('ubus call system board')), "Malformed JSON response, wrong JSON format")

assert(data.release, "Malformed JSON response, missing required value: release")
local Openwrt_version = assert(data.release.version, "Malformed JSON response, missing required value: version")
local target = assert(data.release.target, "Malformed JSON response, missing required value: target")
local board_name = assert(data.board_name, "Malformed JSON response, missing required value: board_name")
local kernel = assert(data.kernel, "Malformed JSON response, missing required value: kernel")

-- Get Gluon Infos
local infos = info.get_info()

local gluon_version = assert(infos.gluon_version, "Malformed gluon-info, missing required value: gluon version")
local firmware_release = assert(infos.firmware_release, "Malformed gluon-info, missing required value: firmware release")

print(gluon_version)
print(board_name)
print(Openwrt_version)
print(kernel)
print(target)
print(firmware_release)
