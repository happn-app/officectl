#!/bin/bash


# Straight up copied from Carthage
# Not needed after all because we don’t use this script to compile in Homebrew
SANDBOX_FLAGS=
#SWIFTPM_DISABLE_SANDBOX_SHOULD_BE_FLAGGED=$(test -n "${HOMEBREW_SDKROOT}" && echo should_be_flagged)
#if [ "$SWIFTPM_DISABLE_SANDBOX_SHOULD_BE_FLAGGED" = "should_be_flagged" ]; then
#	SANDBOX_FLAGS="--disable-sandbox"
#fi


cd "$(dirname "$0")/.."

PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/opt/openssl/lib/pkgconfig:${HOME}/usr/homebrew/opt/openssl/lib/pkgconfig" \
	swift build $SANDBOX_FLAGS -c release \
	-Xcc "-I/usr/local/opt/openldap/include" -Xlinker "-L/usr/local/opt/openldap/lib" \
	-Xcc "-I${HOME}/usr/homebrew/opt/openldap/include" -Xlinker "-L${HOME}/usr/homebrew/opt/openldap/lib"
