#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/ramonly.sh - Tails-style no-disk-artifacts mode (--ram-only).
# shellcheck disable=SC1091
ramonly_on() {
  [[ "${RAM_ONLY:-0}" == "1" ]] || return 0
  local free_kb
  free_kb="$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  if [[ "$free_kb" -lt 2000000 ]]; then
    warn "low RAM (${free_kb}kB < 2GB). ram-only may OOM. continuing anyway."
  fi
  if [[ "$DRY_RUN" == "1" ]]; then echo "would mount tmpfs over $VAR_LOG_DIR $ETC_DIR"; return 0; fi
  mount -t tmpfs -o size=64M,mode=750 tmpfs "$VAR_LOG_DIR" 2>/dev/null || warn "tmpfs log mount failed"
  mount -t tmpfs -o size=16M,mode=700 tmpfs "$ETC_DIR" 2>/dev/null || warn "tmpfs etc mount failed"
  audit_event "ram-only-on" "tmpfs mounted"
}

ramonly_off() {
  mountpoint -q "$VAR_LOG_DIR" 2>/dev/null || mountpoint -q "$ETC_DIR" 2>/dev/null || return 0
  if [[ "$DRY_RUN" == "1" ]]; then echo "would shred + unmount tmpfs"; return 0; fi
  find "$VAR_LOG_DIR" "$ETC_DIR" -type f -exec shred -u -z {} \; 2>/dev/null || true
  umount "$VAR_LOG_DIR" 2>/dev/null || true
  umount "$ETC_DIR" 2>/dev/null || true
  audit_event "ram-only-off" "shredded + unmounted"
}
