#!/bin/bash
set -e

cd "$(dirname "$0")/.."
# Note: There is no need for the “`brew --prefix openssl@1.1`/lib/pkgconfig”
#       path in the PKG_CONFIG_PATH (contrary to what’s told in the
#       Package.swift file) because the command line swift tooling finds the
#       brew prefix and uses it to add the required search paths for the system
#       targets.
PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$(pwd)/Configs/pkgconfig" swift package generate-xcodeproj
