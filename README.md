# Anonyx

Tor-based anonymity toolkit for Kali Linux and Debian with kill-switch, DNS protection, and leak detection.

[![License: MIT](https://img.shields.io/github/license/Aryann019x/Anonymity-Tool)](LICENSE)
[![Made with Bash](https://img.shields.io/badge/made_with-bash-green)](Anonyx.sh)
[![Version](https://img.shields.io/badge/version-2.1-blue)](Anonyx.sh)

## Overview

Anonyx routes traffic through Tor, blocks clearnet leaks with an iptables kill-switch, locks DNS configuration, and disables IPv6 while active. It is designed for CLI work on Kali/Debian where accidental IP or DNS leaks are a risk.

Note: An ISP can still observe Tor usage, and logging into personal accounts will de-anonymize activity. This tool reduces accidental leaks; it does not provide absolute anonymity.

## Features

- Hardened Tor configuration (localhost SOCKS, DNSPort, no disk writes)
- iptables kill-switch (only Tor user and loopback allowed out)
- DNS lock to prevent NetworkManager overwrites
- IPv6 disable while enabled, restored on disable
- Leak checker (Tor IP vs clear IP, DNS, IPv6, firewall)
- New identity (fresh Tor circuit)
- Panic mode (immediate network cut)
- Automatic backup and restore of all modified configs
- Operation logging to `/var/log/anonymity.log`

## Requirements

- Kali Linux or Debian-based distribution
- Root privileges
- systemd preferred (falls back to `service` on WSL/non-systemd)

Dependencies (`tor`, `proxychains4`, `torsocks`, `curl`, `ufw`, `iptables`, `iproute2`) are installed automatically.

## Installation

```bash
git clone https://github.com/Aryann019x/Anonymity-Tool.git
cd Anonymity-Tool
chmod +x Anonyx.sh
sudo ./Anonyx.sh
```

## Usage

| Command | Description |
| --- | --- |
| `sudo ./Anonyx.sh` | Open interactive menu |
| `sudo ./Anonyx.sh --enable` | Enable anonymity and kill-switch |
| `sudo ./Anonyx.sh --disable` | Restore normal settings |
| `sudo ./Anonyx.sh --status` | Show Tor, DNS, and IPv6 status |
| `sudo ./Anonyx.sh --leaktest` | Run leak checks |
| `sudo ./Anonyx.sh --newid` | Request a new Tor exit IP |
| `sudo ./Anonyx.sh --panic` | Cut all network connectivity |

Menu options: Enable, Disable, Status, Leak check, New identity, Panic, Exit.

Example workflow:

```bash
sudo ./Anonyx.sh --enable
proxychains4 curl https://check.torproject.org/api/ip
sudo ./Anonyx.sh --leaktest
sudo ./Anonyx.sh --disable
```

While enabled, applications must be run via `proxychains4`. Direct connections will time out; this indicates the kill-switch is functioning.

## How It Works

1. Records the current clearnet IP for later comparison.
2. Backs up `torrc`, `proxychains4.conf`, and `resolv.conf`.
3. Writes a hardened Tor configuration and locks DNS.
4. Applies iptables rules (Tor user + loopback only) and disables IPv6.
5. Verifies Tor connectivity; rolls back automatically on failure.
6. On disable, restores all files, firewall rules, and IPv6 settings.

## Configuration

- SOCKS: `127.0.0.1:9050`
- DNSPort: `127.0.0.1:5353`
- TransPort: `127.0.0.1:9040`
- ControlPort: `9051`
- DNS servers: `1.1.1.1`, `9.9.9.9`, `208.67.222.222`
- State: `/var/lib/anonyx/`
- Backups: `*.bak.anonyx`

## Troubleshooting

- **No connectivity after enable:** Expected without `proxychains4`. Use `proxychains4 <command>`.
- **Tor verification fails:** Tor bootstrap can be slow. Wait 30 seconds, check `systemctl status tor` and the log file.
- **No network after panic:** Run `sudo ./Anonyx.sh --disable` or reboot.
- **Same IP after --newid:** Exit pool is limited; retry after a short wait.

## Contributing

Issues and pull requests are welcome. Changes affecting iptables should be tested in a virtual machine before submission.

## Author

Aryann019x

## License

MIT License. See [LICENSE](LICENSE).
