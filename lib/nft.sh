#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/nft.sh - nftables primary backend. fail-closed, state-tracked.
# Rules live in table inet anonyx. --check safe, --apply gated by DRY_RUN.
# shellcheck disable=SC1091

NFT_TABLE="anonyx"

# Generate ruleset to stdout. Pure function for unit tests (nft --check).
# Args: tor_uid, dns_port, tor_port, control_port, trans_port, mode, allow_dhcp, allow_lan, fw_mark
nft_generate() {
  local uid="$1" dns="$2" sport="$3" cport="$4" tport="$5" mode="$6" dhcp="$7" lan="$8" mark="$9"
  cat <<EOF
table inet $NFT_TABLE {
  chain output {
    type filter hook output priority 0; policy drop;
    oifname "lo" accept
    ct state established,related accept
    meta skuid $uid accept
    udp dport 53 ip daddr 127.0.0.1 accept
    tcp dport { $sport, $cport } ip daddr 127.0.0.1 accept
EOF
  if [[ "$dhcp" == "1" ]]; then
    echo "    udp dport { 67, 68 } udp sport { 67, 68 } accept"
  fi
  if [[ "$lan" == "1" ]]; then
    echo "    ip daddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } accept"
  fi
  if [[ "$mode" == "transparent" ]]; then
    echo "    udp dport 53 accept comment \"redirected to DNSPort, see nat\""
    echo "    udp dport != 53 drop comment \"tor cannot carry non-dns udp\""
  fi
  cat <<EOF
  }
  chain input {
    type filter hook input priority 0; policy drop;
    iifname "lo" accept
    ct state established,related accept
EOF
  if [[ "$dhcp" == "1" ]]; then
    echo "    udp sport { 67, 68 } udp dport { 67, 68 } accept"
  fi
  if [[ "$lan" == "1" ]]; then
    echo "    ip saddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } accept"
  fi
  cat <<EOF
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
EOF
  if [[ "$mode" == "transparent" ]]; then
    cat <<EOF
  chain nat-output {
    type nat hook output priority -100;
    meta skuid $uid return
    oifname "lo" return
EOF
    if [[ "$lan" == "1" ]]; then
      echo "    ip daddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } return"
    fi
    cat <<EOF
    udp dport 53 redirect to :$dns
    tcp dport 53 redirect to :$dns
    tcp dport != 9050 redirect to :$tport
  }
EOF
  fi
  echo "}"
  # routing mark for policy routing (host -> tor). mark set via nft, routed via ip rule.
  echo "# fwmark $mark reserved for policy routing when NETNS_ENABLE=1"
}

nft_snapshot() {
  nft list ruleset 2>/dev/null || true
}

nft_apply() {
  local uid dns sport cport tport
  uid="$(tor_uid)"
  [[ -n "$uid" ]] || die "tor uid missing"
  dns="$DNS_PORT"; sport="$TOR_PORT"; cport="$CONTROL_PORT"; tport="$TRANS_PORT"
  local rules tmp
  rules="$(nft_generate "$uid" "$dns" "$sport" "$cport" "$tport" "$MODE" "$ALLOW_DHCP" "$ALLOW_LAN" "$FW_MARK")"
  if [[ "$DRY_RUN" == "1" ]]; then echo "$rules"; return 0; fi
  # snapshot for state.json (hash, not full dump - full dump goes to audit log)
  local before
  before="$(nft_snapshot | sha256sum 2>/dev/null | awk '{print $1}' || echo unknown)"
  tmp="$(mktemp)" || die "mktemp failed"
  printf '%s\n' "$rules" > "$tmp"
  nft --check -f "$tmp" || { rm -f "$tmp"; die "nft --check failed. refusing to apply."; }
  # remove stale table first (idempotent re-run)
  nft delete table inet "$NFT_TABLE" 2>/dev/null || true
  nft -f "$tmp" || { rm -f "$tmp"; die "nft apply failed. system left without anonyx table (filter default still host)."; }
  rm -f "$tmp"
  audit_event "nft-apply" "mode=$MODE backend=nft before=$before"
  printf '%s' "$before"
}

nft_flush() {
  if [[ "$DRY_RUN" == "1" ]]; then echo "would delete table inet $NFT_TABLE"; return 0; fi
  nft delete table inet "$NFT_TABLE" 2>/dev/null || true
  audit_event "nft-flush" "table=$NFT_TABLE"
}

nft_active() {
  nft list table inet "$NFT_TABLE" >/dev/null 2>&1
}
