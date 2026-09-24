#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# containerized reproducible rebuild check: diffoscope A vs B.
# usage: script/rebuild.sh /tmp/a /tmp/b
set -u
set -o pipefail
A="${1:-/tmp/a}"; B="${2:-/tmp/b}"
echo "[*] comparing $A vs $B"
if command -v diffoscope >/dev/null 2>&1; then
  for f in "$A"/*.deb; do
    base="$(basename "$f")"
    diffoscope --max-text-report-size 2000000 "$f" "$B/$base" || {
      echo "[-] builds differ ($base, see diffoscope above)"
      exit 1
    }
  done
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
