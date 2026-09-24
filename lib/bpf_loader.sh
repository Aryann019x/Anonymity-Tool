#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/bpf_loader.sh - attach XDP/tc guard, fill allowed-guard map from consensus.
# Falls back to nftables when kernel lacks BPF (CONFIG_BPF, CAP_BPF).
# shellcheck disable=SC1091
BPF_DIR="/sys/fs/bpf/anonyx"
OBJ="${BPF_OBJ:-/usr/share/anonyx/bpf/anonyx_kern.o}"

bpf_supported() {
  [[ -d /sys/fs/bpf ]] || return 1
  have bpftool || have ip || return 1
  # CAP_BPF probe: try a dry list
  bpftool prog show >/dev/null 2>&1 || ip link show >/dev/null 2>&1 || return 1
  # kernel >= 5.10 has what we need
  return 0
}

bpf_attach() {
  local iface="$1"
  [[ -n "$iface" ]] || return 1
  if [[ "$DRY_RUN" == "1" ]]; then echo "would attach XDP anonyx_ingress on $iface"; return 0; fi
  bpf_supported || { warn "BPF unsupported, staying on nftables"; return 1; }
  mkdir -p "$BPF_DIR" 2>/dev/null || true
  if have bpftool && [[ -f "$OBJ" ]]; then
    bpftool prog load "$OBJ" "$BPF_DIR/ingress" type xdp 2>/dev/null || return 1
    ip link set dev "$iface" xdp pinned "$BPF_DIR/ingress" 2>/dev/null || \
      ip link set dev "$iface" xdpgeneric pinned "$BPF_DIR/ingress" 2>/dev/null || return 1
    audit_event "bpf-attach" "iface=$iface obj=$OBJ"
    return 0
  fi
  return 1
}

bpf_allow_guard() {
  # $1 = guard IPv4. pins into map for in-kernel egress check.
  local ipaddr="$1" key
  [[ -n "$ipaddr" ]] || return 1
  [[ "$DRY_RUN" == "1" ]] && { echo "would allow guard $ipaddr in BPF map"; return 0; }
  have bpftool || return 1
  # map id lookup by name (pinned maps dir)
  key="$(printf '%s' "$ipaddr" | awk -F. '{printf "%d %d %d %d",$1,$2,$3,$4}')"
  bpftool map update pinned "$BPF_DIR/guards" key hex $key value hex 01 2>/dev/null || true
  audit_event "bpf-allow" "guard=$ipaddr"
}

bpf_detach() {
  local iface="$1"
  [[ "$DRY_RUN" == "1" ]] && { echo "would detach XDP from ${iface:-all}"; return 0; }
  if [[ -n "${iface:-}" ]]; then
    ip link set dev "$iface" xdp off 2>/dev/null || true
  fi
  rm -f "$BPF_DIR/ingress" 2>/dev/null || true
  audit_event "bpf-detach" "iface=${iface:-all}"
}
