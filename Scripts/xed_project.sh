#!/bin/bash

cd "$(dirname "$0")"/..
ps aux | grep -q '[X]code\.app/Contents/MacOS/Xcode' && { echo "Xcode must not be launched" >/dev/stderr; exit 1; }

# The explicit PKG_CONFIG_PATH for openssl is required when using Xcode’s SPM,
# contrary to CLI’s SPM (because CLI’s SPM is aware of brew).
PKG_CONFIG_PATH="$PKG_CONFIG_PATH:`brew --prefix openssl@1.1`/lib/pkgconfig" xed .
