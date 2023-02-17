--[[
Copyright 2022 Maciej Krüger <maciej@xeredo.it>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0
]]--

local unistd = require 'posix.unistd'

local tmpfile = "/tmp/vpninput"

local ssl = require 'openssl'

local site = require 'gluon.site'

local cfg = site.mesh_vpn.openvpn.config()

local f = Form(translate('Mesh VPN'))

local s = f:section(Section)

local function dump_name(name)
	if not name then
		return nil
	end

	local o = {}

	for _, n in ipairs(name:info()) do
		for k, v in pairs(n) do
			o[k] = v
		end
	end

	return o
end

local function try_key(_, input)
	local key = ssl.pkey.read(input, true)

	if not key then
		return
	end

	local info = key:parse()

	return {
		type = 'key',
		display = translatef('Key %s, %s bits', info.type, info.size * 8),
		info = info,
	}
end

local function try_cert(_, input)
	local cert = ssl.x509.read(input)

	if not cert then
		return cert
	end

	local info = cert:parse()

	local subject = dump_name(info.subject)
	local issuer = dump_name(info.issuer)

	return {
		type = info.ca and 'cacert' or 'cert',
		display = info.ca
			and translatef('CA Certificate "%s"', subject.CN)
			or translatef('Certificate "%s" from "%s"', subject.CN, issuer.CN),
		info,
	}
end

local function content_info(file)
	local out = {
		type = nil,
	}

	if file ~= nil and unistd.access(file) then
		local _file = io.open(file, 'rb') -- r read mode and b binary mode

		if _file then
			local input = _file:read '*a' -- *a or *all reads the whole file
			_file:close()

			local status, ret = pcall(try_key, file, input)
			if status and ret then
			  return ret
			end

			status, ret = pcall(try_cert, file, input)
			if status and ret then
			  return ret
			end
		end
	end

	return out
end

local function content_info_str(file)
	local info = content_info(file)

	if not info.type then
		return translate('(unknown)')
	end

	return info.display
end

local function file_info(file, desc)
	local status

	if unistd.access(file) then
		status = translatef('Configured, %s', content_info_str(file))
	else
		status = translate('Not configured')
	end

	s:element('model/info', {}, 'info_' .. file, desc, status)
end

local function rename(src, target)
	local srcf = io.open(src, 'rb')
	local targetf = io.open(target, 'w')
	local data = srcf:read('*a')
	targetf:write(data)
	srcf:close()
	targetf:close()
end

local function try_tar(_)
	if os.execute("rm -rf /tmp/_tarex") ~= 0 then
		return
	end
	if os.execute("mkdir -p /tmp/_tarex") ~= 0 then
		return
	end
	if os.execute(string.format("tar xfz %s -C /tmp/_tarex", tmpfile)) ~= 0 then
		return
	end

	-- SECURITY: print0 or something, otherwise exploitation with \n in filename is possible
	local p = io.popen('find /tmp/_tarex -type f')
	local index = 0
	for file in p:lines() do
		local info = content_info(file)
		index = index + 1

		if info.type == 'cacert' and cfg.ca then
			rename(file, cfg.ca)
		elseif info.type == 'cert' and cfg.cert then
			rename(file, cfg.cert)
		elseif info.type == 'key' and cfg.key then
			rename(file, cfg.key)
		elseif info.type == nil then
			unistd.unlink(file)
		end

		local i = s:element('model/info', {}, 'install_' .. index)
		if info.type then
			i.content = translatef('Successfully installed %s', info.display)
		end
	end

	return true
end

if unistd.access(tmpfile) then
	local info = content_info(tmpfile)

	if info.type == 'cacert' and cfg.ca then
		rename(tmpfile, cfg.ca)
	elseif info.type == 'cert' and cfg.cert then
		rename(tmpfile, cfg.cert)
	elseif info.type == 'key' and cfg.key then
		rename(tmpfile, cfg.key)
	elseif info.type == nil then
		if try_tar() then
			info = {
				type = 'tar',
				display = translatef('Configuration package'),
			}
		end

		unistd.unlink(tmpfile)
	end

	local i = s:element('model/info', {}, 'info_install')
	if info.type then
		i.content = translatef('Successfully installed %s', info.display)
	else
		i.content = translatef('Error: Unknown file')
	end
end

function s:parse(http)
	Element:parse(http)
	self.isRemove = http:formvalue('remove') ~= nil
end

function s:write()
	if self.isRemove then
		-- unlink files
		unistd.unlink(cfg.ca)
		unistd.unlink(cfg.cert)
		unistd.unlink(cfg.key)
		-- restore ca
		os.execute('/lib/gluon/upgrade/400-mesh-vpn-openvpn')
		s:element('model/info', {}, 'info_clear', 'Successfully cleared configuration')
	end
end

if cfg.ca then
	file_info(cfg.ca, translate('CA Cert'))
end
if cfg.cert then
	file_info(cfg.cert, translate('Mesh Cert'))
end
if cfg.key then
	file_info(cfg.key, translate('Mesh Key'))
end

s:element('model/file', {}, 'upload', translate('Upload .tar.gz, key, CA or cert'))

s:element('model/actions', {
	actions = {
		{ 'remove', translate('Reset'), true }
	},
}, 'action')

s:element('model/hideactions', {}, 'hideactions')
s:element('model/common', {}, 'common')

return f
