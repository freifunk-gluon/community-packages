#!/usr/bin/env bash
# Show that the split relay does what this package needs it to: a client
# behind a node whose only client-link address is the shared next_node one
# still gets a lease out of the central range, with its own node as router,
# resolver and server-id - and the answer comes back to the node's own
# address rather than to the shared one.
#
# Three namespaces on the machine you run it on, root needed:
#
#   ./contrib/split-relay-test.sh [dnsmasq] [dhcpcd]
set -eu

DNSMASQ="${1:-dnsmasq}"
DHCPCD="${2:-dhcpcd}"

drop_namespaces() {
	for ns in node srv cli; do ip netns del "$ns" 2>/dev/null || true; done
}
drop_namespaces

D=$(mktemp -d)
trap 'drop_namespaces; rm -rf "$D"' EXIT

ip netns add node; ip netns add srv; ip netns add cli
for ns in node srv cli; do ip -n "$ns" link set lo up; done

# node <-> srv, the mesh
ip link add mesh type veth peer name meshsrv
ip link set mesh netns node; ip link set meshsrv netns srv
ip -n node addr add 10.67.0.1/30 dev mesh; ip -n node link set mesh up
ip -n srv addr add 10.67.0.2/30 dev meshsrv; ip -n srv link set meshsrv up

# node <-> cli, the client link. The node's only address here is next_node,
# which every other node has as well
ip link add lnode type veth peer name lcli
ip link set lnode netns node; ip link set lcli netns cli
ip -n node addr add 10.12.244.1/22 dev lnode; ip -n node link set lnode up
ip -n cli link set lcli up

# the node's own routable address, which is what the server answers to
ip -n node addr add 10.12.23.5/32 dev lo
ip -n srv addr add 10.12.6.66/32 dev lo
ip -n srv route add 10.12.23.5/32 via 10.67.0.1
ip -n node route add 10.12.6.66/32 via 10.67.0.2
ip netns exec node sysctl -qw net.ipv4.ip_forward=1

cat > "$D/srv.conf" <<CONF
port=0
interface=meshsrv
dhcp-range=10.12.244.10,10.12.247.254,255.255.252.0,1h
dhcp-option=option:router,10.12.244.1
dhcp-option=option:dns-server,10.12.244.1
dhcp-authoritative
dhcp-leasefile=$D/leases
log-dhcp
log-facility=$D/srv.log
CONF

cat > "$D/node.conf" <<CONF
port=0
dhcp-split-relay=10.12.244.1,10.12.6.66,10.12.23.5
log-facility=$D/node.log
CONF

ip netns exec srv "$DNSMASQ" -C "$D/srv.conf" --pid-file="$D/srv.pid"
ip netns exec node "$DNSMASQ" -C "$D/node.conf" --pid-file="$D/node.pid"
sleep 1

ip netns exec cli timeout 25 "$DHCPCD" -1 -q -B -t 20 \
	--config /dev/null -o domain_name_servers -o routers \
	--script /bin/true lcli || true

address=$(ip -n cli -4 -o addr show lcli | awk '{print $4}')
echo "client address: ${address:-none}"
grep -E 'DHCPACK|sent size' "$D/srv.log" || true

fail=0
case "$address" in
	10.12.24[4-7].*/22) ;;
	*) echo "FAIL: no lease out of 10.12.244.0/22"; fail=1 ;;
esac
for expect in 'option: 54 server-identifier  10.12.244.1' \
	'option:  3 router  10.12.244.1' \
	'option:  6 dns-server  10.12.244.1' \
	'option:  1 netmask  255.255.252.0'; do
	grep -qF "$expect" "$D/srv.log" || { echo "FAIL: missing $expect"; fail=1; }
done

[ "$fail" -eq 0 ] && echo OK
exit "$fail"
