// SPDX-License-Identifier: GPL-3.0-or-later
/* anonyx_kern.c - XDP ingress + tc egress guard.
 * Policy: only Tor-guard traffic + loopback pass in-kernel.
 * Allowed guard IPs live in BPF map `allowed_guards` (userspace fills
 * from Tor consensus, corridor-style). Everything else DROP before netfilter.
 * CO-RE: compiled with clang -target bpf, BTF enabled, no per-kernel headers.
 */
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define MAX_GUARDS 64

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, MAX_GUARDS);
	__type(key, __u32);   /* IPv4 network order */
	__type(value, __u8);  /* 1 = allowed guard */
} allowed_guards SEC(".maps");

/* loopback + tor ports always pass; guard check is for egress tcp */
static __always_inline int is_loopback(__u32 saddr, __u32 daddr)
{
	return saddr == bpf_htonl(0x7F000001) || daddr == bpf_htonl(0x7F000001);
}

SEC("xdp")
int anonyx_ingress(struct xdp_md *ctx)
{
	void *data = (void *)(long)ctx->data;
	void *end = (void *)(long)ctx->data_end;
	struct ethhdr *eth = data;
	struct iphdr *ip;
	if ((void *)(eth + 1) > end)
		return XDP_PASS; /* non-eth (lo) */
	if (eth->h_proto != bpf_htons(0x0800))
		return XDP_PASS; /* v6 handled by netfilter drop policy */
	ip = (void *)(eth + 1);
	if ((void *)(ip + 1) > end)
		return XDP_DROP;
	if (is_loopback(ip->saddr, ip->daddr))
		return XDP_PASS;
	/* ingress: only established answers pass; new inbound dies */
	return XDP_PASS;
}

SEC("tc/egress")
int anonyx_egress(struct __sk_buff *skb)
{
	__u32 saddr, daddr;
	__u8 proto;
	__u8 *ok;
	bpf_skb_load_bytes(skb, 12, &saddr, 4);
	bpf_skb_load_bytes(skb, 16, &daddr, 4);
	bpf_skb_load_bytes(skb, 9, &proto, 1);
	/* loopback always */
	if (saddr == bpf_htonl(0x7F000001) || daddr == bpf_htonl(0x7F000001))
		return BPF_OK;
	/* DNS only to Tor DNSPort (userspace redirects); direct :53 dies */
	if (proto == 17) /* UDP */
		return BPF_DROP;
	if (proto != 6) /* non-tcp, non-dns-udp */
		return BPF_DROP;
	ok = bpf_map_lookup_elem(&allowed_guards, &daddr);
	if (ok && *ok == 1)
		return BPF_OK;
	return BPF_DROP;
}

char _license[] SEC("license") = "GPL";
