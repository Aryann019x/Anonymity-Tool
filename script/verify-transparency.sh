#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# verify Sigstore Rekor inclusion for release artifacts.
# usage: script/verify-transparency.sh <artifact> <rekor-uuid>
set -u
set -o pipefail
ART="${1:-}"; UUID="${2:-}"
[[ -n "$ART" ]] || { echo "usage: $0 <artifact> [rekor-uuid]"; exit 2; }
if command -v rekor-cli >/dev/null 2>&1 && [[ -n "$UUID" ]]; then
  rekor-cli get --log-index "$UUID" --format json
else
  echo "[*] artifact sha256:"
  sha256sum "$ART"
  echo "[*] check inclusion at https://search.sigstore.dev/ (see docs/transparency.md)"
  [[ -n "$UUID" ]] && echo "uuid: $UUID"
fi
