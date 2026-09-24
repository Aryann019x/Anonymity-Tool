# recipes - what to actually run

All assume `sudo anonyx --enable` first. Direct without proxychains = blocked on purpose.

## apt updates over tor (debian/ubuntu)

```
sudo anonyx apt update
sudo anonyx apt upgrade
```

Uses socks5h proxy for apt. No clearnet fallback.

## git over tor

```
sudo anonyx --exec -- git clone https://github.com/user/repo.git
# or profile (sets socks proxy + ssh ProxyCommand):
anonyx git clone https://github.com/user/repo.git
```

Never `git://`, only https/ssh. Profile warns and refuses git://.

## ssh over tor

```
anonyx ssh user@host -p 22
```

Goes via `nc -X 5 -x 127.0.0.1:9050`. Needs netcat-openbsd.

## curl / wget

```
anonyx curl https://check.torproject.org/api/ip
anonyx wget https://example.com/file
```

## nmap (lab only)

```
anonyx nmap -sT -Pn 10.0.0.5
```

TCP connect only, no SYN/UDP scan over tor. Slow. Don't scan exits.

## transparent mode (apps that ignore proxychains)

```
sudo anonyx --enable --mode transparent
curl https://check.torproject.org/api/ip   # now goes via tor even without proxychains
```

TCP + DNS through tor. Other UDP dropped (voip/games break - expected).

## censored net (tor blocked)

```
sudo anonyx --bridges
# paste lines from bridges.torproject.org, empty line to finish
sudo anonyx --enable
```

## opsec before serious work

```
sudo anonyx --opsec
sudo anonyx --leaktest
```
