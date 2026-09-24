#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# containerized reproducible rebuild check: diffoscope A vs B.
# usage: script/rebuild.sh /tmp/a /tmp/b
set -u
set -o pipefail
A="${1:-/tmp/a}"; B="${2:-/tmp/b}"
echo "[*] comparing $A vs $B"
if command -v diffoscope >/dev/null 2>&1; then
  diffoscope --max-text-report-size 2000000 "$A"/*.deb "$B"/*.deb || {
    echo "[-] builds differ (see diffoscope above)"
    exit 1
  }
else
  # fallback: sha256 compare per file
  fail=0
  for f in "$A"/*; do
    base="$(basename "$f")"
    if ! cmp -s "$f" "$B/$base"; then echo "[-] differs: $base"; fail=1; fi
  done
  [[ $fail -eq 0 ]] || exit 1
fi
echo "[+] reproducible: identical"
