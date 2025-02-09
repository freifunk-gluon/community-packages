#!/bin/busybox sh
# simple script to loop noderoute lua script

tmpdir=/tmp/ff-Ohb0ba0u/

LOGGER="logger -s -t noderoute.sh"
$LOGGER Starting up.

check_batman() {
    # check if we have a functional batman-setup
    if ! ip l | grep -q "bat0:"; then
        $LOGGER ERROR: No BATMAN-interface found
        return 1
    fi

    if ip l | grep "bat0:" | grep -q DOWN; then
        $LOGGER ERROR: BATMAN-interface is not up
        return 1
    fi

    if ! ip l | grep "bat0:" | grep -q br-client; then
        $LOGGER ERROR: bat0 not part of br-client
        return 1
    fi
    return 0
}

while true; do
    $LOGGER Cycling
    if ! lua /usr/share/lua/noderoute.lua $tmpdir | $LOGGER; then
        $LOGGER noderoute.lua returned non-zero
    fi
    touch ${tmpdir}/noderoute-successful
    sleep 10

    if batctl gw | grep -q server; then
        # sanity check: is uradvd running?
        if ! pidof uradvd > /dev/null; then
            $LOGGER ERROR: NO URADVD RUNNING.
        fi

        # sanity check: does dnsmasq have a valid config?
        if ! grep -qF "dhcp-range=set:client" /var/etc/dnsmasq.conf.cfg*; then
            $LOGGER ERROR: NO DHCP-RANGE IN dnsmasq.conf.
        fi
    fi

    while (! check_batman); do
        /etc/init.d/network restart
        sleep 30
    done;

    sleep 20
done
