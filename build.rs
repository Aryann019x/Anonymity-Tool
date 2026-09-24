// SPDX-License-Identifier: GPL-3.0-or-later
//! build.rs - compile the eBPF object with clang when available.
//! Falls back silently (bash nft path stays working) so builds never break
//! on boxes without clang/llvm.
fn main() {
    println!("cargo:rerun-if-changed=lib/bpf/anonyx_kern.c");
    let clang = std::process::Command::new("clang")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    if !clang {
        println!("cargo:warning=clang missing, skipping BPF object build");
        return;
    }
    let status = std::process::Command::new("clang")
        .args([
            "-O2",
            "-target",
            "bpf",
            "-g",
            "-c",
            "lib/bpf/anonyx_kern.c",
            "-o",
            "target/anonyx_kern.o",
        ])
        .status();
    match status {
        Ok(s) if s.success() => println!("cargo:warning=BPF object at target/anonyx_kern.o"),
        _ => println!("cargo:warning=BPF build failed, nft fallback stays active"),
    }
}
