#include <linux/types.h>

static int __always_inline update_l3_6to4(struct __sk_buff *skb, __u32 l3_offset, struct iphdr *ip_new, int set_dummy_saddr, __u8 is_inner, __wsum *outer_icmp_csum_diff);
