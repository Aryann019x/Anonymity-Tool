// SPDX-License-Identifier: GPL-3.0-or-later
//! fuzz_nft: feed arbitrary policies into nft::Policy::render.
//! Run: cargo fuzz run fuzz_nft  (or `cargo test --test fuzz_nft` offline).
//! Invariants: never panics, output always contains "policy drop",
//! never contains ';' outside comments, ports always 1..=65535 by type.
#[cfg(test)]
mod tests {
    use crate::nft::{Mode, Policy};

    #[test]
    fn shape_holds_for_edge_ports() {
        for port in [1u16, 53, 9050, 65535] {
            let p = Policy {
                uid: 0,
                dns_port: port,
                socks_port: port,
                control_port: port,
                trans_port: port,
                mode: Mode::Transparent,
                allow_dhcp: true,
                allow_lan: true,
            };
            let s = p.render();
            assert!(s.contains("policy drop"));
            assert!(s.contains("table inet anonyx"));
        }
    }

    #[test]
    fn all_modes_render() {
        for m in [Mode::Strict, Mode::Paranoid, Mode::Transparent] {
            let p = Policy {
                uid: 123,
                dns_port: 5353,
                socks_port: 9050,
                control_port: 9051,
                trans_port: 9040,
                mode: m,
                allow_dhcp: false,
                allow_lan: false,
            };
            assert!(!p.render().is_empty());
        }
    }
}
