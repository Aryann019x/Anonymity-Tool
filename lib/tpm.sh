#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# lib/tpm.sh - measured boot extras. All best-effort, never fatal.
# If /dev/tpm0 exists and tpm2-tools present: extend PCR 15 with state hash.
# shellcheck disable=SC1091
tpm_present() { [[ -e /dev/tpm0 || -e /dev/tpmrm0 ]]; }

tpm_extend_state() {
  # $1 = event string
  tpm_present || return 0
  have tpm2_pcrextend || { log "tpm present but tpm2-tools missing (apt install tpm2-tools)"; return 0; }
  local h
  h="$(printf '%s' "${1:-state}" | sha256sum 2>/dev/null | awk '{print $1}' || echo "")"
  [[ -n "$h" ]] || return 0
  if [[ "$DRY_RUN" == "1" ]]; then echo "would extend PCR15 with $h"; return 0; fi
  tpm2_pcrextend 15:sha256="$h" 2>/dev/null || warn "tpm extend failed (non-fatal)"
  audit_event "tpm-extend" "pcr15 event=${1:-state}"
}

tpm_seal_note() {
  # Full sealed-log encryption needs clevis/tpm2 sealing at install time;
  # here we record PCR state so live-USB tampering is detectable in audit log.
  tpm_present || return 0
  local pcrs
  pcrs="$(tpm2_pcrread sha256:15 2>/dev/null | sha256sum 2>/dev/null | awk '{print $1}' || echo unknown)"
  audit_event "tpm-pcr" "sha256:15 digest=$pcrs"
}
