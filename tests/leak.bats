#!/usr/bin/env bats
# smoke tests. run: bats tests/ or make test
# static checks run anywhere. fw tests need root on debian/kali.

@test "bash syntax ok" {
  run bash -n Anonyx.sh
  [ "$status" -eq 0 ]
}

@test "no 80/443 fallback ACCEPT" {
  run grep -E "dport 80 -j ACCEPT|dport 443 -j ACCEPT" Anonyx.sh
  [ "$status" -ne 0 ]
}

@test "no clearnet dns allow rules" {
  # must not allow 1.1.1.1:53 direct anymore
  run bash -c 'grep -q "OUTPUT -d .1.1.1.1" Anonyx.sh'
  [ "$status" -ne 0 ]
}

@test "dns tor-only in lock" {
  run grep -q 'nameserver 127.0.0.1' Anonyx.sh
  [ "$status" -eq 0 ]
}

@test "torrc uses managed markers" {
  run grep -q "anonyx managed" Anonyx.sh
  [ "$status" -eq 0 ]
}

@test "proxychains path auto-detected, not hardcoded only" {
  run grep -q "PROXYCHAINS_CANDIDATES" Anonyx.sh
  [ "$status" -eq 0 ]
}

@test "no hard xxd dep in NEWNYM" {
  run bash -c 'grep -A3 "control_newnym" Anonyx.sh | grep -q "have xxd || return 1" && exit 1 || exit 0'
  [ "$status" -eq 0 ]
}

@test "doctor command exists" {
  run bash Anonyx.sh --help
  [[ "$output" == *"doctor"* ]]
}

@test "panic keeps loopback" {
  run grep -A8 "PANIC - cutting" Anonyx.sh
  [[ "$output" == *"lo"* ]]
}

@test "debian doc exists" {
  [ -f docs/DEBIAN.md ]
}

@test "opsec + bridges + app profiles exist" {
  run grep -q "do_opsec" Anonyx.sh
  [ "$status" -eq 0 ]
  run grep -q "do_bridges" Anonyx.sh
  [ "$status" -eq 0 ]
  run grep -q "do_app" Anonyx.sh
  [ "$status" -eq 0 ]
}

@test "transparent drops non-dns udp" {
  run grep -q 'OUTPUT -p udp -j DROP' Anonyx.sh
  [ "$status" -eq 0 ]
}

@test "recipes doc exists" {
  [ -f docs/RECIPES.md ]
}
