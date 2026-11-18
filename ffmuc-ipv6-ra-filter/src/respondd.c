#include <respondd.h>

#include <json-c/json.h>
#include <libgluonutil.h>
#include <net/ethernet.h>
#include <stdio.h>

#include <netlink/netlink.h>
#include <netlink/genl/genl.h>
#include <netlink/genl/ctrl.h>
#include <batadv-genl.h>

#include "mac.h"

struct mode_netlink_opts {
	bool is_server;
	struct batadv_nlquery_opts query_opts;
};

static const enum batadv_nl_attrs mode_mandatory[] = {
	BATADV_ATTR_GW_MODE,
};

static int parse_mode_netlink_cb(struct nl_msg *msg, void *arg)
{
	struct nlattr *attrs[BATADV_ATTR_MAX+1];
	struct nlmsghdr *nlh = nlmsg_hdr(msg);
	struct batadv_nlquery_opts *query_opts = arg;
	struct genlmsghdr *ghdr;
	struct mode_netlink_opts *opts;
	uint8_t mode;

	opts = batadv_container_of(query_opts, struct mode_netlink_opts,
				   query_opts);

	if (!genlmsg_valid_hdr(nlh, 0))
		return NL_OK;

	ghdr = nlmsg_data(nlh);

	if (ghdr->cmd != BATADV_CMD_GET_MESH_INFO)
		return NL_OK;

	if (nla_parse(attrs, BATADV_ATTR_MAX, genlmsg_attrdata(ghdr, 0),
	    genlmsg_len(ghdr), batadv_genl_policy))
		return NL_OK;

	if (batadv_genl_missing_attrs(attrs, mode_mandatory,
	    BATADV_ARRAY_SIZE(mode_mandatory)))
		return NL_OK;

	mode = nla_get_u8(attrs[BATADV_ATTR_GW_MODE]);

	opts->is_server = mode == BATADV_GW_MODE_SERVER;

	return NL_OK;
}

static bool is_batman_gateway() {
	struct mode_netlink_opts opts = {
		.is_server = false,
		.query_opts = {
			.err = 0,
		},
	};

	batadv_genl_query("bat0", BATADV_CMD_GET_MESH_INFO,
			  parse_mode_netlink_cb, 0,
			  &opts.query_opts);

	return opts.is_server;
}

static struct json_object * get_ipv6_ra_filter() {
	FILE *f = popen("exec ebtables-tiny -L IPV6_RA_FILTER", "r");
	char *line = NULL;
	size_t len = 0;
	struct ether_addr mac = {};
	struct ether_addr unspec = {};
	char macstr[F_MAC_LEN + 1] = "";

	if (!f)
		return NULL;

	while (getline(&line, &len, f) > 0) {
		if (sscanf(line, "-s " F_MAC " -j ACCEPT\n", F_MAC_VAR_REF(mac)) == ETH_ALEN)
			break;
	}
	free(line);

	pclose(f);

	memset(&unspec, 0, sizeof(unspec));
	if (ether_addr_equal(mac, unspec)) {
		return NULL;
	} else {
		snprintf(macstr, sizeof(macstr), F_MAC, F_MAC_VAR(mac));
		return gluonutil_wrap_string(macstr);
	}
}

static struct json_object * respondd_provider_statistics() {
	struct json_object *ret = json_object_new_object();
	struct json_object *gateway6;

	// We are a batman gateway, do not write gateway6: we do not select a
	// gateway, so the filter chain holds no gateway to report, and the
	// package that made us a gateway describes our uplink itself.
	if (is_batman_gateway())
		return ret;

	// Only report a gateway when we know one. Writing a null would
	// override what another respondd module has to say about gateway6.
	gateway6 = get_ipv6_ra_filter();
	if (gateway6)
		json_object_object_add(ret, "gateway6", gateway6);

	return ret;
}

const struct respondd_provider_info respondd_providers[] = {
	{"statistics", respondd_provider_statistics},
	{}
};
