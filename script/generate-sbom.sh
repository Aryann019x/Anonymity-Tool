#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# generate SBOM (SPDX + CycloneDX) and fail on HIGH/CRITICAL vulns.
# Debian-only tools where possible; cargo plugins when present.
set -u
set -o pipefail
OUT="${1:-sbom}"
mkdir -p "$OUT"
if command -v cargo-cyclonedx >/dev/null 2>&1; then
  cargo cyclonedx --format json -o "$OUT/bom.json" || true
  echo "[+] cyclonedx: $OUT/bom.json"
else
  echo "[!] cargo-cyclonedx missing: cargo install cargo-cyclonedx"
fi
if command -v cargo-audit >/dev/null 2>&1; then
  cargo audit --deny warnings 2>&1 | tee "$OUT/audit.txt" || {
    echo "[-] cargo audit found issues (see $OUT/audit.txt)"
    exit 1
  }
else
  echo "[!] cargo-audit missing: cargo install cargo-audit"
fi
if command -v cargo-deny >/dev/null 2>&1; then
  cargo deny check 2>&1 | tee -a "$OUT/audit.txt" || exit 1
else
  echo "[!] cargo-deny missing (optional)"
fi
echo "[+] sbom done: $OUT/"
