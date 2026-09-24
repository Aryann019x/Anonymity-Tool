#!/usr/bin/env bash
# sudo ./uninstall.sh
set -u
PREFIX="${PREFIX:-/usr/local}"
rm -f "$PREFIX/bin/anonyx"
rm -f /usr/share/bash-completion/completions/anonyx
rm -f /usr/share/man/man1/anonyx.1
echo "[+] removed. /etc/anonyx/anonyx.conf left in place on purpose."
