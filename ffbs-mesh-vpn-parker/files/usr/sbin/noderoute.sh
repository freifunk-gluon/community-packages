#!/bin/busybox sh
# simple script to loop noderoute lua script
# shellcheck shell="busybox sh"

tmpdir=/tmp/ff-Ohb0ba0u/
config_file="${tmpdir}noderoute.json"
cycle_stamp="${tmpdir}noderoute-cycle"

# A tunnel counts as usable while its last handshake is younger than this.
# Keep in sync with noderoute.lua.
HANDSHAKE_MAX_AGE=180
# Shortest possible time between two cycles.
CYCLE_SLEEP=10
# How much longer we idle at the end of a cycle if nothing happens.
IDLE_SLEEP=20
# How often we look for something to happen while idling.
POLL_SLEEP=5
# How long we wait for the first tunnel after startup before we configure
# this node as a client of some other node.
STARTUP_TIMEOUT=60
STARTUP_POLL_SLEEP=2
# How long we give the network to bring bat0 up on its own before we
# restart it, and how often we look while doing so.
BATMAN_GRACE=30
BATMAN_POLL_SLEEP=10

LOGGER="logger -s -t noderoute.sh"
$LOGGER Starting up.

# The set of usable tunnels the running configuration is based on.
tunnels=""

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

recover_batman() {
	# Wait for a functional batman-setup, restarting the network if it
	# does not come up on its own. Right after boot bat0 may simply not
	# be there yet, so give the network some time before hitting it with
	# a restart.
	local waited=0
	while ! check_batman; do
		if [ "$waited" -ge "$BATMAN_GRACE" ]; then
			$LOGGER Restarting network to get a working BATMAN-interface
			/etc/init.d/network restart
			waited=0
		fi
		sleep "$BATMAN_POLL_SLEEP"
		waited=$((waited + BATMAN_POLL_SLEEP))
	done
}

active_tunnels() {
	# The wg-interfaces with a recent handshake, i.e. the tunnels
	# noderoute.lua considers usable.
	wg show all latest-handshakes |
		awk -v max_age="$HANDSHAKE_MAX_AGE" '$3 > 0 && systime() - $3 < max_age { printf "%s ", $1 }'
}

new_config() {
	# Has nodeconfig.sh installed a configuration since our last cycle
	# started? Before the first cycle there is nothing to compare against
	# and a configuration on its own is no reason to do anything.
	[ -f "$cycle_stamp" ] && [ -f "$config_file" ] && [ "$config_file" -nt "$cycle_stamp" ]
}

wait_for_change() {
	# Wait until the set of usable tunnels or the configuration changes,
	# but no longer than $1 seconds. Checks every $2 seconds and returns
	# 0 if something changed.
	local waited=0
	while true; do
		if [ "$(active_tunnels)" != "$tunnels" ]; then
			$LOGGER Set of usable tunnels changed
			return 0
		fi
		if new_config; then
			$LOGGER New configuration available
			return 0
		fi
		if [ "$waited" -ge "$1" ]; then
			return 1
		fi
		sleep "$2"
		waited=$((waited + $2))
	done
}

# Do not tear the client network down before nodeconfig.sh had a chance to
# bring the tunnels up: switching the node to client mode and back costs
# minutes, waiting here costs seconds. wait_for_change() returns as soon as
# the first tunnel is there, so a healthy node hardly waits at all.
if [ "$(uci -q get gluon.mesh_vpn.enabled)" = 1 ]; then
	$LOGGER "Waiting up to ${STARTUP_TIMEOUT}s for the first tunnel"
	if ! wait_for_change "$STARTUP_TIMEOUT" "$STARTUP_POLL_SLEEP"; then
		$LOGGER No tunnel came up. Continuing without one.
	fi
fi

while true; do
	$LOGGER Cycling
	touch "$cycle_stamp"
	tunnels="$(active_tunnels)"
	if ! lua /usr/share/lua/noderoute.lua $tmpdir ; then
		$LOGGER noderoute.lua returned non-zero
	fi
	touch ${tmpdir}/noderoute-successful
	sleep "$CYCLE_SLEEP"

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

	recover_batman

	wait_for_change "$IDLE_SLEEP" "$POLL_SLEEP"
done
