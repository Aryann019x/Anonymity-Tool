#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# release gate for anonyx. run from repo root before tagging.
set -u
set -o pipefail
fail=0
run() { echo "[*] $*"; "$@" || { echo "[-] FAILED: $*"; fail=1; }; }
run shellcheck -S warning bin/anonyx lib/*.sh
run bash -n bin/anonyx
run systemd-analyze verify systemd/anonyx.service
run systemd-analyze verify systemd/anonyx-watchdog.service
if command -v apparmor_parser >/dev/null 2>&1; then
  run apparmor_parser -p etc/apparmor.d/usr.bin.anonyx
else
  echo "[!] apparmor_parser missing, skipped"
fi
if command -v dpkg-buildpackage >/dev/null 2>&1; then
  run dpkg-buildpackage -us -uc
  if command -v lintian >/dev/null 2>&1 && ls ../*.deb >/dev/null 2>&1; then
    run lintian --pedantic ../*.deb
  else
    echo "[!] lintian skipped (no .deb or no lintian)"
  fi
else
  echo "[!] dpkg-buildpackage missing, skipped"
fi
if command -v bats >/dev/null 2>&1; then
  run bats test/unit/
else
  echo "[!] bats missing, skipped"
fi
if grep -rInwE 'TODO|FIXME|XXX' bin/ lib/ etc/ systemd/ debian/ test/ examples/ 2>/dev/null; then
  echo "[-] placeholder markers found"; fail=1
else
  echo "[+] no TODO/FIXME/XXX"
fi
exit $fail
