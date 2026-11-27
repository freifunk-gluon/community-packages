// SPDX-License-Identifier: Apache-2.0
/* Test of the FDB filter of the client count. Run with tests/run.sh. */

#include "clients.h"

#include <linux/neighbour.h>
#include <linux/rtnetlink.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>

enum { BR = 10, ETH0 = 2, BAT0 = 3, LOCAL_PORT = 4, CLIENT0 = 5, OTHER_BR = 20 };

static const struct fdb_filter filter = {
	.bridge = BR,
	.skip = { BAT0, LOCAL_PORT },
	.skip_len = 2,
};

struct entry {
	int ifindex, master;
	uint16_t state;
	uint8_t flags;
	uint8_t mac[MAC_LEN];
	int updated; /* < 0: no NDA_CACHEINFO */
};

static void put_attr(struct nlmsghdr *nlh, int type, const void *data, int len) {
	struct rtattr *rta = (struct rtattr *)((char *)nlh + NLMSG_ALIGN(nlh->nlmsg_len));

	rta->rta_type = type;
	rta->rta_len = RTA_LENGTH(len);
	memcpy(RTA_DATA(rta), data, len);
	nlh->nlmsg_len = NLMSG_ALIGN(nlh->nlmsg_len) + RTA_ALIGN(rta->rta_len);
}

static bool check(const struct entry *e, uint8_t *mac) {
	char buf[512] __attribute__((aligned(4))) = {};
	struct nlmsghdr *nlh = (struct nlmsghdr *)buf;
	struct ndmsg *ndm = NLMSG_DATA(nlh);

	nlh->nlmsg_type = RTM_NEWNEIGH;
	nlh->nlmsg_len = NLMSG_LENGTH(sizeof(*ndm));
	ndm->ndm_family = AF_BRIDGE;
	ndm->ndm_ifindex = e->ifindex;
	ndm->ndm_state = e->state;
	ndm->ndm_flags = e->flags;
	put_attr(nlh, NDA_LLADDR, e->mac, MAC_LEN);
	if (e->master) {
		uint32_t m = e->master;
		put_attr(nlh, NDA_MASTER, &m, sizeof(m));
	}
	if (e->updated >= 0) {
		struct nda_cacheinfo ci = { .ndm_updated = e->updated };
		put_attr(nlh, NDA_CACHEINFO, &ci, sizeof(ci));
	}
	return fdb_client(nlh, &filter, mac);
}

#define A { 0x02, 0, 0, 0, 0, 0x0a }
#define B { 0x02, 0, 0, 0, 0, 0x0b }

static const struct {
	const char *name;
	struct entry e;
	bool counts;
} cases[] = {
	{ "learned on LAN port", { ETH0, BR, NUD_REACHABLE, 0, A, 100 }, true },
	{ "learned on Wi-Fi AP", { CLIENT0, BR, NUD_REACHABLE, 0, B, 0 }, true },
	{ "age 60 s", { ETH0, BR, NUD_REACHABLE, 0, A, 6000 }, true },
	{ "age 60.01 s", { ETH0, BR, NUD_REACHABLE, 0, A, 6001 }, false },
	{ "client of other node (bat0)", { BAT0, BR, NUD_REACHABLE, 0, A, 0 }, false },
	{ "local-port", { LOCAL_PORT, BR, NUD_REACHABLE, 0, A, 0 }, false },
	{ "entry of bridge itself", { BR, BR, NUD_REACHABLE, 0, A, 0 }, false },
	{ "local address of node", { ETH0, BR, NUD_PERMANENT, 0, A, 0 }, false },
	{ "static entry", { ETH0, BR, NUD_NOARP, 0, A, 0 }, false },
	{ "self entry of port", { ETH0, 0, NUD_PERMANENT, NTF_SELF, A, -1 }, false },
	{ "self flag", { ETH0, BR, NUD_REACHABLE, NTF_SELF, A, 0 }, false },
	{ "other bridge", { ETH0, OTHER_BR, NUD_REACHABLE, 0, A, 0 }, false },
	{ "no master", { ETH0, 0, NUD_REACHABLE, 0, A, 0 }, false },
	{ "multicast MAC", { ETH0, BR, NUD_REACHABLE, 0, { 0x33, 0x33, 0, 0, 0, 1 }, 0 }, false },
	{ "no cacheinfo", { ETH0, BR, NUD_REACHABLE, 0, A, -1 }, false },
};

int main(void) {
	static const uint8_t a[MAC_LEN] = A, b[MAC_LEN] = B;
	const size_t n = sizeof(cases) / sizeof(cases[0]);
	struct macset set = {};
	uint8_t mac[MAC_LEN];
	int fail = 0;
	size_t i;

	for (i = 0; i < n; i++) {
		bool got = check(&cases[i].e, mac);

		if (got != cases[i].counts) {
			printf("FAIL %s: got %d\n", cases[i].name, got);
			fail++;
		} else if (got && memcmp(mac, cases[i].e.mac, MAC_LEN)) {
			printf("FAIL %s: wrong MAC\n", cases[i].name);
			fail++;
		}
	}

	/* A Wi-Fi client is in the FDB and in the station list. VLAN entries
	 * give the same MAC more than once. */
	macset_add(&set, a);
	macset_add(&set, b);
	macset_add(&set, a);
	macset_add(&set, b);
	for (i = 0; i < 100; i++) {
		uint8_t m[MAC_LEN] = { 0x02, 1, 0, 0, 0, (uint8_t)i };
		macset_add(&set, m);
		macset_add(&set, m);
	}
	if (set.len != 102) {
		printf("FAIL macset: %zu MACs, expected 102\n", set.len);
		fail++;
	}
	macset_free(&set);

	printf("%s: %zu FDB cases, macset, %d failed\n", fail ? "FAIL" : "PASS", n, fail);
	return fail != 0;
}
