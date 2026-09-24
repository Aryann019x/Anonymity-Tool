// SPDX-License-Identifier: GPL-3.0-or-later
//! anonyx 5.0 dispatcher - memory-safe CLI, no shell injection.
//! Hot path (verify/nft) is 100% safe Rust (see cargo-geiger).
//! BPF/landlock helpers shell out to bpftool/ip to avoid unsafe libc in hot path.
mod bpf;
mod landlock;
mod nft;
mod verify;

use std::env;
use std::process::Command;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn usage() {
    eprintln!("anonyx {VERSION} - tor killswitch (rust dispatcher, bash fallback if cargo missing)");
    eprintln!("  --enable [--mode strict|paranoid|transparent] [--ram-only]");
    eprintln!("  --restore | --status [--json] | --leaktest | --audit | --doctor");
    eprintln!("  --help --version");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let has = |f: &str| args.iter().any(|a| a == f);
    let get = |f: &str| {
        args.windows(2)
            .find(|w| w[0] == f)
            .map(|w| w[1].clone())
            .unwrap_or_default()
    };
    if has("--help") || has("-h") {
        usage();
        return;
    }
    if has("--version") || has("-V") {
        println!("anonyx {VERSION}");
        return;
    }
    if has("--status") {
        let st = verify::read_state();
        if has("--json") || std::env::var("JSON_OUT").as_deref() == Ok("1") {
            println!("{}", st.to_json());
        } else {
            println!("{st}");
        }
        std::process::exit(st.exit_code());
    }
    if has("--leaktest") {
        match verify::leaktest() {
            Ok(ip) => {
                println!("[+] tor exit {ip}");
                if verify::direct_blocked() {
                    println!("[+] direct blocked");
                } else {
                    eprintln!("[-] direct open");
                    std::process::exit(1);
                }
            }
            Err(e) => {
                eprintln!("[-] {e}");
                std::process::exit(1);
            }
        }
        return;
    }
    // privileged ops delegate to the audited bash appliance (same policy files).
    let script = "/usr/share/anonyx/libexec.sh";
    let fallback = "bin/anonyx";
    let target = if std::path::Path::new(script).exists() {
        script.to_string()
    } else {
        fallback.to_string()
    };
    let mode = get("--mode");
    let mut cmd = Command::new("bash");
    cmd.arg(&target);
    cmd.args(&args[1..]);
    if !mode.is_empty() {
        cmd.env("MODE", mode);
    }
    if has("--ram-only") {
        cmd.env("RAM_ONLY", "1");
    }
    // Landlock self-restriction before exec (best effort, falls back silently).
    landlock::restrict_self();
    let status = cmd.status().unwrap_or_else(|e| {
        eprintln!("[-] exec {target}: {e}");
        std::process::exit(2);
    });
    std::process::exit(status.code().unwrap_or(2));
}
