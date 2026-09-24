# how anonyx works

```
apps -> proxychains (127.0.0.1:9050) -> tor -> guard -> middle -> exit -> net
dns  -> 127.0.0.1:5353 (tor DNSPort), nothing else allowed
clearnet -> iptables OUTPUT DROP (except debian-tor uid + lo)
ipv6 -> sysctl off + ip6tables DROP
```

## enable order

1. check uplink, install deps (unless --no-install)
2. save clear ip to /var/lib/anonyx/clear_ip (600) for leak compare
3. backup resolv (incl. symlink target), write nameserver 127.0.0.1, chattr +i
4. torrc: keep user file, append managed block, restart tor
5. proxychains -> socks5 127.0.0.1 9050
6. iptables: flush, P DROP, allow lo, ESTABLISHED, debian-tor uid, lo dns/tor ports. dhcp/lan only if config allows. transparent adds nat REDIRECT.
7. wait bootstrap (curl check.torproject.org/api/ip up to 60s). fail -> auto --disable.

## disable order

resolv restore (rebuild symlink if there was one) -> strip torrc block ->
proxychains restore -> iptables-restore from backup -> ipv6 on -> tor restart.

## files

- /etc/tor/torrc (+ .bak.anonyx once)
- /etc/proxychains4.conf (+ .bak.anonyx once)
- /etc/resolv.conf (+ .bak.anonyx + /var/lib/anonyx/resolv.link)
- /var/lib/anonyx/iptables.bak, ip6tables.bak, ufw.state (informational), state, clear_ip
- /var/log/anonyx.log

No persistence across reboot by design, except anonyx-restore.service which
just runs --disable on boot if a stale state file exists.
