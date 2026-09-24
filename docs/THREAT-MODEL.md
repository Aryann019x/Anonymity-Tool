# threat model - read this first

anonyx is a cli killswitch. nothing more.

## Adversaries we handle

- your own mistakes: running `curl ipinfo.io` without proxychains and leaking home ip.
- dhcp / NetworkManager / resolved flipping dns back to lan/router mid-session.
- ipv6 going out direct while you thought everything was socksed.
- app doing direct udp/53 to clearnet.

## Adversaries we do NOT handle

- isp seeing tor. they see entry guard ip + timing. bridges hide a bit, not fully.
- exit node sniffing http. use https. always.
- browser fingerprinting. anonyx is not Tor Browser. don't treat cli curl like a hardened browser.
- malware on your box. rootkit reads clear_ip file, keylogs, done.
- you logging into gmail/github over tor exit. that links exit to you.
- tor-over-tor: Tor Browser + anonyx at same time makes weird circuits. pick one.
- forensics: log at /var/log/anonyx.log has timestamps. clear_ip stored while enabled.

## Rules

1. enable, then `sudo anonyx --leaktest`. if it says leak, believe it.
2. use `proxychains4` or `anonyx --exec -- <cmd>`. direct = blocked on purpose.
3. bridges if tor is blocked in your country. get them from bridges.torproject.org yourself.
4. panic (`--panic`) when in doubt. then `--disable` or reboot.
5. reboot wipes killswitch. after reboot you are on clearnet until you enable again.
   install `systemd/anonyx-restore.service` if you want auto-restore of dns on boot after crash.

If your threat includes police / military / targeted hacking, use Tails / Whonix,
not a single bash script on a daily-driver kali.
