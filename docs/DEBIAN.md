# debian / ubuntu / kali notes. core boxes differ from live kali usb.

## supported

- kali rolling, debian 11/12, ubuntu 22.04/24.04, parrot, mint, pop
- run `sudo anonyx --doctor` first. it tells you distro, firewall, tor uid, cookie.

## packages

names move around. anonyx handles it:
- proxychains: `proxychains4` on kali/debian12, `proxychains` on old releases. auto-detected.
- torsocks: optional. install fails won't kill enable.
- ufw: only auto-installed on ubuntu/kali/parrot. plain debian server usually has none, we don't force it.
- xxd: no hard dep. uses xxd -> od -> hexdump -> python3, whatever you have.
- obfs4proxy: only if you set BRIDGE_LINES.

debian minimal install needs: `apt install tor curl iptables iproute2`

## firewall

- debian 12 uses iptables-nft wrapper by default. anonyx drives iptables, works on top. native nft sets may conflict, check `nft list ruleset`.
- if ufw or firewalld is active, enable refuses unless `FW_FORCE=1`. we don't clobber other firewalls blind. stop them or set the flag.
- docker / lxc / vps: needs NET_ADMIN. in container it fails closed with a clear msg. test with `--dry-run`.

## dns

- kali: NetworkManager + resolved stub. handled, link saved/restored.
- debian server: often plain /etc/resolv.conf or resolvconf. we lock with chattr if present, warn if resolvconf fights us.
- we stop systemd-resolved only if it was active. plain boxes left alone.

## tor

- user is `debian-tor` on debian/kali/ubuntu, `tor` elsewhere, `_tor` on some. auto-detected. missing = abort, no open fallback.
- cookie at /var/lib/tor/control_auth_cookie, or /run/tor/control.authcookie. auto-detected for NEWNYM.
- apparmor: stock debian tor profile stays. we only touch torrc managed block.

## wsl2 / vm

wsl2 has no systemd by default, no real iptables. use native linux or vm with bridged net. `--doctor` will tell you.

## server heads-up

reboot clears killswitch. after reboot you are clearnet until enable again. enable `systemd/anonyx-restore.service` if you want auto-restore of dns on boot after crash.
