#!/usr/bin/env bash
# Run this on your COMPUTER (needs internet), from the project root, before
# `clickable`. It bundles argon2-cffi (arm64 wheels) into ./vendor so the app
# can open KeePass databases that use Argon2d/Argon2id (the KeePass default).
# UNTESTED helper: if pip can't find matching wheels, use AES-KDF in KeePass.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf vendor .wheels && mkdir -p vendor .wheels
pip download argon2-cffi argon2-cffi-bindings \
  --only-binary=:all: --no-deps \
  --platform manylinux2014_aarch64 --python-version 3.8 --implementation cp \
  -d .wheels
for w in .wheels/*.whl; do unzip -q -o "$w" -d vendor; done
rm -rf .wheels
echo "Bundled into ./vendor:"; ls vendor
