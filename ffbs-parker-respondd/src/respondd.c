// SPDX-License-Identifier: Apache-2.0

#include "clients.h"

#include <respondd.h>

#include <iwinfo.h>
#include <json-c/json.h>
#include <uci.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <stdbool.h>
#include <stdint.h>
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

/* Name prefix of the mesh VPN tunnels ffbs-mesh-vpn-parker sets up. */
#define MESH_VPN_PREFIX "wg_"

#define SYSFS_NET "/sys/class/net/"

#define CLIENT_BRIDGE "br-client"

struct gatewayinfo {
	char interface[IF_NAMESIZE];
	char gateway4[INET_ADDRSTRLEN];
	char gateway6[INET6_ADDRSTRLEN];
};

int getgatewayandiface(struct gatewayinfo * gwinfo, sa_family_t family) {
	int     received_bytes = 0, msg_len = 0, route_attribute_len = 0;
	int     sock = -1, msgseq = 0;
	struct  nlmsghdr *nlh, *nlmsg;
	struct  rtmsg *route_entry, *req_rtmsg;
	// This struct contain route attributes (route type)
	struct  rtattr *route_attribute;
	char    gateway_address[INET6_ADDRSTRLEN];
	char    msgbuf[BUFFER_SIZE], buffer[BUFFER_SIZE];
	char    *ptr = buffer;
	struct  timeval tv;
	int     error = 0;

	if ((sock = socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE)) < 0) {
		perror("socket failed");
		error = 1;
		goto stop_now;
	}

	memset(msgbuf, 0, sizeof(msgbuf));
	memset(gateway_address, 0, sizeof(gateway_address));
	memset(buffer, 0, sizeof(buffer));

	/* point the header and the msg structure pointers into the buffer */
	nlmsg = (struct nlmsghdr *)msgbuf;

	req_rtmsg = (struct rtmsg *) (msgbuf + sizeof(struct nlmsghdr));

	/* Fill in the nlmsg header*/
	nlmsg->nlmsg_len = NLMSG_LENGTH(sizeof(struct rtmsg));
	nlmsg->nlmsg_type = RTM_GETROUTE; // Get the routes from kernel routing table .
	nlmsg->nlmsg_flags = NLM_F_DUMP | NLM_F_REQUEST; // The message is a request for dump.
	nlmsg->nlmsg_seq = msgseq++; // Sequence of the message packet.
	nlmsg->nlmsg_pid = getpid(); // PID of process sending the request.
	req_rtmsg->rtm_family = family;

	/* 1 Sec Timeout to avoid stall */
	tv.tv_sec = 1;
	setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (struct timeval *)&tv, sizeof(struct timeval));
	/* send msg */
	if (send(sock, nlmsg, nlmsg->nlmsg_len, 0) < 0) {
		perror("send failed");
		error = 2;
		goto stop_now;
	}

	/* receive response */
	do
	{
		received_bytes = recv(sock, ptr, sizeof(buffer) - msg_len, 0);
		if (received_bytes < 0) {
			perror("Error in recv");
			error = 3;
			goto stop_now;
		}

		nlh = (struct nlmsghdr *) ptr;

		/* Check if the header is valid */
		if((NLMSG_OK(nlmsg, received_bytes) == 0) ||
				(nlmsg->nlmsg_type == NLMSG_ERROR))
		{
			perror("Error in received packet");
			error = 4;
			goto stop_now;
		}

		/* If we received all data break */
		if (nlh->nlmsg_type == NLMSG_DONE)
			break;
		else {
			ptr += received_bytes;
			msg_len += received_bytes;
		}

		/* Break if its not a multi part message */
		if ((nlmsg->nlmsg_flags & NLM_F_MULTI) == 0)
			break;
	}
	while ((nlmsg->nlmsg_seq != msgseq) || (nlmsg->nlmsg_pid != getpid()));

	/* parse response */
	for ( ; NLMSG_OK(nlh, received_bytes); nlh = NLMSG_NEXT(nlh, received_bytes))
	{
		/* Get the route data */
		route_entry = (struct rtmsg *) NLMSG_DATA(nlh);

		/* We are just interested in main routing table */
		if (route_entry->rtm_table != RT_TABLE_MAIN)
			continue;

		route_attribute = (struct rtattr *) RTM_RTA(route_entry);
		route_attribute_len = RTM_PAYLOAD(nlh);

		/* Loop through all attributes */
		for ( ; RTA_OK(route_attribute, route_attribute_len); route_attribute = RTA_NEXT(route_attribute, route_attribute_len))
		{
			switch(route_attribute->rta_type) {
				case RTA_OIF:
					if (family == AF_INET) {
						if_indextoname(*(int *)RTA_DATA(route_attribute), gwinfo->interface);
					}
					break;
				case RTA_GATEWAY:
					inet_ntop(req_rtmsg->rtm_family, RTA_DATA(route_attribute),
							gateway_address, sizeof(gateway_address));
					break;
				default:
					break;
			}
		}

		if (*gateway_address) {
			if (req_rtmsg->rtm_family == AF_INET) {
				strncpy(gwinfo->gateway4, gateway_address, INET_ADDRSTRLEN);
			} else if (req_rtmsg->rtm_family == AF_INET6) {
				strncpy(gwinfo->gateway6, gateway_address, INET6_ADDRSTRLEN);
			}
			break;
		}
	}

	stop_now:
	close(sock);

	return error;
}


static bool is_mesh_vpn(const char * interface) {
	return strncmp(interface, MESH_VPN_PREFIX, strlen(MESH_VPN_PREFIX)) == 0;
}

static bool read_counter(const char *interface, const char *name, uint64_t *value) {
	char path[sizeof(SYSFS_NET) + IF_NAMESIZE + 32];
	unsigned long long v;
	FILE *f;
	bool ok;

	snprintf(path, sizeof(path), SYSFS_NET "%s/statistics/%s", interface, name);
	f = fopen(path, "r");
	if (!f)
		return false;
	ok = fscanf(f, "%llu", &v) == 1;
	fclose(f);
	if (ok)
		*value += v;
	return ok;
}

static struct json_object * new_counter(uint64_t packets, uint64_t bytes) {
	struct json_object *ret = json_object_new_object();

	json_object_object_add(ret, "packets", json_object_new_int64(packets));
	json_object_object_add(ret, "bytes", json_object_new_int64(bytes));
	return ret;
}

/* The client traffic of a parker node goes through its mesh VPN tunnels,
 * not through bat0. Thus "rx" and "tx" are the sums of all wg_* tunnels.
 * "forward", "mgmt_rx" and "mgmt_tx" stay as gluon-mesh-batman-adv reports
 * them for the batman-adv mesh to other nodes. */
static void add_traffic(struct json_object *obj) {
	struct if_nameindex *ifs = if_nameindex(), *i;
	uint64_t rx_packets = 0, rx_bytes = 0, tx_packets = 0, tx_bytes = 0, tx_dropped = 0;
	bool found = false;
	struct json_object *traffic, *tx;

	if (!ifs)
		return;

	for (i = ifs; i->if_index; i++) {
		if (!is_mesh_vpn(i->if_name))
			continue;
		found |= read_counter(i->if_name, "rx_packets", &rx_packets);
		read_counter(i->if_name, "rx_bytes", &rx_bytes);
		read_counter(i->if_name, "tx_packets", &tx_packets);
		read_counter(i->if_name, "tx_bytes", &tx_bytes);
		read_counter(i->if_name, "tx_dropped", &tx_dropped);
	}
	if_freenameindex(ifs);

	if (!found)
		return;

	traffic = json_object_new_object();
	tx = new_counter(tx_packets, tx_bytes);
	json_object_object_add(tx, "dropped", json_object_new_int64(tx_dropped));
	json_object_object_add(traffic, "rx", new_counter(rx_packets, rx_bytes));
	json_object_object_add(traffic, "tx", tx);
	json_object_object_add(obj, "traffic", traffic);
}

/* noderoute sets the client interface to "static" while the node routes
 * for its clients, and to "dhcp" while it is a mesh-only node. */
static bool is_routing(struct uci_context *ctx) {
	struct uci_package *p;
	struct uci_section *s;
	const char *proto;

	if (uci_load(ctx, "network", &p))
		return false;
	s = uci_lookup_section(ctx, p, "client");
	proto = s ? uci_lookup_option_string(ctx, s, "proto") : NULL;
	return proto && strcmp(proto, "static") == 0;
}

static void add_iface_stations(struct macset *set, const char *ifname) {
	const struct iwinfo_ops *iw = iwinfo_backend(ifname);
	struct iwinfo_assoclist_entry *entry;
	char buf[IWINFO_BUFSIZE];
	int len;

	if (!iw || iw->assoclist(ifname, buf, &len) < 0)
		return;

	for (entry = (struct iwinfo_assoclist_entry *)buf; (char *)(entry + 1) <= buf + len; entry++) {
		if (entry->inactive > CLIENT_MAX_INACTIVITY_MS)
			continue;
		macset_add(set, entry->mac);
	}
}

/* The same access points as gluon-respondd counts for "wifi". */
static void add_stations(struct uci_context *ctx, struct macset *set) {
	struct uci_package *p;
	struct uci_element *e;

	if (uci_load(ctx, "wireless", &p))
		return;

	uci_foreach_element(&p->sections, e) {
		struct uci_section *s = uci_to_section(e);
		const char *network, *mode, *ifname;

		if (strcmp(s->type, "wifi-iface"))
			continue;
		network = uci_lookup_option_string(ctx, s, "network");
		mode = uci_lookup_option_string(ctx, s, "mode");
		ifname = uci_lookup_option_string(ctx, s, "ifname");
		if (!network || strcmp(network, "client") || !mode || strcmp(mode, "ap") || !ifname)
			continue;
		add_iface_stations(set, ifname);
	}
}

/* gluon-mesh-batman-adv counts the clients in the local translation table
 * of bat0. A routing node is the router of its clients: their frames stay
 * in br-client and do not go into bat0. Thus count the MACs that the bridge
 * learned on its client ports, and the stations of the access points (a
 * sleeping station sends no frames to the bridge). The clients of other
 * nodes come in through bat0 and do not count. */
static void add_clients(struct json_object *obj) {
	struct fdb_filter filter = {
		.bridge = if_nametoindex(CLIENT_BRIDGE),
		.skip = { if_nametoindex("bat0"), if_nametoindex("local-port") },
		.skip_len = 2,
	};
	struct macset set = {};
	struct uci_context *ctx;
	struct json_object *clients;

	if (!filter.bridge)
		return;

	ctx = uci_alloc_context();
	if (!ctx)
		return;
	ctx->flags &= ~UCI_FLAG_STRICT;

	if (!is_routing(ctx))
		goto out;

	if (fdb_clients(&filter, &set))
		goto out;
	add_stations(ctx, &set);

	clients = json_object_new_object();
	json_object_object_add(clients, "total", json_object_new_int(set.len));
	json_object_object_add(obj, "clients", clients);

out:
	macset_free(&set);
	uci_free_context(ctx);
}

static struct json_object * respondd_parker_statistics(void) {
	struct json_object *ret = json_object_new_object();
	struct gatewayinfo gwinfo = {0};

	add_traffic(ret);
	add_clients(ret);

	if (getgatewayandiface(&gwinfo, AF_INET) > 0) {
		return ret;
	}
	if (getgatewayandiface(&gwinfo, AF_INET6) > 0) {
		return ret;
	}
	if (is_mesh_vpn(gwinfo.interface)) {
		json_object_object_add(ret, "gateway", json_object_new_string(gwinfo.gateway4));
		json_object_object_add(ret, "gateway6", json_object_new_string(gwinfo.gateway6));
		json_object_object_add(ret, "gateway_nexthop", json_object_new_string(gwinfo.interface));
	}
	return ret;
}


const struct respondd_provider_info respondd_providers[] = {
	{"statistics", respondd_parker_statistics},
	{}
};
