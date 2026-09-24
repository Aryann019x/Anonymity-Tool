#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/watchdog.sh - fail-closed if Tor dies; gpio panic button if present.
# shellcheck disable=SC1091

watchdog_once() {
  # called by systemd unit and by --enable post-check. blocks net if tor dead.
  if pgrep -x tor >/dev/null 2>&1; then return 0; fi
  warn "tor dead, fail-closed: blocking egress"
  audit_event "watchdog" "tor-dead block"
  if have nft; then
    nft delete table inet anonyx 2>/dev/null || true
    nft add table inet anonyx 2>/dev/null || true
    nft add chain inet anonyx output '{ type filter hook output priority 0; policy drop; }' 2>/dev/null || true
    nft add rule inet anonyx output oifname lo accept 2>/dev/null || true
  else
    iptables -P OUTPUT DROP 2>/dev/null || true
  fi
  return 1
}

watchdog_loop() {
  while true; do
    watchdog_once || true
    gpio_panic_check || true
    sleep 10
  done
}

gpio_panic_check() {
  # hardware button: /sys/class/gpio/gpio17/value == 0 means pressed (wired per docs).
  # requires gpio group: sudo usermod -a -G gpio $USER (then re-login).
  local btn="/sys/class/gpio/gpio17/value"
  [[ -f "$btn" ]] || return 0
  if ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx "gpio" && [[ $EUID -ne 0 ]]; then
    return 0
  fi
  [[ -r "$btn" ]] || return 0
  if [[ "$(cat "$btn" 2>/dev/null)" == "0" ]]; then
    audit_event "panic-button" "gpio17 pressed"
    panic_now
  fi
  return 0
}

panic_now() {
  if have nft; then
    nft delete table inet anonyx 2>/dev/null || true
    nft add table inet anonyx 2>/dev/null || true
    nft add chain inet anonyx input '{ type filter hook input priority 0; policy drop; }' 2>/dev/null || true
    nft add chain inet anonyx output '{ type filter hook output priority 0; policy drop; }' 2>/dev/null || true
    nft add chain inet anonyx forward '{ type filter hook forward priority 0; policy drop; }' 2>/dev/null || true
    nft add rule inet anonyx input iifname lo accept 2>/dev/null || true
    nft add rule inet anonyx output oifname lo accept 2>/dev/null || true
  else
    iptables -F; iptables -X
    iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT DROP
    iptables -A INPUT -i lo -j ACCEPT; iptables -A OUTPUT -o lo -j ACCEPT
  fi
  systemctl stop tor 2>/dev/null || true
  audit_event "panic" "network cut, loopback kept"
}
