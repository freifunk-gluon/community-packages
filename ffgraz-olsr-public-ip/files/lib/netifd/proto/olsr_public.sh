#!/bin/sh

. /lib/functions.sh
. ../netifd-proto.sh
init_proto "$@"

proto_olsr_public_init_config() {
	proto_config_add_string gateway4
	proto_config_add_string ipaddr4
	proto_config_add_string gateway6
	proto_config_add_string ipaddr6
}

proto_olsr_public_setup() {
	export CONFIG="$1"
	export IFNAME="$2"

	local gateway4 ipaddr4 gateway6 ipaddr6
	json_get_vars gateway4 ipaddr4 gateway6 ipaddr6

	ip tunnel add public4 mode ipip remote "$gateway4" local "$ipaddr4" ttl 255
	ip link set public4 up
	ip addr add "$ipaddr4" dev public4
	ip route add default dev public4 table default

	ip rule add from all lookup 111 pref 20000
	ip rule add from all lookup main pref 30000
	ip rule del pref 32766
}
