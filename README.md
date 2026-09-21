# Anonymity Tool Anonyx v2.0

## Overview
Anonyx is a simple anonymity tool for Kali / Debian. It routes stuff through Tor, locks DNS, blocks ipv6 leaks and has a kill-switch so if Tor dies your clear IP doesnt leak out.

Not magic though - your ISP still sees youre using Tor, and if you login to your real accounts Tor wont hide you. This just makes accidental leaks much harder.

## Features
- Sets up Tor with safer torrc (socks + dnsport, no disk writes, localhost only).
- Kill-switch with iptables: only tor user + loopback can go out.
- Locks resolv.conf so NetworkManager doesnt revert it.
- Blocks ipv6 (biggest bypass for tor socks).
- Backs up everything before changing.
- Leak check (tor ip vs clear ip, dns, ipv6, firewall).
- Panic mode to cut net instantly.
- Menu + cli flags.
- Logs to /var/log/anonymity.log.

## Prerequisites
- Kali Linux or any Debian-based distro.
- Root access (needed for network configs and packages).

## Installation
1. **Clone the repo**:
    ```bash
    git clone https://github.com/Aryann019x/Anonymity-Tool.git
    cd Anonymity-Tool
    ```

2. **Make it executable**:
    ```bash
    chmod +x Anonyx.sh
    ```
3. **Run it as root**:
    ```bash
    sudo ./Anonyx.sh
    ```
    Or direct:
    ```bash
    sudo ./Anonyx.sh --enable
    sudo ./Anonyx.sh --status
    sudo ./Anonyx.sh --leaktest
    sudo ./Anonyx.sh --disable
    sudo ./Anonyx.sh --panic
    ```
## Menu Options

**[1] Enable**: Tor + proxychains + dns + kill-switch.  
**[2] Disable**: Restores old configs + firewall.  
**[3] Show Status**: tor, ips, dns, ipv6.  
**[4] Leak check**: compares tor ip vs clear ip, checks dns/ipv6.  
**[5] Panic**: cuts all net right now.  
**[6] Exit**.

## Tool Specifications
- Socks: 127.0.0.1:9050
- DNSPort: 127.0.0.1:5353
- TransPort: 127.0.0.1:9040
- Control: 9051
- DNS:
  - 1.1.1.1
  - 9.9.9.9
  - 208.67.222.222

- **Files used**
  - Log: `/var/log/anonymity.log`
  - State: `/var/lib/anonyx/` (iptables backup, clear ip)
  - Proxychains: `/etc/proxychains4.conf` (backup `.bak.anonyx`)
  - DNS: `/etc/resolv.conf` (backup `.bak.anonyx`, locked with chattr)
  - Tor: `/etc/tor/torrc` (backup `.bak.anonyx`)

## How to use right
Enable, then **always use proxychains**:

```bash
sudo ./Anonyx.sh --enable
proxychains4 curl https://check.torproject.org/api/ip
sudo ./Anonyx.sh --leaktest
```

Without proxychains most apps will just fail to connect - thats the kill-switch working, not a bug.

Check:
```bash
cat /etc/resolv.conf
# should be 1.1.1.1 etc, not 192.168.x or 127.0.0.53
sudo iptables -L OUTPUT -n | head
# should show DROP + tor uid rule
cat /proc/sys/net/ipv6/conf/all/disable_ipv6
# should be 1
```

## Disable it
```bash
sudo ./Anonyx.sh --disable
```
Restores resolv.conf, torrc, proxychains, iptables and ipv6.

If you used panic, run disable after to get net back. Reboot also clears it.

All runs logged in `/var/log/anonymity.log`.

## Notes / limits
- Kill-switch allows tor user + dhcp + lo only. Normal clearnet browsing is blocked on purpose while enabled.
- Ipv6 is disabled while enabled, restored after.
- ISP / college / govt can still see youre using Tor (thats how Tor works). Dont login to personal accounts if you need anonymity.
- Tested on Kali + Debian with systemd. On WSL / non-systemd it falls back to `service tor`.
- If you ran v1.x before, backups now use `.bak.anonyx` + `/var/lib/anonyx`.

## CONTRIBUTING
Found a bug or want something added? Open an issue or send a PR.

## AUTHOR
Aryann019x

## LICENSE
MIT License - see LICENSE file.
