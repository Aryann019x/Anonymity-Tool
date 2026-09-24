#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/mac.sh - MAC randomization for paranoid mode.
# Uses macchanger if present, else ip link. Stores originals for --restore.
# shellcheck disable=SC1091

mac_save_file() { echo "$VAR_RUN_DIR/mac.save"; }

mac_randomize_all() {
  [[ "$MODE" == "paranoid" ]] || return 0
  local save
  save="$(mac_save_file)"
  : > "$save" 2>/dev/null || true
  chmod 600 "$save" 2>/dev/null || true
  local iface mac
  for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -Ev '^(lo|veth|docker|virbr|tun|wg)'); do
    mac="$(cat "/sys/class/net/$iface/address" 2>/dev/null || echo unknown)"
    echo "$iface $mac" >> "$save" 2>/dev/null || true
    if [[ "$DRY_RUN" == "1" ]]; then echo "would randomize $iface (was $mac)"; continue; fi
    ip link set dev "$iface" down 2>/dev/null || continue
    if have macchanger; then
      macchanger -r "$iface" >/dev/null 2>&1 || ip link set dev "$iface" address "$(random_mac)" 2>/dev/null || true
    else
      ip link set dev "$iface" address "$(random_mac)" 2>/dev/null || true
    fi
    ip link set dev "$iface" up 2>/dev/null || true
    audit_event "mac-randomize" "iface=$iface was=$mac"
  done
}

random_mac() {
  # locally-administered unicast
  printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

mac_restore_all() {
  local save iface old
  save="$(mac_save_file)"
  [[ -f "$save" ]] || return 0
  while read -r iface old; do
    [[ -n "${iface:-}" && -n "${old:-}" ]] || continue
    if [[ "$DRY_RUN" == "1" ]]; then echo "would restore $iface -> $old"; continue; fi
    ip link set dev "$iface" down 2>/dev/null || continue
    ip link set dev "$iface" address "$old" 2>/dev/null || true
    ip link set dev "$iface" up 2>/dev/null || true
  done < "$save"
  rm -f "$save"
  audit_event "mac-restore" "done"
}
