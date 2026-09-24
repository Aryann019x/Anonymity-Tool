#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/common.sh - shared paths, logging, config, state
# sourced by bin/anonyx, never executed directly.
# shellcheck disable=SC2034

set -u
set -o pipefail

ANONYX_VERSION="${ANONYX_VERSION:-3.0.0}"

# FHS paths, all overridable for tests / XDG / packaging.
ETC_DIR="${ETC_DIR:-/etc/tor-killswitch}"
VAR_RUN_DIR="${VAR_RUN_DIR:-/run/tor-killswitch}"
VAR_LOG_DIR="${VAR_LOG_DIR:-/var/log/tor-killswitch}"
VAR_LIB_DIR="${VAR_LIB_DIR:-/var/lib/anonyx}"
CONF_FILE="${CONF_FILE:-$ETC_DIR/config}"
STATE_JSON="${STATE_JSON:-$VAR_RUN_DIR/state.json}"
AUDIT_LOG="${AUDIT_LOG:-$VAR_LOG_DIR/audit.log}"
TOR_CONF="${TOR_CONF:-/etc/tor/torrc}"
TOR_BAK="${TOR_BAK:-/etc/tor/torrc.bak.anonyx}"

TOR_PORT="${TOR_PORT:-9050}"
CONTROL_PORT="${CONTROL_PORT:-9051}"
DNS_PORT="${DNS_PORT:-5353}"
TRANS_PORT="${TRANS_PORT:-9040}"
MODE="${MODE:-strict}"
ALLOW_DHCP="${ALLOW_DHCP:-1}"
ALLOW_LAN="${ALLOW_LAN:-0}"
EXIT_NODES="${EXIT_NODES:-}"
BRIDGE_LINES="${BRIDGE_LINES:-}"
FW_FORCE="${FW_FORCE:-0}"
FW_BACKEND_PREF="${FW_BACKEND_PREF:-auto}"
NETNS_ENABLE="${NETNS_ENABLE:-0}"
NETNS_NAME="${NETNS_NAME:-anonyx-tor}"
RAM_ONLY="${RAM_ONLY:-0}"
FW_MARK="${FW_MARK:-0x1}"
QUIET="${QUIET:-0}"
JSON_OUT="${JSON_OUT:-0}"
DRY_RUN="${DRY_RUN:-0}"
NO_INSTALL="${NO_INSTALL:-0}"

if [[ -t 1 ]]; then
  C_R="\e[31m"; C_G="\e[32m"; C_Y="\e[33m"; C_W="\e[97m"; C_B="\e[34m"; C_0="\e[0m"
else
  C_R=""; C_G=""; C_Y=""; C_W=""; C_B=""; C_0=""
fi

have() { command -v "$1" >/dev/null 2>&1; }

log()  { [[ "$QUIET" == "1" ]] || echo -e "${C_W}[*] $*${C_0}"; logger -t anonyx "$*" 2>/dev/null || true; }
ok()   { [[ "$QUIET" == "1" ]] || echo -e "${C_G}[+] $*${C_0}"; }
warn() { echo -e "${C_Y}[!] $*${C_0}" >&2; }
die()  { echo -e "${C_R}[-] $*${C_0}" >&2; exit "${2:-1}"; }

need_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "run as root: sudo anonyx --enable" 1; }

ensure_dirs() {
  mkdir -p "$VAR_RUN_DIR" "$VAR_LOG_DIR" "$VAR_LIB_DIR" "$ETC_DIR" 2>/dev/null || true
  chmod 750 "$VAR_RUN_DIR" "$VAR_LOG_DIR" "$VAR_LIB_DIR" "$ETC_DIR" 2>/dev/null || true
  touch "$AUDIT_LOG" 2>/dev/null || true
  chmod 640 "$AUDIT_LOG" 2>/dev/null || true
}

# minimal KEY=VALUE config loader with schema validation.
load_config() {
  [[ -f "$CONF_FILE" ]] || return 0
  local key val
  while IFS='=' read -r key val; do
    key="$(echo "$key" | tr -d ' \t')"
    [[ -z "$key" || "$key" == \#* ]] && continue
    val="$(echo "$val" | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
    case "$key" in
      MODE|ALLOW_DHCP|ALLOW_LAN|EXIT_NODES|BRIDGE_LINES|FW_FORCE|FW_BACKEND_PREF|NETNS_ENABLE|NETNS_NAME|TOR_PORT|CONTROL_PORT|DNS_PORT|TRANS_PORT|FW_MARK) printf -v "$key" '%s' "$val" ;;
      *) warn "unknown config key $key in $CONF_FILE (ignored)" ;;
    esac
  done < "$CONF_FILE"
  case "${MODE:-strict}" in strict|paranoid|transparent) ;; *) die "bad MODE=$MODE in $CONF_FILE" ;; esac
  case "${FW_BACKEND_PREF:-auto}" in auto|nft|iptables) ;; *) die "bad FW_BACKEND_PREF=$FW_BACKEND_PREF" ;; esac
  [[ "$MODE" == "paranoid" ]] && ALLOW_DHCP=0
  if ! [[ "$TOR_PORT" =~ ^[0-9]+$ && "$CONTROL_PORT" =~ ^[0-9]+$ && "$DNS_PORT" =~ ^[0-9]+$ && "$TRANS_PORT" =~ ^[0-9]+$ ]]; then
    die "bad ports in $CONF_FILE"
  fi
}

# state.json: single source of truth for --restore.
state_write() {
  ensure_dirs
  local tmp
  tmp="$(mktemp "$VAR_RUN_DIR/.state.XXXXXX")" || return 1
  cat > "$tmp"
  chmod 640 "$tmp"
  mv -f "$tmp" "$STATE_JSON"
}

state_clear() { rm -f "$STATE_JSON" 2>/dev/null || true; }
state_get() {
  [[ -f "$STATE_JSON" ]] || return 1
  have jq && jq -r "$1" "$STATE_JSON" 2>/dev/null && return 0
  have python3 && python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],""))' "$STATE_JSON" "${1#.}" 2>/dev/null && return 0
  grep -o "\"${1#.}\": *\"[^\"]*\"" "$STATE_JSON" 2>/dev/null | cut -d'"' -f4
}
