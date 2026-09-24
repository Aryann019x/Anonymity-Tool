// SPDX-License-Identifier: GPL-3.0-or-later
//! Type-safe nftables builders. Renders the same policy as lib/nft.sh.
//! Fuzz target: test/fuzz/fuzz_nft.rs feeds arbitrary modes/ports here and
//! asserts `nft --check` would accept the shape (no panics, no injections).
use std::fmt::Write;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    Strict,
    Paranoid,
    Transparent,
}

impl Mode {
    pub fn parse(s: &str) -> Option<Mode> {
        match s {
            "strict" => Some(Mode::Strict),
            "paranoid" => Some(Mode::Paranoid),
            "transparent" => Some(Mode::Transparent),
            _ => None,
        }
    }
}

/// Ports are u16 by type: injection impossible, range-checked at parse.
pub struct Policy {
    pub uid: u32,
    pub dns_port: u16,
    pub socks_port: u16,
    pub control_port: u16,
    pub trans_port: u16,
    pub mode: Mode,
    pub allow_dhcp: bool,
    pub allow_lan: bool,
}

impl Policy {
    pub fn render(&self) -> String {
        let mut s = String::with_capacity(2048);
        let _ = writeln!(s, "table inet anonyx {{");
        let _ = writeln!(
            s,
            "  chain output {{ type filter hook output priority 0; policy drop;"
        );
        let _ = writeln!(s, "    oifname \"lo\" accept");
        let _ = writeln!(s, "    ct state established,related accept");
        let _ = writeln!(s, "    meta skuid {} accept", self.uid);
        let _ = writeln!(
            s,
            "    udp dport 53 ip daddr 127.0.0.1 accept"
        );
        let _ = writeln!(
            s,
            "    tcp dport {{ {}, {} }} ip daddr 127.0.0.1 accept",
            self.socks_port, self.control_port
        );
        if self.allow_dhcp {
            let _ = writeln!(s, "    udp dport {{ 67, 68 }} udp sport {{ 67, 68 }} accept");
        }
        if self.allow_lan {
            let _ = writeln!(
                s,
                "    ip daddr {{ 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 }} accept"
            );
        }
        if self.mode == Mode::Transparent {
            let _ = writeln!(s, "    udp dport != 53 drop");
        }
        let _ = writeln!(s, "  }}");
        let _ = writeln!(
            s,
            "  chain input {{ type filter hook input priority 0; policy drop;"
        );
        let _ = writeln!(s, "    iifname \"lo\" accept");
        let _ = writeln!(s, "    ct state established,related accept");
        let _ = writeln!(s, "  }}");
        let _ = writeln!(
            s,
            "  chain forward {{ type filter hook forward priority 0; policy drop; }}"
        );
        if self.mode == Mode::Transparent {
            let _ = writeln!(
                s,
                "  chain nat-output {{ type nat hook output priority -100;"
            );
            let _ = writeln!(s, "    meta skuid {} return", self.uid);
            let _ = writeln!(s, "    oifname \"lo\" return");
            let _ = writeln!(s, "    udp dport 53 redirect to :{}", self.dns_port);
            let _ = writeln!(s, "    tcp dport 53 redirect to :{}", self.dns_port);
            let _ = writeln!(s, "    tcp dport != 9050 redirect to :{}", self.trans_port);
            let _ = writeln!(s, "  }}");
        }
        let _ = writeln!(s, "}}");
        s
    }
}
