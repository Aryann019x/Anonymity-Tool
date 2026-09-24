#!/usr/bin/env bats
# test/unit/nft.bats - nft rule generation, no root needed.
setup() { export LIB_DIR="$BATS_TEST_DIRNAME/../../lib"; source "$LIB_DIR/common.sh"; source "$LIB_DIR/nft.sh"; }

@test "strict generates drop policy + tor uid accept" {
  run nft_generate 123 5353 9050 9051 9040 strict 1 0 0x1
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy drop"* ]]
  [[ "$output" == *"meta skuid 123 accept"* ]]
  [[ "$output" != *"dport 80"* ]]
}

@test "transparent adds nat redirect + udp drop" {
  run nft_generate 123 5353 9050 9051 9040 transparent 1 0 0x1
  [[ "$output" == *"redirect to :5353"* ]]
  [[ "$output" == *"redirect to :9040"* ]]
  [[ "$output" == *"udp dport != 53 drop"* ]]
}

@test "nft --check passes when nft present" {
  have nft || skip "nft not installed here"
  run nft_generate 123 5353 9050 9051 9040 strict 1 0 0x1 > /tmp/anonyx-test.nft
  run nft --check -f /tmp/anonyx-test.nft
  [ "$status" -eq 0 ]
}
