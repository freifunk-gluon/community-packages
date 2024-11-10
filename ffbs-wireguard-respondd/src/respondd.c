/*
on_ Copyright (c) 2016, Matthias Schiffer <mschiffer@universe-factory.net>
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
       this list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#include <respondd.h>

#include <json-c/json.h>

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <sys/socket.h>
#include <sys/un.h>

#include "wireguard.h"


struct json_object * get_wireguard_handshakes()
{
	char *device_names, *device_name;
	size_t len;
	json_object *json_val;
	json_object *json_device;
	json_object *json_ptr;
	json_object *json_interface;
	json_object *ret = json_object_new_object();

	json_interface = json_object_new_object();
	json_object_object_add(ret, "interfaces", json_interface);

	device_names = wg_list_device_names();

	if (!device_names) {
		perror("Unable to get device names");
		exit(1);
	}

	wg_for_each_device_name(device_names, device_name, len) {
		json_object *json_peers;
		wg_device *device;
		wg_peer *peer;

		if (wg_get_device(&device, device_name) < 0) {
			perror("Unable to get device");
			continue;
		}

		json_device = json_object_new_object();
		json_object_object_add(json_interface, device_name, json_device);

		json_peers = json_object_new_object();
		json_object_object_add(json_device, "peers",
				       json_peers);

		wg_for_each_peer(device, peer) {
			wg_key_b64_string pubkey;
			json_ptr = json_object_new_object();

			int64_t age = (int64_t)time(NULL) - peer->last_handshake_time.tv_sec;
			if (age <= 3600) {
				json_val = json_object_new_int64(time(NULL) - peer->last_handshake_time.tv_sec);
				json_object_object_add(json_ptr, "handshake", json_val);
			}

			/* Yes, these values are uint64_t, we just take the risk
			 * off an overflow here since JSON can only handle
			 * 53-bit integers according to spec anyway
			 */
			json_val = json_object_new_int64(peer->rx_bytes);
			json_object_object_add(json_ptr, "transfer_rx", json_val);
			json_val = json_object_new_int64(peer->tx_bytes);
			json_object_object_add(json_ptr, "transfer_tx", json_val);

			wg_key_to_base64(pubkey, peer->public_key);
			json_object_object_add(json_peers, pubkey, json_ptr);
		}

		wg_free_device(device);
	}
	free(device_names);
	return ret;
}

static struct json_object * respondd_wireguard_handshake(void) {
	struct json_object *ret = get_wireguard_handshakes();
	if (ret)
		return ret;
	return NULL;
}


const struct respondd_provider_info respondd_providers[] = {
	{"wireguard", respondd_wireguard_handshake},
	{}
};
