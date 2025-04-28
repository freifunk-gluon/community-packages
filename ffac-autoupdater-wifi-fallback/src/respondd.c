// SPDX-License-Identifier: BSD-2-Clause
// SPDX-FileCopyrightText: 2016 Matthias Schiffer <mschiffer@universe-factory.net>
// SPDX-FileCopyrightText: 2016 Karsten Böddeker <freifunk@kb-light.de>


#include <respondd.h>

#include <json-c/json.h>

#include <uci.h>

#include <string.h>


static struct json_object * get_autoupdater_wifi_fallback(void) {
	struct uci_context *ctx = uci_alloc_context();
	ctx->flags &= ~UCI_FLAG_STRICT;

	struct uci_package *p;
	if (uci_load(ctx, "autoupdater-wifi-fallback", &p))
		goto error;

	struct uci_section *s = uci_lookup_section(ctx, p, "settings");
	if (!s)
		goto error;

	struct json_object *ret = json_object_new_object();

	const char *enabled = uci_lookup_option_string(ctx, s, "enabled");
	json_object_object_add(ret, "wifi-fallback", json_object_new_boolean(enabled && !strcmp(enabled, "1")));

	uci_free_context(ctx);

	return ret;

 error:
	uci_free_context(ctx);
	return NULL;
}

static struct json_object * respondd_provider_nodeinfo(void) {
	struct json_object *ret = json_object_new_object();

	struct json_object *software = json_object_new_object();
	json_object_object_add(software, "autoupdater", get_autoupdater_wifi_fallback());
	json_object_object_add(ret, "software", software);

	return ret;
}


const struct respondd_provider_info respondd_providers[] = {
	{"nodeinfo", respondd_provider_nodeinfo},
	{}
};
