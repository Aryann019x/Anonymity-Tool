#!/usr/bin/env bats
# test/integration/leak.bats - needs root + docker or real debian host.
# CI runs this on debian stable with Tor installed.
setup() { [ "$(id -u)" -eq 0 ] || skip "needs root"; }

@test "enable blocks direct, tor exit works" {
  run bin/anonyx --enable --mode strict
  [ "$status" -eq 0 ]
  run curl --max-time 5 -s https://api.ipify.org
  [ "$status" -ne 0 ]
  run bin/anonyx --leaktest
  [ "$status" -eq 0 ]
  run bin/anonyx --restore
  [ "$status" -eq 0 ]
}

@test "restore is clean (no reboot needed)" {
  run bin/anonyx --restore
  [ "$status" -eq 0 ]
  run curl --max-time 8 -sI https://1.1.1.1
  [ "$status" -eq 0 ]
}
