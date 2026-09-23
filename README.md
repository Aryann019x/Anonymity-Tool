<div align="center">

# Anonyx

**Simple Tor anonymity toolkit for Kali Linux and Debian.**

Route CLI traffic through Tor, with kill-switch, DNS lock, and leak checks.

[![version](https://img.shields.io/badge/version-2.2-blue)](Anonyx.sh)
[![bash](https://img.shields.io/badge/bash-5.x-green)](Anonyx.sh)
[![license](https://img.shields.io/github/license/Aryann019x/Anonymity-Tool)](LICENSE)
[![last-commit](https://img.shields.io/github/last-commit/Aryann019x/Anonymity-Tool)](https://github.com/Aryann019x/Anonymity-Tool/commits/main)

</div>

<br>

<p align="center">
  <a href="assets/anonyx-demo.gif"><img src="assets/anonyx-demo.gif" alt="Anonyx live terminal demo" width="100%"></a>
  <br>
  <em>Live demo: menu → enable → status → leak check → Tor proof (click to enlarge)</em>
</p>

---

## Contents

- [What it does](#what-it-does)
- [Quick start](#quick-start)
- [Usage](#usage)
- [How it works](#how-it-works)
- [Security notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)
- [License](#license)

---

## What it does

Anonyx is a single Bash script that:

1. Transparently routes **all TCP** through Tor — no `proxychains` needed
2. Resolves **DNS through Tor itself** (`127.0.0.1:5353`), never plaintext
3. Blocks everything else with an iptables kill-switch
4. Disables IPv6 while active (a common Tor bypass)
5. Isolates circuits per destination, verifies leaks, and lets you grab a fresh identity or cut the network instantly

> [!NOTE]
> Your ISP can still see you are using Tor. Logging into personal accounts will still identify you. Anonyx stops accidental leaks — it does not make you invisible.

Built for Kali Linux and Debian-based systems. Must run as root.

New to Tor? Start here: [Tor Project](https://www.torproject.org/) · [Tor FAQ](https://support.torproject.org/faq/) · [Whonix Do-Not list](https://www.whonix.org/wiki/DoNot)

---

## Quick start

```bash
git clone https://github.com/Aryann019x/Anonymity-Tool.git
cd Anonymity-Tool
chmod +x Anonyx.sh

sudo ./Anonyx.sh --enable
curl -s https://check.torproject.org/api/ip
sudo ./Anonyx.sh --leaktest
```

No `proxychains` needed — plain `curl` already exits via Tor (see the demo above). To stop and restore everything:

```bash
sudo ./Anonyx.sh --disable
```

---

## Usage

Run with no arguments for the interactive menu:

```bash
sudo ./Anonyx.sh
```

| Command | Description |
| --- | --- |
| `--enable` | Enable anonymity + kill-switch |
| `--disable` | Restore configs, firewall, IPv6 |
| `--status` | Show Tor, DNS, IPv6 status |
| `--leaktest` | Check IP, DNS, IPv6, firewall |
| `--newid` | Restart Tor for a new exit IP |
| `--panic` | Cut all network immediately |
| `--help`, `--version` | Help / version info |

> [!IMPORTANT]
> Traffic flows transparently: plain `curl`, `apt`, `ssh` all exit via Tor — no `proxychains` needed (it still works as an alternative). UDP-based apps (calls, games, QUIC) stay blocked: Tor can't carry UDP, that's a protocol limit, not a bug.

Dependencies (`tor`, `proxychains4`, `torsocks`, `curl`, `ufw`, `iptables`, `iproute2`) install automatically.

---

## How it works

```text
Your apps → iptables REDIRECT → Tor (TransPort 9040 / DNSPort 5353) → Internet
Anything unredirectable (UDP) → dropped by the kill-switch
IPv6 → disabled for the session
DNS → 127.0.0.1, answered by Tor, never leaves in plaintext
```

Steps on `--enable`:

1. Saves your clear IP for later comparison
2. Backs up `torrc`, `proxychains4.conf`, `resolv.conf` (once, never overwrites a good backup)
3. Writes hardened Tor config (per-destination circuit isolation), pins DNS to Tor with `chattr +i`
4. Applies kill-switch + transparent NAT redirects, disables IPv6
5. Verifies Tor — auto-restores everything on failure

On `--disable`, all files, firewall rules, and IPv6 settings are restored. Nothing else on the system is modified.

Details: SOCKS `9050` (isolated) · DNSPort `5353` · TransPort `9040` · Control `9051` · `resolv.conf` → `127.0.0.1` · state in `/var/lib/anonyx/` · log at `/var/log/anonymity.log`

---

## Security notes

> [!WARNING]
> Anonyx is independent from Tor and carries no guarantee from the Tor Project. It guards against misconfiguration and accidental leaks — not malware or fingerprinting.

- **Hostname / MAC:** apps can still see these. Change them first if your threat includes the local network.
- **Tor over Tor:** don't run Tor Browser while Anonyx is active ([why](https://www.whonix.org/wiki/DoNot#Allow_Tor_over_Tor_Scenarios)).
- **Manual leak check:** `sudo ./Anonyx.sh --leaktest`, or with tcpdump: `sudo tcpdump -n -p -i eth0 not arp and not host <TOR_GUARD_IP>` — expect no traffic beyond headers.

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| No internet after enable | Tor may still be bootstrapping — wait 30s, check `systemctl status tor` and `/var/log/anonymity.log`. |
| UDP apps (calls, games, QUIC) never work | Tor can't carry UDP. By design, not a bug. |
| Tor stuck bootstrapping | Check the clock (`timedatectl`) — Tor needs correct time. Sync, then enable. |
| No network after panic | Run `sudo ./Anonyx.sh --disable` or reboot. |
| Same IP after `--newid` | Exit pool is small. Wait and retry. |
| DNS keeps reverting | v2.2 pins `resolv.conf` to Tor. Run `sudo chattr -i /etc/resolv.conf`, then disable/enable. |

---

## Credits

- [Tor Project support](https://support.torproject.org/)
- [Whonix docs](https://www.whonix.org/wiki/Documentation)
- [Kalitorify](https://github.com/brainfucksec/kalitorify) / Parrot AnonSurf for the transparent-proxy approach

---

## License

MIT — see [LICENSE](LICENSE).
