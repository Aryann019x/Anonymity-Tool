#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# install anonyx from source. Debian-based only. read it first.
set -u
set -o pipefail

PREFIX="${PREFIX:-/usr/local}"

need_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "run as root: sudo ./install.sh"; exit 1; }; }

# 1. distro gate
if [[ ! -f /etc/debian_version ]] && ! grep -qi "debian\|kali\|ubuntu\|parrot\|mint\|pop" /etc/os-release 2>/dev/null; then
  echo "[-] not Debian-based ($(grep -E '^ID=' /etc/os-release 2>/dev/null || echo unknown)). refusing."
  echo "    anonyx 3.x targets Debian 12+ only."
  exit 1
fi

need_root

# 2. kernel gate (nftables features need 5.10+)
KVER="$(uname -r 2>/dev/null | cut -d. -f1,2 || echo 0.0)"
KMAJ="${KVER%%.*}"; KMIN="${KVER#*.}"
if [[ "$KMAJ" -lt 5 ]] || { [[ "$KMAJ" -eq 5 ]] && [[ "$KMIN" -lt 10 ]]; }; then
  echo "[-] kernel $KVER < 5.10. nftables/netns paths need 5.10+."
  exit 1
fi

# 3. backup torrc before anything touches it
if [[ -f /etc/tor/torrc && ! -f /etc/tor/torrc.pre-anonyx ]] && [[ "${1:-}" != "--no-backup" ]]; then
  cp -a /etc/tor/torrc /etc/tor/torrc.pre-anonyx
  chmod 600 /etc/tor/torrc.pre-anonyx
  echo "[+] backed up /etc/tor/torrc -> /etc/tor/torrc.pre-anonyx"
fi

if command -v make >/dev/null 2>&1 && [[ -f Makefile ]]; then
  make install PREFIX="$PREFIX" DESTDIR=""
else
  BIN="$PREFIX/bin/anonyx"
  mkdir -p "$PREFIX/bin" "$PREFIX/share/anonyx/lib" /etc/tor-killswitch
  cp bin/anonyx "$BIN"; chmod 755 "$BIN"
  cp lib/*.sh "$PREFIX/share/anonyx/lib/"
  [[ -f /etc/tor-killswitch/config ]] || cp etc/tor-killswitch/config.example /etc/tor-killswitch/config
  chmod 600 /etc/tor-killswitch/config 2>/dev/null || true
fi

mandb -q 2>/dev/null || true

echo "[+] installed. first: sudo anonyx --doctor"
read -rp "Enable anonyx service now? [y/N] " ans
if [[ "$ans" == y || "$ans" == Y ]]; then
  systemctl enable anonyx 2>/dev/null || echo "[!] systemctl enable failed (non-systemd box?)"
fi
echo "    uninstall without reboot: sudo anonyx --restore"
