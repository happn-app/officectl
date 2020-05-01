#!/bin/bash

cd "$(dirname "$0")"/..
ps aux | grep -q '[X]code\.app/Contents/MacOS/Xcode' && { echo "Xcode must not be launched" >/dev/stderr; exit 1; }
PKG_CONFIG_PATH="$PKG_CONFIG_PATH:`brew --prefix openssl@1.1`/lib/pkgconfig:$(pwd)/Configs/pkgconfig:$(pwd)/.build/checkouts/officectl/Configs/pkgconfig" xed .
