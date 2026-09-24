# Security policy

Report privately. Do not open public issues for bypasses or leaks.

Contact: security@example.com

PGP (placeholder - replace before release):

```
Fingerprint: 1234 5678 90AB CDEF 1234 5678 90AB CDEF 1234 5678
```

## Disclosure

90 days from report to public fix. We notify you 7 days before publish.
Credit given if you want it, silent if you don't.

## In scope (a vuln)

- killswitch bypass: clearnet egress while state=enabled
- DNS/IPv6 leak while enabled
- privilege escalation via anonyx, its units, or NM dispatcher
- restore leaving rules behind (fail-open after --restore)
- audit log tamper without root

Include: distro, `anonyx --status --json`, `anonyx --audit` tail (redact IPs), steps to reproduce.

## Out of scope

- Tor network attacks (exit sniffing, guard discovery, global passive adversary)
- Physical access, evil maid, BIOS/ME
- Browser fingerprinting (use Tor Browser, not curl)
- Censored nets needing fresh bridges (not a vuln)
- Social engineering / identity mixing (logging into personal accounts over Tor)

## Rules for testers

- test on your own boxes or containers only.
- no scanning exits, no relay abuse.
- redact real IPs in reports.
