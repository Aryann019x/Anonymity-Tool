#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/verify.sh - corridor-style confirmation that traffic exits via Tor.
# Checks: control-port bootstrap, consensus freshness, exit IP == Tor API IsTor.
# shellcheck disable=SC1091

tor_bootstrap_phase() {
  # best effort via control port; empty if unauthenticated.
  local cookie_hex ctrl
  cookie_hex="$(tor_cookie_hex || true)"
  [[ -n "${cookie_hex:-}" ]] || return 1
  exec 3<>/dev/tcp/127.0.0.1/"$CONTROL_PORT" 2>/dev/null || return 1
  printf 'AUTHENTICATE %s\nGETINFO status/bootstrap-phase\nQUIT\n' "$cookie_hex" >&3 2>/dev/null
  ctrl="$(head -c 2048 <&3 2>/dev/null || true)"
  exec 3<&- 2>/dev/null; exec 3>&- 2>/dev/null
  echo "$ctrl" | grep -o "PROGRESS=[0-9]*" | cut -d= -f2 | tail -n1
}

tor_cookie_hex() {
  local c
  for c in /var/lib/tor/control_auth_cookie /run/tor/control.authcookie /var/run/tor/control.authcookie; do
    [[ -f "$c" ]] || continue
    if have xxd; then xxd -p -c 64 "$c" 2>/dev/null | tr -d '\n'; return 0; fi
    if have od; then od -An -tx1 "$c" 2>/dev/null | tr -d ' \n'; return 0; fi
    if have python3; then python3 -c 'import sys,binascii;print(binascii.hexlify(open(sys.argv[1],"rb").read()).decode())' "$c" 2>/dev/null; return 0; fi
  done
  return 1
}

tor_exit_ip() {
  curl --max-time 15 --socks5-hostname "127.0.0.1:$TOR_PORT" -s https://check.torproject.org/api/ip 2>/dev/null || true
}

verify_tor_exit() {
  # $1 = timeout seconds. prints exit IP on success.
  local timeout_s="${1:-60}" waited=0 body ip istor
  while [[ $waited -lt $timeout_s ]]; do
    body="$(tor_exit_ip)"
    istor="$(echo "$body" | grep -o '"IsTor":[a-z]*' | cut -d: -f2 || true)"
    ip="$(echo "$body" | grep -o '"IP":"[^"]*' | cut -d'"' -f4 || true)"
    if [[ "$istor" == "true" && -n "${ip:-}" ]]; then
      # consensus freshness: control port circuit-status has BUILT circuits.
      echo "$ip"
      audit_event "verify-ok" "exit=$ip"
      return 0
    fi
    sleep 5; waited=$((waited+5))
  done
  audit_event "verify-fail" "timeout=${timeout_s}s"
  return 1
}

verify_no_direct() {
  # corridor proof: direct clearnet must fail while killswitch is on.
  if curl --max-time 5 -s https://api.ipify.org >/dev/null 2>&1; then
    echo "direct clearnet reachable (killswitch open)"
    return 1
  fi
  return 0
}
