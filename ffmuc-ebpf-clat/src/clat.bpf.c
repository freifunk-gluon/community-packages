#include <stdint.h>
#include <string.h>

#include <linux/bpf.h>
#include <linux/icmp.h>
#include <linux/icmpv6.h>
#include <linux/if_ether.h>
#include <linux/in.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/pkt_cls.h>
#include <linux/tcp.h>
#include <linux/udp.h>

#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

/* This implements the CLAT component for 464XLAT, based on RFC6145. */

struct in6_addr CLAT_PREFIX;
struct in6_addr PLAT_PREFIX;

char _license[] SEC("license") = "GPL";

#define IP_OFFSET_MASK (0x1FFF)
#define IP_MF (0x2000)

// #define DEBUG_PRINT(x)
#define DEBUG_PRINT(x) bpf_printk(x)

/* To make the eBPF validator happy, we need to check that the header is
 * entirely within the valid data region.*/
#define ENSURE_MEM_VALID(x)                                                                        \
	if ((void *)((x) + 1) > data_end) {                                                            \
		return TC_ACT_SHOT;                                                                        \
	}

/* This is intended to run on WireGuard tunnels, which don't have Ethernet
 * headers. */
#define HAS_ETH_HEADER 0

/* Fold given checksum difference down into 16 bit. */
static __always_inline __u16 csum_fold_helper(__wsum csum) {
	__wsum sum = (csum >> 16) + (csum & 0xffff);
	return ~(sum + (sum >> 16));
}

/* To update the L4 checksum, we need to compute the difference to the pseudo-header.
 * The only difference between v4 and v6 here is the addresses, and since we assume /96 prefixes,
 * this means that we just keep the v4 bytes as-is and add 12 new bytes for each address.
 * TODO: Precompute this on the host application and pass it in! */
static __always_inline __wsum l4_pseudo_csum_4to6() {
	__wsum csum_diff = bpf_csum_diff(NULL, 0, CLAT_PREFIX.in6_u.u6_addr32, 12, 0);
	return bpf_csum_diff(NULL, 0, PLAT_PREFIX.in6_u.u6_addr32, 12, csum_diff);
}
static __always_inline __wsum l4_pseudo_csum_6to4() {
	__wsum csum_diff = bpf_csum_diff(CLAT_PREFIX.in6_u.u6_addr32, 12, NULL, 0, 0);
	return bpf_csum_diff(PLAT_PREFIX.in6_u.u6_addr32, 12, NULL, 0, csum_diff);
}

SEC("tc")
int clat_egress_4to6(struct __sk_buff *skb) {
	if (skb->protocol != __bpf_constant_htons(ETH_P_IP)) {
		DEBUG_PRINT("Skipping non-IPv4 packet");
		return TC_ACT_OK;
	}

	void *data_end = (void *)(__u64)skb->data_end;
	void *data = (void *)(__u64)skb->data;
#if HAS_ETH_HEADER
	struct ethhdr *eth = data;
	ENSURE_MEM_VALID(eth);

	struct iphdr *ip = (struct iphdr *)(eth + 1);
#else
	struct iphdr *ip = data;
#endif
	ENSURE_MEM_VALID(ip);

	if (ip->version != 4) {
		DEBUG_PRINT("Dropping invalid IPv4 packet");
		return TC_ACT_SHOT;
	}

	/* TODO: Handle ICMP. */
	if (ip->protocol != IPPROTO_TCP && ip->protocol != IPPROTO_UDP) {
		DEBUG_PRINT("Dropping non-TCP/UDP packet");
		return TC_ACT_SHOT;
	}

	uint16_t frag_off = ip->frag_off & __bpf_constant_htons(IP_OFFSET_MASK);
	if ((ip->frag_off & __bpf_constant_htons(IP_MF)) != 0 || frag_off > 0) {
		/* TODO: We'll want to support this eventually.
		 * Need to check since IPv6 header is bigger though. */
		DEBUG_PRINT("Dropping fragmented IPv4 packet");
		return TC_ACT_SHOT;
	}

	/* Build IPv6 header. */
	struct ipv6hdr ip6_new = {
		.version = 6,
		.priority = ip->tos >> 4,
		.flow_lbl = {(ip->tos & 0xF) << 4, 0, 0},
		.payload_len = bpf_htons(bpf_ntohs(ip->tot_len) - sizeof(struct iphdr)),
		.nexthdr = ip->protocol,
		.hop_limit = ip->ttl,
	};
	for (int i = 0; i < 3; i++) {
		ip6_new.saddr.in6_u.u6_addr32[i] = CLAT_PREFIX.in6_u.u6_addr32[i];
		ip6_new.daddr.in6_u.u6_addr32[i] = PLAT_PREFIX.in6_u.u6_addr32[i];
	}
	ip6_new.saddr.in6_u.u6_addr32[3] = ip->saddr;
	ip6_new.daddr.in6_u.u6_addr32[3] = ip->daddr;

	/* Change SKB protocol. */
	if (bpf_skb_change_proto(skb, __bpf_constant_htons(ETH_P_IPV6), 0)) {
		DEBUG_PRINT("Failed to convert to IPv6");
		return TC_ACT_SHOT;
	}

	/* Update pointers after protocol change invalidated them. */
	data_end = (void *)(__u64)skb->data_end;
	data = (void *)(__u64)skb->data;
#if HAS_ETH_HEADER
	eth = data;
	ENSURE_MEM_VALID(eth);

	/* Update ethernet proto. */
	eth->h_proto = __bpf_constant_htons(ETH_P_IPV6);

	struct ipv6hdr *ip6 = (struct ipv6hdr *)(eth + 1);
#else
	struct ipv6hdr *ip6 = (struct ipv6hdr *)data;
#endif

	/* Write IPv6 header. */
	ENSURE_MEM_VALID(ip6);
	*ip6 = ip6_new;

	/* Update L4 checksum. */
	__u32 offset = sizeof(struct ipv6hdr);
#if HAS_ETH_HEADER
	offset += sizeof(struct ethhdr);
#endif
	switch (ip6_new.nexthdr) {
	case IPPROTO_TCP:
		offset += offsetof(struct tcphdr, check);
		break;
	case IPPROTO_UDP:
		offset += offsetof(struct udphdr, check);
		break;
	default:
		DEBUG_PRINT("Failed to determine L4 checksum offset");
		return TC_ACT_SHOT;
	}

	if (bpf_l4_csum_replace(skb, offset, 0, l4_pseudo_csum_4to6(), BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update L4 checksum");
		return TC_ACT_SHOT;
	}

	DEBUG_PRINT("Translated egress packet");
	return TC_ACT_OK;
}

SEC("tc")
int clat_ingress_6to4(struct __sk_buff *skb) {
	if (skb->protocol != __bpf_constant_htons(ETH_P_IPV6)) {
		DEBUG_PRINT("Skipping non-IPv6 packet");
		return TC_ACT_OK;
	}

	void *data_end = (void *)(__u64)skb->data_end;
	void *data = (void *)(__u64)skb->data;
#if HAS_ETH_HEADER
	struct ethhdr *eth = data;
	ENSURE_MEM_VALID(eth);

	struct ipv6hdr *ip6 = (struct ipv6hdr *)(eth + 1);
#else
	struct ipv6hdr *ip6 = data;
#endif
	ENSURE_MEM_VALID(ip6);

	if (ip6->version != 6) {
		DEBUG_PRINT("Skipping invalid IPv6 packet");
		return TC_ACT_OK;
	}

	if (ip6->saddr.in6_u.u6_addr32[0] != PLAT_PREFIX.in6_u.u6_addr32[0] ||
	    ip6->saddr.in6_u.u6_addr32[1] != PLAT_PREFIX.in6_u.u6_addr32[1] ||
	    ip6->saddr.in6_u.u6_addr32[2] != PLAT_PREFIX.in6_u.u6_addr32[2]) {
		DEBUG_PRINT("Skipping due to wrong source prefix");
		return TC_ACT_OK;
	}

	if (ip6->daddr.in6_u.u6_addr32[0] != CLAT_PREFIX.in6_u.u6_addr32[0] ||
	    ip6->daddr.in6_u.u6_addr32[1] != CLAT_PREFIX.in6_u.u6_addr32[1] ||
	    ip6->daddr.in6_u.u6_addr32[2] != CLAT_PREFIX.in6_u.u6_addr32[2]) {
		DEBUG_PRINT("Skipping due to wrong destination prefix");
		return TC_ACT_OK;
	}

	switch (ip6->nexthdr) {
	case IPPROTO_FRAGMENT:
		DEBUG_PRINT("Dropping due to fragmentation");
		return TC_ACT_SHOT;
	case IPPROTO_HOPOPTS:
	case IPPROTO_ROUTING:
	case IPPROTO_DSTOPTS:
	case IPPROTO_MH:
		DEBUG_PRINT("Dropping due to unsupported extension");
		return TC_ACT_SHOT;
	case IPPROTO_TCP:
	case IPPROTO_UDP:
		break;
	/* TODO: Handle ICMP. */
	default:
		DEBUG_PRINT("Dropping non-TCP/UDP packet");
		return TC_ACT_SHOT;
	}

	/* Build IPv4 header. */
	struct iphdr ip_new = {
		.version = 4,
		.ihl = sizeof(struct iphdr) >> 2,
		.tos = (ip6->priority << 4) | (ip6->flow_lbl[0] >> 4),
		.tot_len = bpf_htons(bpf_ntohs(ip6->payload_len) + sizeof(struct iphdr)),
		.check = 0,
		.protocol = ip6->nexthdr,
		.ttl = ip6->hop_limit,
		.saddr = ip6->saddr.in6_u.u6_addr32[3],
		.daddr = ip6->daddr.in6_u.u6_addr32[3],
	};

	/* Compute L3 header checksum. */
	ip_new.check =
		csum_fold_helper(bpf_csum_diff(NULL, 0, (void *)&ip_new, sizeof(struct iphdr), 0));

	/* Change SKB protocol. */
	if (bpf_skb_change_proto(skb, __bpf_constant_htons(ETH_P_IP), 0)) {
		DEBUG_PRINT("Failed to convert to IPv4");
		return TC_ACT_SHOT;
	}

	/* Update pointers after protocol change invalidated them. */
	data_end = (void *)(__u64)skb->data_end;
	data = (void *)(__u64)skb->data;
#if HAS_ETH_HEADER
	eth = data;
	ENSURE_MEM_VALID(eth);

	/* Update ethernet proto. */
	eth->h_proto = __bpf_constant_htons(ETH_P_IP);

	struct iphdr *ip = (struct iphdr *)(eth + 1);
#else
	struct iphdr *ip = (struct iphdr *)data;
#endif

	/* Write IPv4 header. */
	ENSURE_MEM_VALID(ip);
	*ip = ip_new;

	/* Update L4 checksum. */
	__u32 offset = sizeof(struct iphdr);
#if HAS_ETH_HEADER
	offset += sizeof(struct ethhdr);
#endif
	switch (ip_new.protocol) {
	case IPPROTO_TCP:
		offset += offsetof(struct tcphdr, check);
		break;
	case IPPROTO_UDP:
		offset += offsetof(struct udphdr, check);
		break;
	default:
		DEBUG_PRINT("Failed to determine L4 checksum offset");
		return TC_ACT_SHOT;
	}
	if (bpf_l4_csum_replace(skb, offset, 0, l4_pseudo_csum_6to4(), BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update L4 checksum");
		return TC_ACT_SHOT;
	}

	DEBUG_PRINT("Translated ingress packet");
	return TC_ACT_OK;
}
