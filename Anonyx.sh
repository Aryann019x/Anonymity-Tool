#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# legacy shim. real code moved to bin/anonyx (3.x appliance).
# kept so old `sudo ./Anonyx.sh --enable` still works.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/bin/anonyx" "$@"
