#!/usr/bin/lua5.1

local site = require 'gluon.site'
local uci = require('simple-uci').cursor()

local default_sources = {
    'hostname',
    'node_id',
    'uptime',
    'site_code',
    'system_load',
    'firmware_version',
}

local sources = {}
local disabled = false
local sources_set = false

if not site.node_whisperer.enabled(false) then
    disabled = true
end

for _, information in ipairs(site.node_whisperer.information({})) do
    table.insert(sources, information)
    sources_set = true
end

if not sources_set then
    sources = default_sources
end

uci:delete('node-whisperer', 'settings')
uci:section('node-whisperer', 'settings', 'settings', {
    disabled = disabled,
})
uci:set('node-whisperer', 'settings', 'information', sources)
uci:commit('node-whisperer')
