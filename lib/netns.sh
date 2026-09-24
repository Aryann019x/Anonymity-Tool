#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/netns.sh - optional Tor network-namespace isolation.
# Host routes marked traffic into the namespace over veth; Tor binds inside.
# Disabled by default (NETNS_ENABLE=0). Requires iproute2 + nftables.
# shellcheck disable=SC1091

netns_up() {
  [[ "$NETNS_ENABLE" == "1" ]] || return 0
  local ns="$NETNS_NAME" vhost="veth-host" vtor="veth-tor"
  local host_ip="10.200.0.1/30" tor_ip="10.200.0.2/30"
  if [[ "$DRY_RUN" == "1" ]]; then echo "would create netns $ns with veth $vhost<->$vtor and fwmark $FW_MARK"; return 0; fi
  have ip || die "iproute2 missing for netns mode"
  ip netns list 2>/dev/null | grep -qw "$ns" || ip netns add "$ns"
  ip link show "$vhost" >/dev/null 2>&1 || {
    ip link add "$vhost" type veth peer name "$vtor"
    ip link set "$vtor" netns "$ns"
    ip addr add "$host_ip" dev "$vhost"
    ip link set "$vhost" up
    ip netns exec "$ns" ip addr add "$tor_ip" dev "$vtor"
    ip netns exec "$ns" ip link set "$vtor" up
    ip netns exec "$ns" ip link set lo up
    ip netns exec "$ns" ip route add default via 10.200.0.1
  }
  # policy routing: marked packets go via veth to the namespace.
  ip rule show | grep -q "fwmark $FW_MARK" || ip rule add fwmark "$FW_MARK" table 100
  ip route show table 100 2>/dev/null | grep -q "10.200.0.0/30" || ip route add 10.200.0.0/30 dev "$vhost" table 100
  audit_event "netns-up" "ns=$ns mark=$FW_MARK"
}

netns_down() {
  [[ "$NETNS_ENABLE" == "1" ]] || return 0
  local ns="$NETNS_NAME"
  if [[ "$DRY_RUN" == "1" ]]; then echo "would delete netns $ns and fwmark rule $FW_MARK"; return 0; fi
  ip rule del fwmark "$FW_MARK" table 100 2>/dev/null || true
  ip link del veth-host 2>/dev/null || true
  ip netns del "$ns" 2>/dev/null || true
  audit_event "netns-down" "ns=$ns"
}

netns_exec_tor() {
  # run tor inside the namespace when enabled; else normal restart is handled elsewhere.
  [[ "$NETNS_ENABLE" == "1" ]] || return 1
  ip netns exec "$NETNS_NAME" runuser -u debian-tor -- tor -f "$TOR_CONF" 2>/dev/null &
  return 0
}
