#!/bin/bash

cd "$(dirname "$0")/.."
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/opt/openssl/lib/pkgconfig:${HOME}/usr/homebrew/opt/openssl/lib/pkgconfig" swift package generate-xcodeproj
