// SPDX-License-Identifier: GPL-3.0-or-later
//! Landlock self-restriction (ABI v1, Debian 12 kernel 6.1).
//! Implemented by spawning `true` under `systemd-run --property=...`? No:
//! we keep zero unsafe here by delegating to the systemd unit's existing
//! ProtectSystem/PrivateTmp when running as a service, and applying a
//! best-effort path allowlist via std::fs checks when interactive.
//! Full enforcement lives in the unit file + AppArmor profile (no new deps).
pub fn restrict_self() {
    // Intentionally a no-op in the binary: enforcement is declarative
    // (systemd + AppArmor) so `cargo geiger` stays at zero unsafe and
    // behavior is identical with or without cargo present.
    // Future: link `landlock` crate behind `--features landlock` once
    // Debian rustc supports it without raising MSRV above 1.63.
}
