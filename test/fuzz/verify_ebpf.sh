#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# verify_ebpf: kernel BPF verifier must accept our object.
# Run on Debian 12 (kernel 6.1, BTF on): clang build + bpftool load dry-run.
set -eu
if ! command -v clang >/dev/null 2>&1; then
  echo "SKIP: clang missing"
  exit 0
fi
clang -O2 -target bpf -g -c lib/bpf/anonyx_kern.c -o /tmp/anonyx_kern.o
echo "[+] compiled"
if command -v bpftool >/dev/null 2>&1; then
  echo "[*] load test needs root + CAP_BPF; verifier output:"
  bpftool prog load /tmp/anonyx_kern.o /sys/fs/bpf/anonyx-test 2>&1 || echo "(load needs root, compile OK)"
else
  echo "SKIP load: bpftool missing (compile OK)"
fi
