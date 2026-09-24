#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/iptables_compat.sh - fallback for older systems without nft.
# Same policy as nft backend: tor uid + lo only, no 80/443 fallback, no clearnet DNS.
# shellcheck disable=SC1091

IPT_STATE_FILE="${IPT_STATE_FILE:-$VAR_RUN_DIR/iptables.save}"

ipt_snapshot_save() {
  mkdir -p "$VAR_RUN_DIR" 2>/dev/null || true
  [[ -f "$IPT_STATE_FILE" ]] || iptables-save > "$IPT_STATE_FILE" 2>/dev/null || true
}

ipt_apply() {
  local uid
  uid="$(tor_uid)"
  [[ -n "$uid" ]] || die "tor uid missing"
  if [[ "$DRY_RUN" == "1" ]]; then echo "would apply iptables tor-uid-only ruleset"; return 0; fi
  ipt_snapshot_save
  iptables -F; iptables -X
  iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT DROP
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -m owner --uid-owner "$uid" -j ACCEPT
  iptables -A OUTPUT -d 127.0.0.1 -p udp --dport "$DNS_PORT" -j ACCEPT
  iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport "$TOR_PORT" -j ACCEPT
  iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport "$CONTROL_PORT" -j ACCEPT
  if [[ "$ALLOW_DHCP" == "1" ]]; then
    iptables -A OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
    iptables -A INPUT -p udp --sport 67:68 --dport 67:68 -j ACCEPT
  fi
  if [[ "$ALLOW_LAN" == "1" ]]; then
    for net in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do
      iptables -A INPUT -s "$net" -j ACCEPT
      iptables -A OUTPUT -d "$net" -j ACCEPT
    done
  fi
  if [[ "$MODE" == "transparent" ]]; then
    iptables -t nat -F
    iptables -t nat -A OUTPUT -m owner --uid-owner "$uid" -j RETURN
    iptables -t nat -A OUTPUT -o lo -j RETURN
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports "$TRANS_PORT"
    iptables -A OUTPUT -p udp --dport 53 -d 127.0.0.1 -j ACCEPT
    iptables -A OUTPUT -p udp -j DROP
  fi
  audit_event "iptables-apply" "mode=$MODE"
}

ipt_restore() {
  if [[ -f "$IPT_STATE_FILE" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then echo "would iptables-restore $IPT_STATE_FILE"; return 0; fi
    iptables-restore < "$IPT_STATE_FILE" 2>/dev/null || {
      warn "iptables-restore failed, opening filter (logged)"
      iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
      iptables -F; iptables -X; iptables -t nat -F 2>/dev/null || true
    }
    rm -f "$IPT_STATE_FILE"
  else
    [[ "$DRY_RUN" == "1" ]] || {
      iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
      iptables -F; iptables -X; iptables -t nat -F 2>/dev/null || true
    }
  fi
  audit_event "iptables-restore" "done"
}

ipt_active() {
  iptables -L OUTPUT -n 2>/dev/null | grep -q "DROP\|REJECT"
}
