// SPDX-License-Identifier: Apache-2.0

#include "clients.h"

#include <linux/neighbour.h>
#include <linux/rtnetlink.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* NDA_CACHEINFO gives the times in clock ticks (USER_HZ = 100). */
#define FDB_MAX_AGE (CLIENT_MAX_INACTIVITY_MS / 10)

#define FDB_BUFFER_SIZE 16384

void macset_add(struct macset *set, const uint8_t *mac) {
	size_t i;

	for (i = 0; i < set->len; i++) {
		if (memcmp(set->mac[i], mac, MAC_LEN) == 0)
			return;
	}

	if (set->len == set->cap) {
		size_t cap = set->cap ? 2 * set->cap : 32;
		void *mem = realloc(set->mac, cap * MAC_LEN);

		if (!mem)
			return;
		set->mac = mem;
		set->cap = cap;
	}

	memcpy(set->mac[set->len++], mac, MAC_LEN);
}

void macset_free(struct macset *set) {
	free(set->mac);
	set->mac = NULL;
	set->len = set->cap = 0;
}

static bool skip_port(const struct fdb_filter *filter, int ifindex) {
	size_t i;

	if (ifindex == filter->bridge)
		return true;
	for (i = 0; i < filter->skip_len; i++) {
		if (filter->skip[i] && filter->skip[i] == ifindex)
			return true;
	}
	return false;
}

bool fdb_client(const struct nlmsghdr *nlh, const struct fdb_filter *filter, uint8_t *mac) {
	const struct ndmsg *ndm = NLMSG_DATA(nlh);
	const struct nda_cacheinfo *ci = NULL;
	const uint8_t *lladdr = NULL;
	const struct rtattr *rta;
	int master = 0;
	int len;

	if (nlh->nlmsg_type != RTM_NEWNEIGH || nlh->nlmsg_len < NLMSG_LENGTH(sizeof(*ndm)))
		return false;
	if (ndm->ndm_family != AF_BRIDGE)
		return false;

	/* Static and local entries (the addresses of the node itself) and the
	 * entries of the devices themselves are no clients. */
	if (ndm->ndm_state & (NUD_PERMANENT | NUD_NOARP))
		return false;
	if (ndm->ndm_flags & NTF_SELF)
		return false;
	if (skip_port(filter, ndm->ndm_ifindex))
		return false;

	len = nlh->nlmsg_len - NLMSG_LENGTH(sizeof(*ndm));
	for (rta = (const struct rtattr *)((const char *)ndm + NLMSG_ALIGN(sizeof(*ndm)));
	     RTA_OK(rta, len); rta = RTA_NEXT(rta, len)) {
		switch (rta->rta_type) {
		case NDA_LLADDR:
			if (RTA_PAYLOAD(rta) == MAC_LEN)
				lladdr = RTA_DATA(rta);
			break;
		case NDA_MASTER:
			if (RTA_PAYLOAD(rta) >= sizeof(uint32_t))
				master = *(const uint32_t *)RTA_DATA(rta);
			break;
		case NDA_CACHEINFO:
			if (RTA_PAYLOAD(rta) >= sizeof(*ci))
				ci = RTA_DATA(rta);
			break;
		default:
			break;
		}
	}

	if (master != filter->bridge || !lladdr || !ci)
		return false;
	/* Group addresses */
	if (lladdr[0] & 1)
		return false;
	if (ci->ndm_updated > FDB_MAX_AGE)
		return false;

	memcpy(mac, lladdr, MAC_LEN);
	return true;
}

int fdb_clients(const struct fdb_filter *filter, struct macset *set) {
	struct {
		struct nlmsghdr nlh;
		struct ndmsg ndm;
	} req = {};
	struct timeval tv = { .tv_sec = 1 };
	char *buffer;
	int sock, error = 0;

	sock = socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE);
	if (sock < 0)
		return 1;

	buffer = malloc(FDB_BUFFER_SIZE);
	if (!buffer) {
		close(sock);
		return 1;
	}

	req.nlh.nlmsg_len = NLMSG_LENGTH(sizeof(req.ndm));
	req.nlh.nlmsg_type = RTM_GETNEIGH;
	req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
	req.nlh.nlmsg_seq = 1;
	req.ndm.ndm_family = AF_BRIDGE;

	setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
	if (send(sock, &req, req.nlh.nlmsg_len, 0) < 0) {
		error = 2;
		goto out;
	}

	for (;;) {
		struct nlmsghdr *nlh;
		uint8_t mac[MAC_LEN];
		int received = recv(sock, buffer, FDB_BUFFER_SIZE, 0);

		if (received <= 0) {
			error = 3;
			goto out;
		}

		for (nlh = (struct nlmsghdr *)buffer; NLMSG_OK(nlh, received); nlh = NLMSG_NEXT(nlh, received)) {
			if (nlh->nlmsg_type == NLMSG_DONE)
				goto out;
			if (nlh->nlmsg_type == NLMSG_ERROR) {
				error = 4;
				goto out;
			}
			if (fdb_client(nlh, filter, mac))
				macset_add(set, mac);
		}
	}

out:
	free(buffer);
	close(sock);
	return error;
}
