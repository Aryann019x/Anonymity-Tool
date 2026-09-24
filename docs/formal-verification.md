# Formal verification notes - what we claim and how we check it.

Claim: **if anonyx state=enabled, every egress packet exits through Tor or is dropped.**

Invariants:
1. I1: filter hook output policy = drop (nft + iptables + XDP agree).
2. I2: only ACCEPT classes = loopback, ESTABLISHED, tor-uid, tor-ports-on-lo, (dhcp|lan if configured).
3. I3: UDP != :53 is DROP (Tor cannot carry it; transparent mode included).
4. I4: DNS resolves only via 127.0.0.1:5353 (resolv locked, chattr +i).
5. I5: restore removes table/netns/DNS lock (state.json is the witness).

TLA+ sketch (test/prove/anonyx.tla):
- vars: enabled \in {0,1}, pkt \in {tor, clear, dns, lo}.
- Next: enabled=1 /\ pkt=clear => dropped'=TRUE.
- Liveness: tor-dead => watchdog blocks within 10s.

Checked today by:
- `test/unit/nft.bats`: generated ruleset contains drop + uid accept, no 80/443.
- `bats test/integration`: direct curl fails while enabled, passes after restore.
- `test/fuzz/verify_ebpf.sh`: kernel verifier accepts the XDP/tc object.
- audit log + state.json give the forensic trail.

Not proven: Tor protocol anonymity itself, exit honesty, hardware backdoors.
