#!/usr/bin/env bash
set -euo pipefail
# Do not vendor pykeepass via pip into the click package. The click package must
# not contain host-arch binaries; Ubuntu Touch installs Python deps as target
# packages instead.

echo "pykeepass is expected to be provided by the target device package set."
