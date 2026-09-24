#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/preflight.sh - fail-closed checks before touching the firewall.
# shellcheck disable=SC1091

is_systemd() { have systemctl && [[ -d /run/systemd/system ]]; }

distro_id() { grep -E '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo unknown; }

tor_uid() {
  id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || id -u _tor 2>/dev/null || echo ""
}

in_container() {
  [[ -f /.dockerenv ]] && return 0
  [[ -f /run/.containerenv ]] && return 0
  have systemd-detect-virt && systemd-detect-virt --container >/dev/null 2>&1 && return 0
  grep -qa "docker\|lxc\|kubepods" /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

fw_other_active() {
  local out=""
  have ufw && ufw status 2>/dev/null | grep -q "Status: active" && out="${out}ufw "
  have firewall-cmd && firewall-cmd --state 2>/dev/null | grep -q running && out="${out}firewalld "
  echo "${out:-none}"
}

check_kernel_nft() {
  have nft || { warn "nft missing (need nftables pkg for primary backend)"; return 1; }
  nft list ruleset >/dev/null 2>&1 || { warn "cannot read nft ruleset (need NET_ADMIN)"; return 1; }
  return 0
}

check_caps() {
  have capsh && capsh --print 2>/dev/null | grep -q "cap_net_admin" && return 0
  # fallback: try a no-op nft check
  nft --check -f /dev/null >/dev/null 2>&1 && return 0
  iptables -L OUTPUT -n >/dev/null 2>&1 && return 0
  return 1
}

check_clock() {
  # tor fails with skewed clock; warn, do not auto-fix (admin owns NTP).
  local offset="unknown"
  if have timedatectl; then
    timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes && { echo "clock: NTP synchronized"; return 0; }
  fi
  if have chronyc; then
    offset="$(chronyc tracking 2>/dev/null | awk '/System time/ {print $4, $5}' || echo unknown)"
    echo "clock: chrony offset $offset"
    return 0
  fi
  warn "clock: cannot confirm NTP sync (install chrony/systemd-timesyncd). tor needs <30min skew."
  return 0
}

validate_torrc() {
  local f="${1:-$TOR_CONF}"
  [[ -f "$f" ]] || return 0
  # dangerous settings that punch holes in the killswitch model.
  if grep -Eq '^[[:space:]]*(SocksPort|TransPort|DNSPort)[[:space:]]+0\.0\.0\.0' "$f"; then
    die "torrc binds 0.0.0.0 (LAN-wide tor). refusing."
  fi
  if grep -Eq '^[[:space:]]*ExitPolicy[[:space:]]+accept' "$f"; then
    die "torrc looks like a relay/exit (ExitPolicy accept). refusing client-only run."
  fi
  return 0
}

check_dns_pre() {
  local dns
  dns="$(grep -h nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' || true)"
  log "pre DNS: $dns"
}

preflight() {
  validate_torrc "$TOR_CONF"
  check_clock || true
  check_dns_pre || true
  if in_container; then
    warn "container detected. needs NET_ADMIN. test --dry-run first."
    check_caps || die "no NET_ADMIN in container. run privileged or on host."
  fi
  if [[ -z "$(tor_uid)" ]]; then
    die "tor user missing (debian-tor/tor). apt install tor."
  fi
  local other
  other="$(fw_other_active)"
  if [[ "$other" != "none" && "$FW_FORCE" != "1" ]]; then
    die "other firewall active ($other). stop it or set FW_FORCE=1. refusing to clobber."
  fi
  # backend decision is made by caller; here just report.
  if [[ "$FW_BACKEND_PREF" == "nft" ]] || [[ "$FW_BACKEND_PREF" == "auto" && "$(have nft && echo yes || echo no)" == "yes" ]]; then
    check_kernel_nft || warn "nft check failed, will try iptables compat."
  else
    have iptables || die "iptables missing and nft not selected. apt install nftables iptables."
  fi
}

doctor_full() {
  load_config
  echo "-- anonyx doctor --"
  echo "distro: $(distro_id) systemd: $(is_systemd && echo yes || echo no) container: $(in_container && echo yes || echo no)"
  echo "nft: $(have nft && nft --version 2>/dev/null || echo missing)"
  echo "iptables: $(have iptables && iptables --version 2>/dev/null || echo missing)"
  echo "fw other: $(fw_other_active) (FW_FORCE=$FW_FORCE)"
  echo "tor uid: $(tor_uid || echo missing)"
  echo "tor active: $(systemctl is-active --quiet tor 2>/dev/null && echo yes || pgrep -x tor >/dev/null 2>&1 && echo yes || echo no)"
  check_clock || true
  validate_torrc "$TOR_CONF" && echo "torrc: no dangerous binds"
  check_caps && echo "caps: NET_ADMIN ok" || echo "caps: NET_ADMIN missing"
  if have tor; then
    tor --version 2>/dev/null | head -n1 || true
  fi
}
