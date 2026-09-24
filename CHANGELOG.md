# Changelog - Keep a Changelog

## [3.0.0] - 2026-09-23
First appliance release after the 2.x single-script line.
### Added
- nftables primary backend with `nft --check` gated apply, iptables compat retained.
- Tor network-namespace isolation (opt-in) with veth + fwmark policy routing.
- Corridor-style verification: bootstrap + exit IP IsTor match + direct-block proof.
- `--audit` append-only log at /var/log/tor-killswitch/audit.log (chattr +a).
- Pre-flight: torrc dangerous-setting validation, clock sync check, DNS pre-check, kernel/caps checks.
- Watchdog fail-closed if Tor dies; GPIO panic button hook.
- MAC randomization in paranoid mode with restore file.
- Automatic bridge fallback: snowflake (Debian pkg) then stored obfs4.
- state.json at /run/tor-killswitch/state.json; `--restore` clean undo, no reboot.
- systemd notify units with hardening + seccomp SystemCallFilter; AppArmor profile; NM dispatcher; debconf templates.
- Early-boot block: initramfs hook + init-premount (loopback-only nft), optional `anonyx-initramfs` package.
- eBPF/XDP guard (`lib/bpf/anonyx_kern.c`, CO-RE/BTF) + `lib/bpf_loader.sh`; nft stays authoritative on failure.
- Rust dispatcher (`src/main.rs/verify.rs/nft.rs/bpf.rs/landlock.rs`, optional: bash fallback always stays).
- Landlock posture: declarative via systemd + AppArmor, no new runtime deps.
- TPM measured extras (`lib/tpm.sh`): PCR extend on enable/restore, digest in audit.
- `--ram-only`: tmpfs over logs/config, shred on restore.
- SLSA Level 3: provenance workflow, verify-provenance script, reproducible workflow + rebuild.sh, transparency docs + verify script.
- SBOM: generate-sbom.sh (cargo-cyclonedx/audit/deny), CI fails on HIGH/CRITICAL.
- Secure updates: debian/postinst (downgrade block), lib/update.sh --revoke, apt pinning preferring Debian archive.
- Fuzz + keys CI workflows, TLA+ sketch + formal notes.
- Multi-binary debian: anonyx, anonyx-initramfs, libanonyx-dev.
- test/unit (nft --check) + test/integration + CI on stable/testing/unstable.
- groff man page, examples/, config validation, developer OPSEC/keys docs.

### Changed
- Paths moved to FHS appliance layout (/etc/tor-killswitch, /run/tor-killswitch, /var/log/tor-killswitch).
- Anonyx.sh is now a shim calling bin/anonyx.
- License: GPL-3.0-or-later (was MIT in 2.x).

## [3.2] - 2026-09-23
- Transparent solid, app profiles, opsec checklist, bridge wizard.

## [3.1] - 2026-09-23
- Debian/core compat: doctor, proxychains autodetect, per-distro deps.

## [3.0] - 2026-09-23
- Fail-closed DNS + killswitch rewrite.
