#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/audit.sh - immutable audit log for all network changes.
# shellcheck disable=SC1091

audit_init() {
  ensure_dirs
  touch "$AUDIT_LOG" 2>/dev/null || true
  chmod 640 "$AUDIT_LOG" 2>/dev/null || true
  # append-only; best effort (needs ext4/xfs + root).
  chattr +a "$AUDIT_LOG" 2>/dev/null || true
}

audit_event() {
  # $1=action $2=detail
  local action="${1:-event}" detail="${2:-}"
  local ts
  ts="$(date -u +%FT%TZ 2>/dev/null || date)"
  printf '%s host=%s action=%s %s\n' "$ts" "$(hostname 2>/dev/null || echo unknown)" "$action" "$detail" >> "$AUDIT_LOG" 2>/dev/null || true
  logger -t anonyx-audit "$action $detail" 2>/dev/null || true
}

audit_rules_snapshot() {
  {
    echo "--- nft ---"
    nft list ruleset 2>/dev/null || echo "nft unavailable"
    echo "--- iptables ---"
    iptables-save 2>/dev/null || echo "iptables-save unavailable"
    echo "--- routes ---"
    ip route show 2>/dev/null || true
    ip rule show 2>/dev/null || true
  } >> "$AUDIT_LOG" 2>/dev/null || true
}
