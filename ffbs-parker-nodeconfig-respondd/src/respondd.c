/*
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/

#include <respondd.h>

#include <json-c/json.h>

#include <sys/socket.h>
#include <sys/types.h>
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


static struct json_object * respondd_parker_gateway(void) {
    struct json_object *ret = json_object_new_object();
    struct gatewayinfo gwinfo = {0};
    if (getgatewayandiface(&gwinfo, AF_INET) > 0) {
        return ret;
    }
    if (getgatewayandiface(&gwinfo, AF_INET6) > 0) {
        return ret;
    }
    if (strncmp(gwinfo.interface, "wg_", 3) == 0) {
        json_object_object_add(ret, "gateway", json_object_new_string(gwinfo.gateway4));
        json_object_object_add(ret, "gateway6", json_object_new_string(gwinfo.gateway6));
        json_object_object_add(ret, "gateway_nexthop", json_object_new_string(gwinfo.interface));
    }
    return ret;
}


const struct respondd_provider_info respondd_providers[] = {
    {"statistics", respondd_parker_gateway},
    {}
};
