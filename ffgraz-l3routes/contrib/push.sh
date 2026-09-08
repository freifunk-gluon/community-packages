#!/bin/sh
# Copy the l3routes packages onto a running node and flag it for a
# reconfigure. Everything they ship is interpreted Lua, so this is a full
# iteration - no build, no flash.
#
#   ./contrib/push.sh root@192.168.178.141

set -e

NODE="${1:?usage: push.sh <user@node>}"
FEED="$(cd "$(dirname "$0")/../.." && pwd)"

# dropbear has no sftp-server, so scp has to speak its own protocol
SCP="scp -O"

ssh "$NODE" 'mkdir -p /lib/gluon/l3routes /usr/lib/lua/gluon'

$SCP "$FEED/ffgraz-l3routes/luasrc/usr/lib/lua/gluon/l3routes.lua" "$NODE:/usr/lib/lua/gluon/"
$SCP "$FEED/ffgraz-l3routes/luasrc/lib/gluon/upgrade/850-l3routes" "$NODE:/lib/gluon/upgrade/"

# every package in the feed that declares something to announce, this one and
# ffgraz-olsr-public-ip alike
for snippet in "$FEED"/*/luasrc/lib/gluon/l3routes/*.lua; do
	[ -e "$snippet" ] || continue
	$SCP "$snippet" "$NODE:/lib/gluon/l3routes/"
done

for applier in "$FEED"/ffgraz-l3routes-*/luasrc/lib/gluon/upgrade/*; do
	[ -e "$applier" ] || continue
	$SCP "$applier" "$NODE:/lib/gluon/upgrade/"
done

for extra in "$FEED"/ffgraz-olsr-public-ip/luasrc/lib/gluon/upgrade/*; do
	[ -e "$extra" ] || continue
	$SCP "$extra" "$NODE:/lib/gluon/upgrade/"
done

for lib in "$FEED"/*/luasrc/usr/lib/lua/gluon/*.lua; do
	[ -e "$lib" ] || continue
	$SCP "$lib" "$NODE:/usr/lib/lua/gluon/"
done

for nft in "$FEED"/*/luasrc/lib/gluon/nftables/*.lua; do
	[ -e "$nft" ] || continue
	$SCP "$nft" "$NODE:/lib/gluon/nftables/"
done

if [ -d "$FEED/ffgraz-web-olsr-public-ip" ]; then
	$SCP "$FEED/ffgraz-web-olsr-public-ip/luasrc/lib/gluon/config-mode/model/admin/publicip.lua" \
		"$NODE:/lib/gluon/config-mode/model/admin/"
fi

if [ -d "$FEED/ffgraz-web-l3routes" ]; then
	$SCP "$FEED/ffgraz-web-l3routes/luasrc/lib/gluon/config-mode/model/admin/l3routes.lua" \
		"$NODE:/lib/gluon/config-mode/model/admin/"
	$SCP "$FEED/ffgraz-web-l3routes/luasrc/lib/gluon/config-mode/controller/admin/l3routes.lua" \
		"$NODE:/lib/gluon/config-mode/controller/admin/"
fi

ssh "$NODE" 'chmod +x /lib/gluon/upgrade/850-l3routes /lib/gluon/upgrade/900-l3routes-* /lib/gluon/upgrade/[0-9]*-public-ip* 2>/dev/null; true'
ssh "$NODE" 'touch /etc/config/gluon-l3routes /etc/config/gluon-l3routes-custom'
ssh "$NODE" 'gluon-reconfigure'
