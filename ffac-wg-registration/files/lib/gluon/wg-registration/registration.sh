#!/bin/sh

if [ "$(uci get gluon.mesh_vpn.enabled)" == "true" ] || [ "$(uci get gluon.mesh_vpn.enabled)" == "1" ]; then
        # check if registration has been done since last boot
        if [ ! -f /tmp/WG_REGISTRATION_SUCCESSFUL ]; then
		# Push public key to broker, test for https and use if supported
		if wget -q "https://[::1]"
		then
			PROTO=https
		else
			PROTO=http
		fi
		PUBLICKEY=$(uci get network.wg_mesh.private_key | wg pubkey)
		NODENAME=$(uci get system.@system[0].hostname)
		BROKER=$(uci get wireguard.mesh_vpn.broker)
		logger -t wg-registration "Post $NODENAME and $PUBLICKEY to $PROTO://$BROKER"
		gluon-wan wget -q  -O- --post-data='{"node_name": "'"$NODENAME"'","public_key": "'"$PUBLICKEY"'"}' $PROTO://$BROKER
		if [ $? -eq 0 ]; then
			touch /tmp/WG_REGISTRATION_SUCCESSFUL
			logger -t wg-registration "successfully registered wg publickey"
		fi
	fi
fi
