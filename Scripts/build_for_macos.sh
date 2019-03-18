#!/bin/bash

cd "$(dirname "$0")/.."
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/opt/openssl/lib/pkgconfig:${HOME}/usr/homebrew/opt/openssl/lib/pkgconfig" swift build -c release -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.13" --static-swift-stdlib
