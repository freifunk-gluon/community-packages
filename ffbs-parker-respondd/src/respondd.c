// SPDX-License-Identifier: Apache-2.0

#include <respondd.h>

#include <json-c/json.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <net/if.h>
#include <errno.h>

#define BUFFER_SIZE 4096

/* Name prefix of the mesh VPN tunnels ffbs-mesh-vpn-parker sets up. A node
 * without a tunnel of its own reaches the network through another node;
 * gluon-mesh-batman-adv reports the gateway for that case. */
#define MESH_VPN_PREFIX "wg_"

struct gatewayinfo {
	char interface[IF_NAMESIZE];
	char gateway[INET6_ADDRSTRLEN];
};

static bool is_mesh_vpn(const char * interface) {
	return strncmp(interface, MESH_VPN_PREFIX, strlen(MESH_VPN_PREFIX)) == 0;
}

/* Fill gwinfo from a route message, if it describes the default route over
 * one of our mesh VPN tunnels. */
static bool parse_route(struct nlmsghdr * nlh, struct gatewayinfo * gwinfo) {
	// This struct contain route attributes (route type)
	struct  rtattr *route_attribute;
	struct  rtmsg *route_entry = (struct rtmsg *) NLMSG_DATA(nlh);
	int     route_attribute_len = RTM_PAYLOAD(nlh);
	char    interface[IF_NAMESIZE] = "";
	char    gateway_address[INET6_ADDRSTRLEN] = "";

	/* We are just interested in the default routes of the main routing table */
	if (route_entry->rtm_table != RT_TABLE_MAIN || route_entry->rtm_dst_len != 0)
		return false;

	route_attribute = (struct rtattr *) RTM_RTA(route_entry);

	/* Loop through all attributes */
	for ( ; RTA_OK(route_attribute, route_attribute_len); route_attribute = RTA_NEXT(route_attribute, route_attribute_len))
	{
		switch(route_attribute->rta_type) {
			case RTA_OIF:
				if_indextoname(*(unsigned int *)RTA_DATA(route_attribute), interface);
				break;
			case RTA_GATEWAY:
				inet_ntop(route_entry->rtm_family, RTA_DATA(route_attribute),
						gateway_address, sizeof(gateway_address));
				break;
			default:
				break;
		}
	}

	/* A node may have a default route of its own next to the one over the
	 * tunnel, so it is not enough to take the first one we are told about. */
	if (!*gateway_address || !is_mesh_vpn(interface))
		return false;

	snprintf(gwinfo->interface, sizeof(gwinfo->interface), "%s", interface);
	snprintf(gwinfo->gateway, sizeof(gwinfo->gateway), "%s", gateway_address);

	return true;
}

int getgatewayandiface(struct gatewayinfo * gwinfo, sa_family_t family) {
	struct {
		struct nlmsghdr nlh;
		struct rtmsg rtm;
	} req = {};
	struct  nlmsghdr *nlh;
	char    buffer[BUFFER_SIZE];
	struct  timeval tv;
	int     received_bytes = 0;
	int     sock = -1;
	int     error = 0;

	if ((sock = socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE)) < 0) {
		perror("socket failed");
		return 1;
	}

	/* Fill in the nlmsg header*/
	req.nlh.nlmsg_len = NLMSG_LENGTH(sizeof(req.rtm));
	req.nlh.nlmsg_type = RTM_GETROUTE; // Get the routes from kernel routing table .
	req.nlh.nlmsg_flags = NLM_F_DUMP | NLM_F_REQUEST; // The message is a request for dump.
	req.nlh.nlmsg_seq = 1; // Sequence of the message packet.
	req.nlh.nlmsg_pid = getpid(); // PID of process sending the request.
	req.rtm.rtm_family = family;

	/* 1 Sec Timeout to avoid stall */
	tv.tv_sec = 1;
	tv.tv_usec = 0;
	setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (struct timeval *)&tv, sizeof(struct timeval));
	/* send msg */
	if (send(sock, &req, req.nlh.nlmsg_len, 0) < 0) {
		perror("send failed");
		error = 2;
		goto stop_now;
	}

	/* The kernel spreads the dump over as many datagrams as it needs, so
	 * every one of them has to be parsed as it arrives. */
	for (;;)
	{
		received_bytes = recv(sock, buffer, sizeof(buffer), 0);
		if (received_bytes < 0) {
			perror("Error in recv");
			error = 3;
			goto stop_now;
		}

		/* parse response */
		for (nlh = (struct nlmsghdr *) buffer; NLMSG_OK(nlh, received_bytes); nlh = NLMSG_NEXT(nlh, received_bytes))
		{
			/* If we received all data we are done */
			if (nlh->nlmsg_type == NLMSG_DONE)
				goto stop_now;

			if (nlh->nlmsg_type == NLMSG_ERROR) {
				perror("Error in received packet");
				error = 4;
				goto stop_now;
			}

			if (nlh->nlmsg_type != RTM_NEWROUTE)
				continue;

			if (parse_route(nlh, gwinfo))
				goto stop_now;
		}
	}

	stop_now:
	close(sock);

	return error;
}


static struct json_object * respondd_parker_gateway(void) {
	struct json_object *ret = json_object_new_object();
	struct gatewayinfo gwinfo4 = {0};
	struct gatewayinfo gwinfo6 = {0};

	/* The IPv6 default route is the one that tells us how this node is
	 * connected: with 464XLAT the clients' IPv4 traffic is translated to
	 * IPv6 before it reaches the tunnel. */
	if (getgatewayandiface(&gwinfo6, AF_INET6) == 0 && *gwinfo6.interface) {
		json_object_object_add(ret, "gateway6", json_object_new_string(gwinfo6.gateway));
		json_object_object_add(ret, "gateway_nexthop", json_object_new_string(gwinfo6.interface));
	}

	/* Only networks that route IPv4 over the tunnel have an IPv4 next hop
	 * to report. */
	if (getgatewayandiface(&gwinfo4, AF_INET) == 0 && *gwinfo4.interface) {
		json_object_object_add(ret, "gateway", json_object_new_string(gwinfo4.gateway));
	}

	return ret;
}


const struct respondd_provider_info respondd_providers[] = {
	{"statistics", respondd_parker_gateway},
	{}
};
