#!/bin/busybox sh
# !!!!!!
# THIS SCRIPT MUST HAVE GID 800 (gluon-mesh-vpn)
# USE `gluon-wan nodeconfig.sh`
# !!!!!!
SIGN_PUB_KEY=/etc/parker/node-config-pub.key
DEFAULT_SLEEP=20
export LIBPACKETMARK_MARK=1

tmpdir=/tmp/ff-Ohb0ba0u/
mkdir -p "$tmpdir"

version="$(cat /lib/gluon/release)"

LOGGER="logger -s -t nodeconfig.sh"
$LOGGER "Starting up. I am running ${version}"

if [ ! -s /etc/parker/wg-privkey ]; then
    $LOGGER No Wireguard keys found, generating...
    mkdir -p /etc/parker
    rm -f /etc/parker/wg-pubkey
    wg genkey > /etc/parker/wg-privkey.tmp
    wg pubkey < /etc/parker/wg-privkey.tmp > /etc/parker/wg-pubkey
    sync
    mv /etc/parker/wg-privkey.tmp /etc/parker/wg-privkey
    $LOGGER Wireguard keys generated
else
    $LOGGER Wireguard keys found, proceeding
fi

pubkey=$(sed 's/+/%2B/g' /etc/parker/wg-pubkey)

while true; do
    vpn_enabled=$(uci get gluon.mesh_vpn.enabled)
    if [ "$vpn_enabled" == 0 ]; then
        sleep $DEFAULT_SLEEP
        continue
    fi
    rm -f "${tmpdir}config.json" "${tmpdir}config.json.sig"
    nonce=""
    while [ -z "${nonce}" ]; do
        nonce=$(head -c16 /dev/urandom | md5sum | head -c32)
    done
    v6mtu="$(cat /proc/sys/net/ipv6/conf/br-wan/mtu)"
    if ! ip route show table 1 | grep -Fq via ; then
        $LOGGER no WAN route. Doing nothing.
        sleep $DEFAULT_SLEEP
        continue;
    fi

    if ! config_server=$(uci get parker.nodeconfig.config_server); then
        $LOGGER unable to get config_server from uci
        exit 1
    fi

    LD_PRELOAD=libpacketmark.so wget "http://${config_server}/config?pubkey=${pubkey}&nonce=${nonce}&v6mtu=${v6mtu}&version=${version}" -O "${tmpdir}response" -q
    RET=$?
    if [ $RET -gt 0 ]; then
        $LOGGER "failed to fetch config with exit code $RET. Doing nothing."
        sleep $DEFAULT_SLEEP
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
            sleep "$slp"
        else
            echo "$outp"
            $LOGGER nodeconfig.lua failed.
            sleep "$DEFAULT_SLEEP"
        fi
    else
        $LOGGER Signature validation failed. Doing nothing.
        sleep "$DEFAULT_SLEEP"
    fi
done
