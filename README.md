<p align="center">
<strong>Anonyx</strong>
</p>

<p align="center">
Tor anonymity toolkit for Kali Linux
</p>

<p align="center">
<a href="https://github.com/Aryann019x/Anonymity-Tool/commits/main"><img src="https://img.shields.io/badge/version-2.1-blue"></a>
<a href="./Anonyx.sh"><img src="https://img.shields.io/badge/bash-5.x-green"></a>
<a href="./LICENSE"><img src="https://img.shields.io/github/license/Aryann019x/Anonymity-Tool"></a>
<a href="https://github.com/Aryann019x/Anonymity-Tool/graphs/contributors"><img src="https://img.shields.io/github/contributors/Aryann019x/Anonymity-Tool"></a>
</p>

## About

**Anonyx** is a shell script for [Kali Linux](https://www.kali.org/) which uses Tor, ProxyChains, and iptables rules to route traffic through the Tor network with a kill-switch, DNS protection, and IPv6 blocking. It also provides leak checks, new identity, and panic mode.

In simple terms, with Anonyx you can anonymize system CLI traffic and prevent accidental clearnet leaks when Tor drops.

**This program was created for Kali Linux and Debian-based distributions. Do not run it on other distributions if you are not sure what you are doing.**

### About Tor

If you are new to Tor, start here:

[Wikipedia: Tor anonymity network](https://en.wikipedia.org/wiki/Tor_%28anonymity_network%29)

[Tor Project website](https://www.torproject.org/)

### What Anonyx does

- Routes TCP/DNS via Tor SOCKS (`127.0.0.1:9050`, DNSPort `5353`)
- Applies an iptables kill-switch: only the Tor user and loopback can go out, the rest is dropped
- Locks `/etc/resolv.conf` to anon DNS so NetworkManager cannot revert it
- Disables IPv6 while active (restored on disable)
- Verifies Tor via `check.torproject.org` and rolls back automatically on failure

---

## Install

Download with `git`:

```term
git clone https://github.com/Aryann019x/Anonymity-Tool.git
```

Install dependencies:

```term
sudo apt-get update
sudo apt-get install -y tor proxychains4 torsocks curl ufw iptables iproute2
```

Make executable:

```term
cd Anonymity-Tool/
chmod +x Anonyx.sh
```

---

## Usage

Before starting:

1. Read the [Security](#security) section.
2. Back up iptables rules if you have custom ones.
3. Run as root.

Start anonymity mode:

```term
sudo ./Anonyx.sh --enable
```

Return to clearnet:

```term
sudo ./Anonyx.sh --disable
```

Commands list:

**--enable**

    enable anonymity mode and kill-switch

**--disable**

    restore configs, firewall, and IPv6

**--status**

    show Tor, DNS, and IPv6 status

**--leaktest**

    check Tor IP vs clear IP, DNS, IPv6, and firewall

**--newid**

    restart Tor for a new circuit and exit IP

**--panic**

    cut all network connectivity immediately

**--help, --version**

    show help / version

Interactive menu is available with no arguments:

```term
sudo ./Anonyx.sh
```

While enabled, run applications through ProxyChains:

```term
proxychains4 curl https://check.torproject.org/api/ip
```

Direct connections will time out while enabled. That is the kill-switch working, not a bug.

---

## Uninstall / Restore

Anonyx modifies no system binaries. `--disable` restores:

- `/etc/tor/torrc` from `torrc.bak.anonyx`
- `/etc/proxychains4.conf` from `proxychains4.conf.bak.anonyx`
- `/etc/resolv.conf` from `resolv.conf.bak.anonyx` (unlocks `chattr +i`)
- iptables from `/var/lib/anonyx/iptables.bak`
- IPv6 sysctl settings

To remove the tool, run `--disable` first, then delete the cloned directory. Logs remain at `/var/log/anonymity.log` unless removed manually.

---

## Security

Read this section carefully before use.

**Anonyx is produced independently from Tor and carries no guarantee from the Tor Project about quality or suitability. Read these documents to use Tor safely:**

[Tor Project FAQ](https://support.torproject.org/faq/)

[Whonix Do Not recommendations](https://www.whonix.org/wiki/DoNot)

**Anonyx does not guarantee 100% anonymity.** It protects against accidental connections and DNS leaks by misconfigured software. It is not sufficient against malware or software with serious vulnerabilities.

### Hostname and MAC address

Applications can still learn hostname, MAC address, serial number, and timezone. Change at least hostname and MAC before sensitive work if your threat model includes the local network.

### Tor over Tor

Do not start Tor Browser while Anonyx transparent mode is active. See [Tor over Tor](https://www.whonix.org/wiki/DoNot#Allow_Tor_over_Tor_Scenarios).

### Checking for leaks

After enabling, use `--leaktest` for a quick check. For manual verification with `tcpdump`, get the interface and Tor guard IP:

```term
ip -o addr
ss -ntp | grep "$(cat /var/run/tor/tor.pid)"
```

Then check for non-Tor traffic (replace guard IP):

```term
sudo tcpdump -n -p -i eth0 not arp and not host IP.TO.TOR.GUARD
```

No output beyond headers is expected. See [Tor Transparent Proxy checks](https://gitlab.torproject.org/legacy/trac/-/wikis/doc/TransparentProxy#checking-for-leaks).

---

## Configuration

- SOCKS: `127.0.0.1:9050`
- DNSPort: `127.0.0.1:5353`
- TransPort: `127.0.0.1:9040`
- ControlPort: `9051`
- DNS: `1.1.1.1`, `9.9.9.9`, `208.67.222.222`
- State: `/var/lib/anonyx/`

---

## Credits

- [Tor Project documentation](https://gitlab.torproject.org/tpo/tpa/team/-/wikis/home)
- [Whonix documentation](https://www.whonix.org/wiki/Documentation)
- [Kalitorify](https://github.com/brainfucksec/kalitorify) and Parrot AnonSurf for the transparent proxy approach

"KALI LINUX" is a trademark of Offensive Security. "Tor" is a trademark of The Tor Project, Inc.

---

## License

MIT License. See [LICENSE](LICENSE).
