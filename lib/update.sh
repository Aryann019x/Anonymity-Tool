#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/update.sh - secure update helpers: --revoke emergency disable.
# shellcheck disable=SC1091
update_revoke() {
  # Revoked release or compromised key: kill everything, refuse to re-enable
  # until admin clears the flag. No network needed.
  need_root
  audit_init 2>/dev/null || true
  audit_event "revoke" "emergency disable by admin" 2>/dev/null || true
  dns_restore 2>/dev/null || true
  fw_remove 2>/dev/null || true
  mac_restore_all 2>/dev/null || true
  mkdir -p "$VAR_RUN_DIR" 2>/dev/null || true
  date -u +%FT%TZ > "$VAR_RUN_DIR/revoked" 2>/dev/null || true
  chmod 600 "$VAR_RUN_DIR/revoked" 2>/dev/null || true
  state_clear 2>/dev/null || true
  tor_restart 2>/dev/null || true
  echo "[-] anonyx revoked. re-enable blocked until $VAR_RUN_DIR/revoked is removed."
}

update_revoked() { [[ -f "$VAR_RUN_DIR/revoked" ]]; }
