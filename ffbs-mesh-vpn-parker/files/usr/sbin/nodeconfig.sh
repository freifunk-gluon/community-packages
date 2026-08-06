#!/bin/busybox sh
# !!!!!!
# THIS SCRIPT MUST HAVE GID 800 (gluon-mesh-vpn)
# USE `gluon-wan-dns nodeconfig.sh`
# !!!!!!
SIGN_PUB_KEY=/tmp/ff-Ohb0ba0u/nodeconfig-pub.key
DEFAULT_SLEEP=20
# Time to wait before the first retry. A node that boots with a working
# uplink makes its first attempts while the WAN is still coming up, so
# retrying quickly at first gets us our configuration a lot earlier. Every
# further attempt that fails doubles the delay, up to DEFAULT_SLEEP.
INITIAL_SLEEP=2
export LIBPACKETMARK_MARK=1

tmpdir=/tmp/ff-Ohb0ba0u/
mkdir -p "$tmpdir"

version="$(cat /lib/gluon/release)"

LOGGER="logger -s -t nodeconfig.sh"
$LOGGER "Starting up. I am running ${version}"

retry_sleep=$INITIAL_SLEEP

retry() {
	# Wait before the next attempt and back off for the attempt after that.
	sleep "$retry_sleep"
	retry_sleep=$((retry_sleep * 2))
	if [ "$retry_sleep" -gt "$DEFAULT_SLEEP" ]; then
		retry_sleep=$DEFAULT_SLEEP
	fi
}

if [ ! -s /etc/parker/wg-privkey ]; then
	$LOGGER No Wireguard private key found, generating...
	mkdir -p /etc/parker
	rm -f /etc/parker/wg-pubkey
	wg genkey > /etc/parker/wg-privkey.tmp
	sync
	mv /etc/parker/wg-privkey.tmp /etc/parker/wg-privkey
	$LOGGER Wireguard private key generated
else
	$LOGGER Wireguard private key found, proceeding
fi

if [ ! -s /etc/parker/wg-pubkey ]; then
	$LOGGER No Wireguard public key found, generating...
	rm -f /etc/parker/wg-pubkey
	wg pubkey < /etc/parker/wg-privkey > /etc/parker/wg-pubkey
	sync
	$LOGGER Wireguard public key generated
fi

pubkey=$(sed 's/+/%2B/g' /etc/parker/wg-pubkey)

if ! { echo "untrusted comment: signify public key" && uci -q get parker.nodeconfig.config_pubkey; } > "${SIGN_PUB_KEY}"; then
	$LOGGER unable to read pubkey from uci or write it to "${SIGN_PUB_KEY}"
	exit 1
fi

# Prepare reporting of tc
# These values can (by definition) only change in config-mode.
# So it is sufficient to prepare these values outside of the main loop.
tc_info=""
tc_enabled=$(uci get gluon.mesh_vpn.limit_enabled)
if [ "$tc_enabled" == 1 ]; then
	tc_ingress=$(uci get gluon.mesh_vpn.limit_ingress | tr -cd 0123456789)
	tc_egress=$(uci get gluon.mesh_vpn.limit_egress | tr -cd 0123456789)
	tc_info="&tc_ingress=${tc_ingress}&tc_egress=${tc_egress}"
fi

while true; do
	vpn_enabled=$(uci get gluon.mesh_vpn.enabled)
	if [ "$vpn_enabled" == 0 ]; then
		touch ${tmpdir}/nodeconfig-successful
		sleep $DEFAULT_SLEEP
		continue
	fi
	rm -f "${tmpdir}config.json" "${tmpdir}config.json.sig"
	nonce=""
	while [ -z "${nonce}" ]; do
		nonce=$(head -c16 /dev/urandom | md5sum | head -c32)
	done
	if ! ip route show table 1 | grep -Fq via ; then
		$LOGGER no WAN route. Doing nothing.
		retry
		continue;
	fi

	# Only read this once there is a WAN route: right after boot br-wan
	# may not exist yet.
	v6mtu="$(cat /proc/sys/net/ipv6/conf/br-wan/mtu)"

	if ! config_server=$(uci get parker.nodeconfig.config_server); then
		$LOGGER unable to get config_server from uci
		exit 1
	fi

	LD_PRELOAD=libpacketmark.so wget "http://${config_server}/config?pubkey=${pubkey}&nonce=${nonce}&v6mtu=${v6mtu}&version=${version}${tc_info}" -O "${tmpdir}response" -q
	RET=$?
	if [ $RET -gt 0 ]; then
		$LOGGER "failed to fetch config with exit code $RET. Doing nothing."
		retry
		continue;
	fi

	head -n -1 "${tmpdir}response" > "${tmpdir}config.json"
	echo "" > "${tmpdir}config.json.sig"
	tail -n 1 "${tmpdir}response" >> "${tmpdir}config.json.sig"

	if usign -V -m "${tmpdir}config.json" -p $SIGN_PUB_KEY -q ; then
		if outp=$(lua /usr/share/lua/nodeconfig.lua "${tmpdir}config.json" "$nonce" "$tmpdir") ; then
			echo "$outp"
			slp=$(echo "$outp" | tail -n1)
			$LOGGER "nodeconfig.lua successful. Sleeping ${slp}s".
			touch ${tmpdir}/nodeconfig-successful
			retry_sleep=$INITIAL_SLEEP
			sleep "$slp"
		else
			echo "$outp"
			$LOGGER nodeconfig.lua failed.
			retry
		fi
	else
		$LOGGER Signature validation failed. Doing nothing.
		retry
	fi
done
