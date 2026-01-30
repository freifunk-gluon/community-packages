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

/* Prob. requires CONFIG_BPF_EVENTS and CONFIG_TRACING kernel options to be enabled */
#ifdef ENABLE_DEBUG_PRINT
 #define DEBUG_PRINT(x) bpf_printk(x)
#else
 #define DEBUG_PRINT(x)
#endif

/* To make the eBPF validator happy, we need to check that the header is
 * entirely within the valid data region.
 *
 * A note on the return value here:
 * In general, we have two reasonable choices in case of failure - TC_ACT_OK or TC_ACT_SHOT.
 * The former just lets the packet pass, while the latter drops it.
 * In general, TC_ACT_OK is the better choice if something goes wrong before we start mangling
 * the packet, because that way it'll hit the kernel stack as-is and we can easily spot it,
 * deal with it, generate ICMP errors in response etc.
 * However, if something goes wrong partway through, we don't want to pass on some franken-packet,
 * so we just drop it instead.
 * In this case, we're dropping to be safe, since this should only trigger on severely malformed
 * packets (where the data cuts off halfway through a header).
 * Another consideration is that in the egress hook, the packet will go directly into WireGuard,
 * which will drop any IPv4 packets anyways, so we can be more aggressive in dropping there. */
#define ENSURE_MEM_VALID(x)                                                                        \
	if ((void *)((x) + 1) > data_end) {                                                            \
		return TC_ACT_SHOT;                                                                        \
	}

#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))

/* This is intended to run on WireGuard tunnels, which don't have Ethernet
 * headers. */
#define HAS_ETH_HEADER 0

/* Fold given checksum difference down into 16 bit. */
static __always_inline __sum16 csum_fold_helper(__wsum csum) {
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

static int update_tcp_4to6(struct __sk_buff *skb, __u32 offset) {
	if (bpf_l4_csum_replace(skb, offset + offsetof(struct tcphdr, check), 0, l4_pseudo_csum_4to6(),
	                        BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update L4 checksum");
		return TC_ACT_SHOT;
	}
	return TC_ACT_OK;
}

static int update_udp_4to6(struct __sk_buff *skb, __u32 offset) {
	/* Technically we're supposed to drop UDP packets with a checksum of zero here since IPv6
	 * has no checksum of its own, but with WireGuard there's no risk of packet corruption so
	 * we can just let it through and convert back on the other end. */
	if (bpf_l4_csum_replace(skb, offset + offsetof(struct udphdr, check), 0, l4_pseudo_csum_4to6(),
	                        BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update L4 checksum");
		return TC_ACT_SHOT;
	}
	return TC_ACT_OK;
}

static int update_icmp_4to6(struct __sk_buff *skb, __u32 offset, struct ipv6hdr *ip6) {
	if (!ip6) {
		return TC_ACT_SHOT;
	}

	/* The validator is complaining about direct packet access
	 * here for some reason, so use helper functions. */
	struct icmphdr icmp;
	if (bpf_skb_load_bytes(skb, offset, &icmp, sizeof(icmp))) {
		DEBUG_PRINT("Failed to read ICMP header");
		return TC_ACT_SHOT;
	}

	/* TODO: ICMP Extensions. Do we update them or just trim? */

	struct icmp6hdr icmp6 = *((struct icmp6hdr *)&icmp);

	/* Update type/code/data.
	 * TODO: Test all these. */
	switch (icmp.type) {
	case ICMP_ECHO:
		icmp6.icmp6_type = ICMPV6_ECHO_REQUEST;
		break;
	case ICMP_ECHOREPLY:
		icmp6.icmp6_type = ICMPV6_ECHO_REPLY;
		break;
	case ICMP_TIME_EXCEEDED:
		icmp6.icmp6_type = ICMPV6_TIME_EXCEED;
		break;
	case ICMP_PARAMETERPROB:
		if (icmp.code != 0 && icmp.code != 2) {
			DEBUG_PRINT("Invalid code in ICMP parameter problem message");
			return TC_ACT_SHOT;
		}
		icmp6.icmp6_type = ICMPV6_PARAMPROB;
		icmp6.icmp6_code = ICMPV6_HDR_FIELD;
		/* Pointer translation */
		__u8 new_ptr[20] = {
			0, 1, 4, 4, 255, 255, 255, 255, 7, 6, 255, 255, 8, 8, 8, 8, 24, 24, 24, 24,
		};
		__u8 pointer = icmp.un.reserved[0];
		__u32 new_ptr_len = ARRAY_SIZE(new_ptr);
		if (pointer >= new_ptr_len) {
			DEBUG_PRINT("Invalid pointer in ICMP parameter problem message");
			return TC_ACT_SHOT;
		}
		__u8 mapped_ptr = new_ptr[pointer];
		if (mapped_ptr == 255) {
			DEBUG_PRINT("Invalid pointer in ICMP parameter problem message");
			return TC_ACT_SHOT;
		}
		icmp6.icmp6_pointer = bpf_htonl((__u32)mapped_ptr);
		break;
	case ICMP_DEST_UNREACH:
		icmp6.icmp6_type = ICMPV6_DEST_UNREACH;
		switch (icmp.code) {
		case ICMP_NET_UNREACH:
		case ICMP_HOST_UNREACH:
		case ICMP_SR_FAILED:
		case ICMP_NET_UNKNOWN:
		case ICMP_HOST_UNKNOWN:
		case ICMP_HOST_ISOLATED:
		case ICMP_NET_UNR_TOS:
		case ICMP_HOST_UNR_TOS:
			icmp6.icmp6_code = ICMPV6_NOROUTE;
			break;
		case ICMP_PROT_UNREACH:
			icmp6.icmp6_type = ICMPV6_PARAMPROB;
			icmp6.icmp6_code = ICMPV6_UNK_NEXTHDR;
			icmp6.icmp6_pointer = __bpf_constant_htonl(offsetof(struct ipv6hdr, nexthdr));
			break;
		case ICMP_PORT_UNREACH:
			icmp6.icmp6_code = ICMPV6_PORT_UNREACH;
			break;
		case ICMP_FRAG_NEEDED:
			icmp6.icmp6_type = ICMPV6_PKT_TOOBIG;
			icmp6.icmp6_code = 0;
			/* If the downstream (IPv4) link can handle e.g. 1300 bytes, it's fine
			 * for the upstream (IPv6) link to send us up to 1320 bytes since the
			 * conversion will remove 20 bytes from the header. */
			__u32 mtu = bpf_ntohs(icmp.un.frag.mtu);
			mtu += 20;
			if (mtu < 1280) {
				/* Should do pleteau logic for MTU zero in incoming packet, but meh. */
				mtu = 1280;
			}
			icmp6.icmp6_mtu = bpf_htonl(mtu);
			break;
		case ICMP_NET_ANO:
		case ICMP_HOST_ANO:
		case ICMP_PKT_FILTERED:
		case ICMP_PREC_CUTOFF:
			icmp6.icmp6_code = ICMPV6_ADM_PROHIBITED;
			break;
		case ICMP_PREC_VIOLATION:
		default:
			return TC_ACT_SHOT;
		}
		break;
	default:
		return TC_ACT_SHOT;
	}

	/* Update checksum: First, account for the change to the header itself. */
	__wsum csum_diff = bpf_csum_diff((void *)&icmp, sizeof(icmp), (void *)&icmp6, sizeof(icmp6), 0);
	/* Then, add the pseudo-header for ICMPv6. */
	csum_diff = bpf_csum_diff(NULL, 0, ip6->saddr.in6_u.u6_addr32, sizeof(ip6->saddr), csum_diff);
	csum_diff = bpf_csum_diff(NULL, 0, ip6->daddr.in6_u.u6_addr32, sizeof(ip6->daddr), csum_diff);
	__be32 payload_len = bpf_htonl(bpf_ntohs(ip6->payload_len));
	csum_diff = bpf_csum_diff(NULL, 0, &payload_len, sizeof(payload_len), csum_diff);
	__be32 nextheader = __bpf_constant_htonl(IPPROTO_ICMPV6);
	csum_diff = bpf_csum_diff(NULL, 0, &nextheader, sizeof(nextheader), csum_diff);

	/* TODO translate embedded header for errors. */

	/* Update IPv6 next-header to ICMPv6. */
	ip6->nexthdr = IPPROTO_ICMPV6;

	/* Write new header. */
	if (bpf_skb_store_bytes(skb, offset, &icmp6, sizeof(icmp6), 0)) {
		DEBUG_PRINT("Failed to store ICMPv6 header");
		return TC_ACT_SHOT;
	}
	if (bpf_l4_csum_replace(skb, offset + offsetof(struct icmp6hdr, icmp6_cksum), 0, csum_diff,
	                        BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update ICMPv6 checksum");
		return TC_ACT_SHOT;
	}

	DEBUG_PRINT("Translated egress ICMP packet");
	return TC_ACT_OK;
}

static int update_l4_4to6(struct __sk_buff *skb, __u32 offset, struct ipv6hdr *ip6) {
	if (!ip6) {
		return TC_ACT_SHOT;
	}
	switch (ip6->nexthdr) {
	case IPPROTO_TCP:
		return update_tcp_4to6(skb, offset);
	case IPPROTO_UDP:
		return update_udp_4to6(skb, offset);
	case IPPROTO_ICMP:
		return update_icmp_4to6(skb, offset, ip6);
	default:
		DEBUG_PRINT("Egress packet with unknown L4 type");
		return TC_ACT_OK;
	}
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
		.saddr = CLAT_PREFIX,
		.daddr = PLAT_PREFIX,
	};
	ip6_new.saddr.in6_u.u6_addr32[3] = ip->saddr;
	ip6_new.daddr.in6_u.u6_addr32[3] = ip->daddr;

	/* Update L4 checksum. */
	__u32 offset = sizeof(struct iphdr);
#if HAS_ETH_HEADER
	offset += sizeof(struct ethhdr);
#endif
	int ret = update_l4_4to6(skb, offset, &ip6_new);
	if (ret != TC_ACT_OK) {
		return ret;
	}

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

	DEBUG_PRINT("Translated egress packet");
	return TC_ACT_OK;
}

static int update_tcp_6to4(struct __sk_buff *skb, __u32 offset) {
	if (bpf_l4_csum_replace(skb, offset + offsetof(struct tcphdr, check), 0, l4_pseudo_csum_6to4(),
	                        BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update L4 checksum");
		return TC_ACT_SHOT;
	}
	return TC_ACT_OK;
}

static int update_udp_6to4(struct __sk_buff *skb, __u32 offset) {
	/* Technically we're supposed to drop UDP packets with a checksum of zero here since IPv6
	 * has no checksum of its own, but with WireGuard there's no risk of packet corruption so
	 * we can just let it through and convert back on the other end. */
	if (bpf_l4_csum_replace(skb, offset + offsetof(struct udphdr, check), 0, l4_pseudo_csum_6to4(),
	                        BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update L4 checksum");
		return TC_ACT_SHOT;
	}
	return TC_ACT_OK;
}

static int update_icmp_6to4(struct __sk_buff *skb, __u32 offset, struct iphdr *ip, struct ipv6hdr *ip6) {
	if (!ip || !ip6) {
		return TC_ACT_SHOT;
	}

	/* The validator is complaining about direct packet access
	 * here for some reason, so use helper functions. */
	struct icmp6hdr icmp6;
	if (bpf_skb_load_bytes(skb, offset, &icmp6, sizeof(icmp6))) {
		DEBUG_PRINT("Failed to read ICMPv6 header");
		return TC_ACT_SHOT;
	}

	/* TODO: ICMP Extensions. Do we update them or just trim? */

	struct icmphdr icmp = *((struct icmphdr *)&icmp6);

	/* Update type/code/data.
	 * TODO: Test all these. */
	switch (icmp6.icmp6_type) {
	case ICMPV6_ECHO_REQUEST:
		icmp.type = ICMP_ECHO;
		break;
	case ICMPV6_ECHO_REPLY:
		icmp.type = ICMP_ECHOREPLY;
		break;
	case ICMPV6_DEST_UNREACH:
		icmp.type = ICMP_DEST_UNREACH;
		switch (icmp6.icmp6_code) {
		case ICMPV6_NOROUTE:
		case ICMPV6_NOT_NEIGHBOUR:
		case ICMPV6_ADDR_UNREACH:
			icmp.code = ICMP_HOST_UNREACH;
			break;
		case ICMPV6_ADM_PROHIBITED:
			icmp.code = ICMP_HOST_ANO;
			break;
		case ICMPV6_PORT_UNREACH:
			icmp.code = ICMP_PORT_UNREACH;
			break;
		default:
			return TC_ACT_SHOT;
		}
		break;
	case ICMPV6_PKT_TOOBIG:
		icmp.type = ICMP_DEST_UNREACH;
		icmp.code = ICMP_FRAG_NEEDED;
		__u32 mtu = bpf_ntohl(icmp6.icmp6_mtu);
		/* If the upstream (IPv6) link can handle e.g. 1320 bytes, the
		 * downstream (IPv4) link can only send us up to 1300 bytes since
		 * the conversion will add 20 bytes to the header. */
		if (mtu > 20) {
			mtu -= 20;
		}
		icmp.un.frag.mtu = bpf_htons(mtu);
		break;
	case ICMPV6_TIME_EXCEED:
		icmp.type = ICMP_TIME_EXCEEDED;
		break;
	case ICMPV6_PARAMPROB:
		if (icmp6.icmp6_code == 1) {
			icmp.type = ICMPV6_DEST_UNREACH;
			icmp.code = ICMP_PROT_UNREACH;
			break;
		} else if (icmp6.icmp6_code != 0) {
			return TC_ACT_SHOT;
		}
		icmp.type = ICMP_PARAMETERPROB;
		icmp.code = 0;
		/* Pointer translation */
		__u8 new_ptr[40] = {
			0,  1,  255, 255, 2,  2,  9,  8,  12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
			12, 12, 12,  12,  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
		};
		__u32 pointer = bpf_ntohl(icmp6.icmp6_pointer);
		__u32 new_ptr_len = ARRAY_SIZE(new_ptr);
		if (pointer >= new_ptr_len) {
			DEBUG_PRINT("Invalid pointer in ICMPv6 parameter problem message");
			return TC_ACT_SHOT;
		}
		__u8 mapped_ptr = new_ptr[pointer];
		if (mapped_ptr == 255) {
			DEBUG_PRINT("Invalid pointer in ICMPv6 parameter problem message");
			return TC_ACT_SHOT;
		}
		icmp.un.reserved[0] = mapped_ptr;
		break;
	default:
		return TC_ACT_SHOT;
	}

	/* Update checksum: First, account for the change to the header itself. */
	__wsum csum_diff = bpf_csum_diff((void *)&icmp6, sizeof(icmp6), (void *)&icmp, sizeof(icmp), 0);
	/* Then, remove the pseudo-header for ICMPv6. */
	csum_diff = bpf_csum_diff(ip6->saddr.in6_u.u6_addr32, sizeof(ip6->saddr), NULL, 0, csum_diff);
	csum_diff = bpf_csum_diff(ip6->daddr.in6_u.u6_addr32, sizeof(ip6->daddr), NULL, 0, csum_diff);
	__be32 payload_len = bpf_htonl(bpf_ntohs(ip6->payload_len));
	csum_diff = bpf_csum_diff(&payload_len, sizeof(payload_len), NULL, 0, csum_diff);
	__be32 nextheader = __bpf_constant_htonl(IPPROTO_ICMPV6);
	csum_diff = bpf_csum_diff(&nextheader, sizeof(nextheader), NULL, 0, csum_diff);

	/* TODO translate embedded header for errors. */

	/* Update IPv4 next-header to ICMP. */
	ip->protocol = IPPROTO_ICMP;

	/* Write new header. */
	if (bpf_skb_store_bytes(skb, offset, &icmp, sizeof(icmp), 0)) {
		DEBUG_PRINT("Failed to store ICMP header");
		return TC_ACT_SHOT;
	}
	if (bpf_l4_csum_replace(skb, offset + offsetof(struct icmphdr, checksum), 0, csum_diff,
	                        BPF_F_PSEUDO_HDR)) {
		DEBUG_PRINT("Failed to update ICMP checksum");
		return TC_ACT_SHOT;
	}

	DEBUG_PRINT("Translated ingress ICMP packet");
	return TC_ACT_OK;
}

static int update_l4_6to4(struct __sk_buff *skb, __u32 offset, struct iphdr *ip, struct ipv6hdr *ip6) {
	if (!ip) {
		return TC_ACT_SHOT;
	}
	switch (ip->protocol) {
	case IPPROTO_TCP:
		return update_tcp_6to4(skb, offset);
	case IPPROTO_UDP:
		return update_udp_6to4(skb, offset);
	case IPPROTO_ICMPV6:
		return update_icmp_6to4(skb, offset, ip, ip6);
	default:
		DEBUG_PRINT("Ingress packet with unknown L4 type");
		return TC_ACT_OK;
	}
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

	/* Update L4 checksum. */
	__u32 offset = sizeof(struct ipv6hdr);
#if HAS_ETH_HEADER
	offset += sizeof(struct ethhdr);
#endif
	int ret = update_l4_6to4(skb, offset, &ip_new, ip6);
	if (ret != TC_ACT_OK) {
		return ret;
	}

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

	DEBUG_PRINT("Translated ingress packet");
	return TC_ACT_OK;
}
