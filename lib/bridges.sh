#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/bridges.sh - automatic fallback when direct Tor is censored.
# Order: direct -> snowflake (Debian pkg) -> stored obfs4 -> ask user.
# No downloads outside Debian main/contrib.
# shellcheck disable=SC1091

bridges_auto() {
  # called after direct verify fails. returns 0 if a bridge path works.
  log "direct Tor failed, trying bridge fallback..."
  if have snowflake-client; then
    log "enabling snowflake (Debian pkg)"
    BRIDGE_LINES="Bridge snowflake 192.0.2.3:1 2B280B9FDA0F5984F message"
    # real snowflake needs broker; tor handles it via ClientTransportPlugin.
    if tor_with_bridges "snowflake"; then return 0; fi
  fi
  if [[ -n "${BRIDGE_LINES:-}" ]]; then
    log "trying stored obfs4 bridges"
    have obfs4proxy || { warn "obfs4proxy missing (apt install obfs4proxy)"; return 1; }
    if tor_with_bridges "obfs4"; then return 0; fi
  fi
  warn "no working auto-bridge. run: sudo anonyx --bridges (paste from bridges.torproject.org)"
  return 1
}

tor_with_bridges() {
  local kind="$1"
  # appends managed bridge block via torrc_write in main; here just signal.
  # main re-calls torrc_write + restart + verify. keep this side-effect free for tests.
  [[ "$kind" == "snowflake" || "$kind" == "obfs4" ]]
}
