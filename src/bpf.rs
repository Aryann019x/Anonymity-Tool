// SPDX-License-Identifier: GPL-3.0-or-later
//! BPF map management without unsafe in this crate: shell out to bpftool/ip.
//! Keeps `cargo geiger` at zero unsafe in hot path; kernel verifier is the
//! real gate (test/fuzz/verify_ebpf.sh checks acceptance).
use std::process::Command;

pub fn supported() -> bool {
    std::path::Path::new("/sys/fs/bpf").exists()
        && (Command::new("bpftool")
            .arg("--version")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
            || Command::new("ip")
                .arg("link")
                .output()
                .map(|o| o.status.success())
                .unwrap_or(false))
}

pub fn allow_guard(ip: &str) -> bool {
    // validate dotted quad by type, never formatted into shell.
    let octets: Option<[u8; 4]> = parse_v4(ip);
    if octets.is_none() {
        return false;
    }
    Command::new("bpftool")
        .args(["map", "update", "pinned", "/sys/fs/bpf/anonyx/guards"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn parse_v4(s: &str) -> Option<[u8; 4]> {
    let mut out = [0u8; 4];
    let parts: Vec<&str> = s.split('.').collect();
    if parts.len() != 4 {
        return None;
    }
    for (i, p) in parts.iter().enumerate() {
        out[i] = p.parse::<u8>().ok()?;
    }
    Some(out)
}
