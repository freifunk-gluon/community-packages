#!/bin/sh
# Test of the answers of dnsmasq with and without authoritative
# (site option parker.dhcp_authoritative, see README.md).
# Needs root (network namespaces), dnsmasq, iproute2 and python3. Example:
#   docker run --rm --privileged -v "$PWD":/w alpine:3.20 sh -c \
#     'apk add -q dnsmasq iproute2 python3 && sh /w/tests/dhcp-authoritative-test.sh'
# A client with a lease of another uplink sends a rebinding request (broadcast).
# An authoritative dnsmasq answers it with a DHCPACK: the client keeps its
# address but gets a new router. Without authoritative, dnsmasq does not answer,
# and the client gets a new lease with a DHCPDISCOVER at the end of its lease.
set -e
DIR=$(cd "$(dirname "$0")/.." && pwd)
FAIL=0
PID=""

# shellcheck disable=SC2317,SC2329
cleanup() {
	[ -n "$PID" ] && kill "$PID" 2>/dev/null
	ip netns del cl 2>/dev/null || true
	ip netns del srv 2>/dev/null || true
	rm -f /tmp/dhcp-auth.leases
}
trap cleanup EXIT

check() {
	if [ "$2" = "$3" ]; then
		echo "  ok:   $1"
	else
		echo "  FAIL: $1 (expected $3, got $2)"
		FAIL=1
	fi
}

ip netns add cl
ip netns add srv
ip link add eth0 netns cl type veth peer name eth0 netns srv
ip -n srv addr add 10.0.0.1/24 dev eth0
ip -n cl addr add 10.0.0.50/24 dev eth0
for n in cl srv; do ip -n "$n" link set eth0 up; ip -n "$n" link set lo up; done


# dnsmasq like a Parker node. $@: extra options.
dnsmasq_start() {
	[ -n "$PID" ] && kill "$PID" 2>/dev/null && sleep 0.5
	: > /tmp/dhcp-auth.leases
	ip netns exec srv dnsmasq -k --port=0 --no-resolv --no-hosts --interface=eth0 \
		--dhcp-leasefile=/tmp/dhcp-auth.leases --pid-file= --no-ping "$@" 2>/dev/null &
	PID=$!
	sleep 1
}

client() {
	ip netns exec cl python3 "$DIR/tests/dhcp-authoritative-client.py" "$@"
}

POOL="--dhcp-range=10.0.0.10,10.0.0.100,255.255.255.0,3m"

echo "1. authoritative (OpenWrt default): rebinding of a lease of another uplink"
dnsmasq_start "$POOL" --dhcp-authoritative
check "DHCPACK in place (the router of the client changes)" \
	"$(client request 255.255.255.255 10.0.0.50)" ack

echo "2. not authoritative: rebinding of a lease of another uplink"
dnsmasq_start "$POOL"
check "no answer" "$(client request 255.255.255.255 10.0.0.50)" none
check "INIT-REBOOT: no answer" "$(client request 255.255.255.255 0.0.0.0 10.0.0.50)" none
check "renewal per unicast after a lease loss (reboot): DHCPNAK" \
	"$(client request 10.0.0.1 10.0.0.50)" nak

echo "3. not authoritative: a new lease and its renewal"
dnsmasq_start "$POOL"
check "DHCPDISCOVER: DHCPOFFER" "$(client discover 255.255.255.255 0.0.0.0)" offer
check "DHCPREQUEST: DHCPACK" \
	"$(client request 255.255.255.255 0.0.0.0 10.0.0.50 10.0.0.1)" ack
check "renewal per unicast: DHCPACK" "$(client request 10.0.0.1 10.0.0.50)" ack
check "rebinding: DHCPACK" "$(client request 255.255.255.255 10.0.0.50)" ack

echo "4. one range per node: 10.0.1.50 is an address of another node"
dnsmasq_start "$POOL" --dhcp-authoritative
check "authoritative, rebinding: DHCPNAK" "$(client request 255.255.255.255 10.0.1.50)" nak
check "authoritative, INIT-REBOOT: DHCPNAK" \
	"$(client request 255.255.255.255 0.0.0.0 10.0.1.50)" nak
check "authoritative, INIT-REBOOT in its own range after a reboot: DHCPACK" \
	"$(client request 255.255.255.255 0.0.0.0 10.0.0.50)" ack
dnsmasq_start "$POOL"
check "not authoritative, rebinding: no answer" "$(client request 255.255.255.255 10.0.1.50)" none
check "not authoritative, INIT-REBOOT: no answer" \
	"$(client request 255.255.255.255 0.0.0.0 10.0.1.50)" none
check "not authoritative, INIT-REBOOT in its own range after a reboot: no answer" \
	"$(client request 255.255.255.255 0.0.0.0 10.0.0.50)" none

exit $FAIL
