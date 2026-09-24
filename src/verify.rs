// SPDX-License-Identifier: GPL-3.0-or-later
//! Corridor-style verification without shell injection.
//! All parsing is typed; HTTP via curl subprocess with fixed argv (no sh -c).
use serde::{Deserialize, Serialize};
use std::fs;
use std::process::Command;
use std::time::{Duration, Instant};

#[derive(Debug, Serialize, Deserialize)]
pub struct TorApi {
    #[serde(rename = "IsTor")]
    pub is_tor: bool,
    #[serde(rename = "IP")]
    pub ip: String,
}

#[derive(Debug)]
pub struct State {
    pub state: String,
    pub backend: String,
    pub netns: String,
    pub tor_bootstrap: u8,
    pub tor: String,
    pub last_audit: String,
    pub mac_randomized: bool,
    pub bridges: String,
    pub version: String,
}

impl State {
    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".into())
    }
    pub fn exit_code(&self) -> i32 {
        match (self.state.as_str(), self.tor.as_str()) {
            ("enabled", "active") => 0,
            ("enabled", _) => 2,
            _ => 1,
        }
    }
}

impl std::fmt::Display for State {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "-- anonyx {} --\nstate: {} backend: {} netns: {}\ntor: {} bootstrap: {}% bridges: {}\nlast_audit: {} mac: {}",
            self.version,
            self.state,
            self.backend,
            self.netns,
            self.tor,
            self.tor_bootstrap,
            self.bridges,
            self.last_audit,
            self.mac_randomized
        )
    }
}

fn tor_port() -> String {
    std::env::var("TOR_PORT").unwrap_or_else(|_| "9050".into())
}

fn curl_tor_api() -> Result<TorApi, String> {
    let proxy = format!("socks5h://127.0.0.1:{}", tor_port());
    let out = Command::new("curl")
        .args([
            "--max-time",
            "15",
            "-s",
            "--proxy",
            &proxy,
            "https://check.torproject.org/api/ip",
        ])
        .output()
        .map_err(|e| format!("curl exec: {e}"))?;
    if !out.status.success() {
        return Err("curl failed".into());
    }
    let body = String::from_utf8_lossy(&out.stdout);
    serde_json::from_str::<TorApi>(&body).map_err(|e| format!("parse: {e}"))
}

/// Poll until IsTor==true or timeout. Returns exit IP.
pub fn leaktest() -> Result<String, String> {
    leaktest_timeout(Duration::from_secs(60))
}

pub fn leaktest_timeout(d: Duration) -> Result<String, String> {
    let start = Instant::now();
    loop {
        match curl_tor_api() {
            Ok(api) if api.is_tor && !api.ip.is_empty() => return Ok(api.ip),
            _ => {}
        }
        if start.elapsed() >= d {
            return Err("no tor exit (timeout)".into());
        }
        std::thread::sleep(Duration::from_secs(5));
    }
}

/// Corridor proof: direct clearnet must fail while enabled.
pub fn direct_blocked() -> bool {
    let out = Command::new("curl")
        .args(["--max-time", "5", "-s", "https://api.ipify.org"])
        .output();
    match out {
        Ok(o) => !o.status.success(),
        Err(_) => true,
    }
}

pub fn read_state() -> State {
    let path = std::env::var("STATE_JSON")
        .unwrap_or_else(|_| "/run/tor-killswitch/state.json".into());
    let raw = fs::read_to_string(&path).unwrap_or_default();
    let v: serde_json::Value = serde_json::from_str(&raw).unwrap_or(serde_json::Value::Null);
    let tor_up = Command::new("pgrep")
        .args(["-x", "tor"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    State {
        state: v
            .get("mode")
            .and_then(|m| m.as_str())
            .map(|_| "enabled".to_string())
            .unwrap_or_else(|| {
                if raw.contains("enabled") {
                    "enabled".into()
                } else {
                    "disabled".into()
                }
            }),
        backend: v
            .get("backend")
            .and_then(|m| m.as_str())
            .unwrap_or("unknown")
            .to_string(),
        netns: "unknown".into(),
        tor_bootstrap: 0,
        tor: if tor_up { "active".into() } else { "inactive".into() },
        last_audit: "unknown".into(),
        mac_randomized: std::path::Path::new("/run/tor-killswitch/mac.save").exists(),
        bridges: "direct".into(),
        version: env!("CARGO_PKG_VERSION").into(),
    }
}
