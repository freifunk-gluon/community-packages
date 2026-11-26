// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <linux/netlink.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define MAC_LEN 6

/* The same limit as Gluon: a client counts when it was active in the last
 * 60 seconds. */
#define CLIENT_MAX_INACTIVITY_MS 60000

struct macset {
	uint8_t (*mac)[MAC_LEN];
	size_t len, cap;
};

/* The bridge and the ports of the bridge that do not connect clients. */
struct fdb_filter {
	int bridge;
	int skip[4];
	size_t skip_len;
};

void macset_add(struct macset *set, const uint8_t *mac);
void macset_free(struct macset *set);

/* Return true and copy the MAC when the RTM_NEWNEIGH message is a learned
 * entry of a local client in the FDB of the bridge. */
bool fdb_client(const struct nlmsghdr *nlh, const struct fdb_filter *filter, uint8_t *mac);

/* Add the MACs of the local clients in the FDB of the bridge. */
int fdb_clients(const struct fdb_filter *filter, struct macset *set);
