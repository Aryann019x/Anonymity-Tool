# Anonymity Tool Anonyx v1.2

## Overview
Anonyx is a simple anonymity tool for Kali Linux or any other Debian-based distro. It automates Tor, Proxychains and secure DNS setup so you can browse more privately.

## Features
- Installs and configures Tor, Proxychains and secure DNS.
- Backs up your original configs before changing anything.
- Simple menu + cli flags to enable / disable anonymity.
- Checks if Tor is actually working before saying done.
- Logs to /var/log/anonymity.log for debugging.

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
    You can also run it directly:
    ```bash
    sudo ./Anonyx.sh --enable
    sudo ./Anonyx.sh --status
    sudo ./Anonyx.sh --disable
    ```
## Menu Options

**[1] Enable Anonymity**: Sets up Tor + proxychains + anon DNS.  
**[2] Disable Anonymity**: Restores your old configs.  
**[3] Show Status**: Shows tor service, tor IP and DNS.  
**[4] Exit**: Exits the tool.

## Tool Specifications
- Tor Port: 9050
- Control Port: 9051
- DNS Servers:
  - 1.1.1.1
  - 9.9.9.9
  - 208.67.222.222

- **Files used**
  - Log: `/var/log/anonymity.log`
  - Proxychains: `/etc/proxychains4.conf` (backup at `/etc/proxychains4.conf.bak.anonyx`)
  - DNS: `/etc/resolv.conf` (backup at `/etc/resolv.conf.bak.anonyx`)
  - Tor: `/etc/tor/torrc` (backup at `/etc/tor/torrc.bak.anonyx`)

## How to check if its working
- Enable it:

```bash
sudo ./Anonyx.sh
# pick [1]
```

**Check Tor**:
```bash
proxychains4 curl https://check.torproject.org
```
Should say you are using Tor.

**Tor service**:
```bash
sudo systemctl status tor
```

**DNS**:
```bash
cat /etc/resolv.conf
```
Should show:
```
nameserver 1.1.1.1
nameserver 9.9.9.9
nameserver 208.67.222.222
```

**Firewall**:
```bash
sudo ufw status verbose
```

## Disable it
```bash
sudo ./Anonyx.sh
# pick [2]
```
Then check:
```bash
cat /etc/resolv.conf
curl https://www.example.com
```
DNS should be back to normal and net should work.

All runs are logged in `/var/log/anonymity.log`.

## Notes
- Tor socks runs on localhost so no need to open 9050/9051 in ufw. Script just makes sure ufw is enabled.
- If ping is blocked on your network the script falls back to curl for the net check.
- If you ran v1.1 before, old `/etc/resolv.conf.bak` is left alone, new backups use `.bak.anonyx`.

## CONTRIBUTING
Found a bug or want something added? Open an issue or send a PR.

## AUTHOR
Aryann019x

## LICENSE
MIT License - see LICENSE file.
