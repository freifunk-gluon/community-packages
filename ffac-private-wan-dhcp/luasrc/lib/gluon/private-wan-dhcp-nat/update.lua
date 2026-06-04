#!/usr/bin/lua

local uci = require('simple-uci').cursor()

-- Funktion zum Ausführen von Shell-Befehlen und Erfassen der Ausgabe
local function shell(cmd)
	local f = io.popen(cmd)
	local result = f:read("*a")
	f:close()
	return result
end

-- Funktion um uradvd config zu prüfen

-- Funktion um zu prüfen, ob eine Regel bereits existiert
local function uradvd_config_exists(name)
	local exists = false
	uci:foreach('uradvd', 'interface', function(iface)
		if iface.ifname == name then
			exists = true
			return false
		end
	end)
	return exists
end

-- Funktion um uradvd config zu löschen
local function delete_uradvd_section(name)
	uci:delete_all('uradvd', 'interface', function(iface)
		return iface.ifname == name
	end)
end

-- Funktion um zu prüfen, ob eine Regel bereits existiert
local function rule_exists(name)
	local exists = false
	uci:foreach('firewall', 'rule', function(section)
		if section.name == name then
			exists = true
			return false
		end
	end)
	return exists
end

-- Funktion um Regel zu löschen
local function delete_rule(name)
	uci:delete_all('firewall', 'rule', function(section)
		return section.name == name
	end)
end

-- Funktion um zu prüfen, ob ein Forwarding bereits existiert
local function forwarding_exists(src, dest)
	local exists = false
	uci:foreach('firewall', 'forwarding', function(section)
		if section.src == src and section.dest == dest then
			exists = true
			return false
		end
	end)
	return exists
end

-- Funktion um ein forwarding zu löschen
local function delete_forwarding(src, dest)
	-- Funktion um Regel zu löschen
	uci:delete_all('firewall', 'forwarding', function(section)
		return section.src == src and section.dest == dest
	end)
end

if #arg < 1 then
	io.stderr:write('Usage: update.lua up|down\n')
	os.exit(1)
end

local function add_dhcp_config()
	-- IPv4 für DHCP vergeben auf WAN-Interface
	local ipaddr = uci:get('private-wan-dhcp','settings','ipaddr')
	local netmask = uci:get('private-wan-dhcp','settings','netmask')
	uci:set('network', 'wan', 'proto', 'static')
	uci:set('network', 'wan', 'ipaddr', ipaddr)
	uci:set('network', 'wan', 'netmask', netmask)
	-- IPv6 /64 netzwerk auf cellular anfragen
	uci:set('network', 'cellular', 'ip6assign', '64')

	uci:save('network')

	os.execute("/etc/init.d/network reload")

	-- Forwarding über das wwan-Interface erlauben
	uci:set('firewall', '@zone[1]', 'forward', 'ACCEPT')

	-- DHCP in Firewall auf WAN erlauben
	if not rule_exists('Allow-DHCP-WAN') then
		uci:add('firewall', 'rule')
		uci:set('firewall', '@rule[-1]', 'name', 'Allow-DHCP-WAN')
		uci:set('firewall', '@rule[-1]', 'src', 'wan')
		uci:set('firewall', '@rule[-1]', 'proto', 'udp')
		uci:set('firewall', '@rule[-1]', 'src_port', '67 68')
		uci:set('firewall', '@rule[-1]', 'dest_port', '67 68')
		uci:set('firewall', '@rule[-1]', 'target', 'ACCEPT')
	end

	-- DNS in Firewall auf WAN erlauben
	if not rule_exists('Allow-DNS-WAN') then
		uci:add('firewall', 'rule')
		uci:set('firewall', '@rule[-1]', 'name', 'Allow-DNS-WAN')
		uci:set('firewall', '@rule[-1]', 'src', 'wan')
		uci:set('firewall', '@rule[-1]', 'proto', 'tcp udp')
		uci:set('firewall', '@rule[-1]', 'dest_port', '53')
		uci:set('firewall', '@rule[-1]', 'target', 'ACCEPT')
	end

	-- NAT von wan auf wwan einrichten
	if not forwarding_exists('wan', 'wwan') then
		uci:add('firewall', 'forwarding')
		uci:set('firewall', '@forwarding[-1]', 'src', 'wan')
		uci:set('firewall', '@forwarding[-1]', 'dest', 'wwan')
	end

	uci:save('firewall')

	os.execute("/etc/init.d/firewall reload")

	-- DHCP-Server einstellen für wan
	uci:delete('dhcp', 'wan', 'ignore')
	uci:set('dhcp', 'wan', 'start', '100')
	uci:set('dhcp', 'wan', 'limit', '150')
	uci:set('dhcp', 'wan', 'leasetime', '12h')
	uci:set('dhcp', 'wan', 'force', '1')
	local dns_server = uci:get('private-wan-dhcp','settings','dns_server')
	uci:set_list('dhcp', 'wan', 'dhcp_option', { '6,'..dns_server })
	uci:save('dhcp')
	os.execute("/etc/init.d/dnsmasq reload")

	-- Aktuelles IPv6-Präfix von wwan0 abrufen, doppelte Einträge entfernen
	local ipv6_prefix_cmd = "ip -6 addr show dev wwan0 | "
						.. "grep 'global' | "
						.. "grep -v 'temporary' | "
						.. "awk '{print $2}' | "
						.. "cut -f1,2,3,4 -d':' | "
						.. "sed 's/$/::\\/64/' | "
						.. "sort | "
						.. "uniq"
	local ipv6_prefix = shell(ipv6_prefix_cmd):match("%S+")

	-- Schauen ob Prefix gefunden, falls nein kein IPv6
	if ipv6_prefix then
		print("ipv6 prefix is", ipv6_prefix)
		-- Prüfen, ob eine vorhandene Konfiguration für das Interface 'br-wan' existiert
		if uradvd_config_exists('br-wan') then
			delete_uradvd_section('br-wan')
		end

		local br_wan_section = uci:add('uradvd', 'interface')
		-- Konfiguration für 'br-wan' aktualisieren
		uci:set('uradvd', br_wan_section, 'enabled', '1')
		uci:set('uradvd', br_wan_section, 'ifname', 'br-wan')
		uci:set('uradvd', br_wan_section, 'default_lifetime', '1800')
		uci:set_list('uradvd', br_wan_section, 'prefix_on_link', {ipv6_prefix})
		local uradvd_dns_server = uci:get_list('private-wan-dhcp','settings','uradvd_dns_server')
		uci:set_list('uradvd', br_wan_section, 'dns', uradvd_dns_server)
		uci:save('uradvd')

		-- uradvd reload
		os.execute("/etc/init.d/uradvd reload")

		-- IPv6-Policy-Routing: Traffic der br-wan-Clients aus dem LTE-/64 ueber
		-- Tabelle 1 (LTE-Default via wwan0) leiten. Ohne diese Regel faellt der
		-- Client-Traffic auf Tabelle 'main' zurueck -> dort zeigt die v6-Default-
		-- Route auf Freifunk (br-client), und die Clients kommen nicht ueber LTE raus.
		-- Die Section wird mit dem AKTUELLEN Praefix neu gesetzt; da dieses Skript
		-- bei jedem 'ifup' der LTE-Schnittstelle laeuft, ist die Regel praefix-sicher.
		uci:delete('network', 'lte_clients')
		uci:section('network', 'rule6', 'lte_clients', {
			src = ipv6_prefix,
			lookup = '1',
			priority = '9999',
		})
		uci:save('network')
		os.execute("/etc/init.d/network reload")
	end
end

local function remove_dhcp_config()
	delete_rule('Allow-DHCP-WAN')
	delete_rule('Allow-DNS-WAN')
	delete_forwarding('wan', 'wwan')
	uci:save('firewall')
	uci:set('dhcp', 'wan', 'ignore')
	uci:save('dhcp')

	-- IPv6-Policy-Routing-Regel wieder entfernen
	uci:delete('network', 'lte_clients')

	uci:set('network', 'wan', 'proto', 'dhcp')
	uci:delete('network', 'wan', 'ipaddr')
	uci:delete('network', 'wan', 'netmask')
	uci:save('network')
	os.execute("/etc/init.d/network reload")
	os.execute("/etc/init.d/firewall reload")
	os.execute("/etc/init.d/dnsmasq reload")

	-- evtl. noch live haengende Regel (Prio 9999) sicher abraeumen
	os.execute("while ip -6 rule del priority 9999 2>/dev/null; do :; done")

	delete_uradvd_section('br-wan')
	uci:save('uradvd')

	os.execute("/etc/init.d/uradvd reload")
end

if arg[1] == "up" then
	add_dhcp_config()
elseif arg[1] == "down" then
	remove_dhcp_config()
end
