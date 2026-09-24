#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# verify SLSA provenance for a release artifact.
# usage: script/verify-provenance.sh <artifact> <provenance.jsonl>
set -u
set -o pipefail
ART="${1:-}"; PROV="${2:-}"
[[ -n "$ART" && -n "$PROV" ]] || { echo "usage: $0 <artifact> <provenance>"; exit 2; }
if command -v slsa-verifier >/dev/null 2>&1; then
  slsa-verifier verify-artifact "$ART" \
    --provenance-path "$PROV" \
    --source-uri github.com/Aryann019x/Anonymity-Tool
else
  echo "[!] slsa-verifier missing (go install github.com/slsa-framework/slsa-verifier)"
  echo "[*] manual check: sha256sum $ART against subjects in $PROV"
  sha256sum "$ART"
  grep -o '"sha256":"[0-9a-f]*"' "$PROV" | head -n 5 || true
fi
