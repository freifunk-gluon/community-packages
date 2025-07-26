#include <stdint.h>
#include <string.h>

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/in.h>
#include <linux/icmp.h>
#include <linux/icmpv6.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/pkt_cls.h>
#include <linux/udp.h>

#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

struct in6_addr CLAT_PREFIX;
struct in6_addr PLAT_PREFIX;

char _license[] SEC("license") = "GPL";

#define IP_OFFSET_MASK (0x1FFF)
#define IP_MF (0x2000)

#define DEBUG_PRINT(x)
//#define DEBUG_PRINT(x) bpf_printk(x)

/* Based on RFC6145. */

SEC("tc")
int clat_downstream(struct __sk_buff *skb)
{
	if (skb->protocol != __bpf_constant_htons(ETH_P_IP)) {
		DEBUG_PRINT("Skipping non-IPv4 packet");
		return TC_ACT_OK;
	}

	struct ethhdr eth;
	if (bpf_skb_load_bytes(skb, 0, &eth, sizeof(eth))) {
		DEBUG_PRINT("Failed to copy eth buffer");
		return TC_ACT_OK;
	}

	struct iphdr ip;
	if (bpf_skb_load_bytes(skb, sizeof(struct ethhdr), &ip, sizeof(ip))) {
		DEBUG_PRINT("Failed to copy ip buffer");
		return TC_ACT_OK;
	}

	if (ip.version != 4) {
		DEBUG_PRINT("Skipping invalid IPv4 packet");
		return TC_ACT_OK;
	}

	uint16_t frag_off = ip.frag_off & __bpf_constant_htons(IP_OFFSET_MASK);
	if ((ip.frag_off & __bpf_constant_htons(IP_MF)) != 0 || frag_off > 0 ) {
		/* TODO: We'll want to support this eventually. Need to check since IPv6 header is bigger though. */
		DEBUG_PRINT("Skipping fragmented IPv4 packet");
		return TC_ACT_OK;
	}

	if (bpf_skb_change_proto(skb, __bpf_constant_htons(ETH_P_IPV6), 0)) {
		DEBUG_PRINT("Failed to convert to IPv6");
		return TC_ACT_OK;
	}

	/* Write IPv6 header. */
	struct ipv6hdr ipv6 = {
		.version = 6,
		.priority = ip.tos >> 4,
		.flow_lbl = {(ip.tos & 0xF) << 4, 0, 0},
		.payload_len = bpf_htons(bpf_ntohs(ip.tot_len) - sizeof(struct iphdr)),
		.nexthdr = ip.protocol,
		.hop_limit = ip.ttl,
	};
	for (int i = 0; i < 3; i++) {
		ipv6.saddr.in6_u.u6_addr32[i] = CLAT_PREFIX.in6_u.u6_addr32[i];
		ipv6.daddr.in6_u.u6_addr32[i] = PLAT_PREFIX.in6_u.u6_addr32[i];
	}
	ipv6.saddr.in6_u.u6_addr32[3] = ip.saddr;
	ipv6.daddr.in6_u.u6_addr32[3] = ip.daddr;

	/* TODO Checksum */

	if (bpf_skb_store_bytes(skb, sizeof(struct ethhdr), &ipv6, sizeof(ipv6), BPF_F_INVALIDATE_HASH | BPF_F_RECOMPUTE_CSUM)) {
		DEBUG_PRINT("Failed to write IPv6 header");
		return TC_ACT_OK;
	}

	eth.h_proto = __bpf_constant_htons(ETH_P_IPV6);
	if (bpf_skb_store_bytes(skb, 0, &eth, sizeof(eth), BPF_F_INVALIDATE_HASH)) {
		DEBUG_PRINT("Failed to write eth header");
		return TC_ACT_OK;
	}

	DEBUG_PRINT("Translated packet");
	return TC_ACT_OK;
}

SEC("tc")
int clat_upstream(struct __sk_buff *skb)
{
	if (skb->protocol != __bpf_constant_htons(ETH_P_IPV6)) {
		DEBUG_PRINT("Skipping non-IPv6 packet");
		return TC_ACT_OK;
	}

	struct ethhdr eth;
	if (bpf_skb_load_bytes(skb, 0, &eth, sizeof(eth))) {
		DEBUG_PRINT("Failed to copy eth buffer");
		return TC_ACT_OK;
	}

	struct ipv6hdr ip6;
	if (bpf_skb_load_bytes(skb, sizeof(struct ethhdr), &ip6, sizeof(ip6))) {
		DEBUG_PRINT("Failed to copy ip6 buffer");
		return TC_ACT_OK;
	}

	if (ip6.version != 6) {
		DEBUG_PRINT("Skipping invalid IPv6 packet");
		return TC_ACT_OK;
	}

	if (ip6.saddr.in6_u.u6_addr32[0] != PLAT_PREFIX.in6_u.u6_addr32[0] ||
	    ip6.saddr.in6_u.u6_addr32[1] != PLAT_PREFIX.in6_u.u6_addr32[1] ||
	    ip6.saddr.in6_u.u6_addr32[2] != PLAT_PREFIX.in6_u.u6_addr32[2]) {
		DEBUG_PRINT("Skipping due to wrong source prefix");
		return TC_ACT_OK;
	}

	if (ip6.daddr.in6_u.u6_addr32[0] != CLAT_PREFIX.in6_u.u6_addr32[0] ||
	    ip6.daddr.in6_u.u6_addr32[1] != CLAT_PREFIX.in6_u.u6_addr32[1] ||
	    ip6.daddr.in6_u.u6_addr32[2] != CLAT_PREFIX.in6_u.u6_addr32[2]) {
		DEBUG_PRINT("Skipping due to wrong destination prefix");
		return TC_ACT_OK;
	}

	switch (ip6.nexthdr) {
		case IPPROTO_FRAGMENT:
			DEBUG_PRINT("Skipping due to fragmentation");
			return TC_ACT_OK;
		case IPPROTO_HOPOPTS:
		case IPPROTO_ROUTING:
		case IPPROTO_DSTOPTS:
		case IPPROTO_MH:
			DEBUG_PRINT("Skipping due to unsupported extension");
			return TC_ACT_OK;
	}

	if (bpf_skb_change_proto(skb, __bpf_constant_htons(ETH_P_IP), 0)) {
		DEBUG_PRINT("Failed to convert to IPv4");
		return TC_ACT_OK;
	}

	/* Write IPv4 header. */
	struct iphdr ip = {
		.version = 4,
		.ihl = sizeof(struct iphdr)>>2,
		.tos = (ip6.priority << 4) | (ip6.flow_lbl[0] >> 4),
		.tot_len = ip6.payload_len + sizeof(struct iphdr),
		.protocol = ip6.nexthdr,
		.ttl = ip6.hop_limit,
		.saddr = ip6.saddr.in6_u.u6_addr32[3],
		.daddr = ip6.daddr.in6_u.u6_addr32[3],
	};

	/* TODO Checksum */

	if (bpf_skb_store_bytes(skb, sizeof(struct ethhdr), &ip, sizeof(ip), BPF_F_INVALIDATE_HASH | BPF_F_RECOMPUTE_CSUM)) {
		DEBUG_PRINT("Failed to write IPv4 header");
		return TC_ACT_OK;
	}

	eth.h_proto = __bpf_constant_htons(ETH_P_IP);
	if (bpf_skb_store_bytes(skb, 0, &eth, sizeof(eth), BPF_F_INVALIDATE_HASH)) {
		DEBUG_PRINT("Failed to write eth header");
		return TC_ACT_OK;
	}

	DEBUG_PRINT("Translated packet");
	return TC_ACT_OK;
}
