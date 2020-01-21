#!/bin/bash


# Straight up copied from Carthage
# Not needed after all because we don’t use this script to compile in Homebrew
SANDBOX_FLAGS=
#SWIFTPM_DISABLE_SANDBOX_SHOULD_BE_FLAGGED=$(test -n "${HOMEBREW_SDKROOT}" && echo should_be_flagged)
#if [ "$SWIFTPM_DISABLE_SANDBOX_SHOULD_BE_FLAGGED" = "should_be_flagged" ]; then
#	SANDBOX_FLAGS="--disable-sandbox"
#fi


# Let’s find Homebrew’s OpenLDAP
SWIFT_BUILD_OPENLDAP_OPTIONS=()
for b in "/usr/local/opt/openldap" "${HOME}/usr/homebrew/opt/openldap"; do
	lib_dir="$b/lib"
	include_dir="$b/include"
	if [ -d "$lib_dir" -a -d "$include_dir" ]; then
		SWIFT_BUILD_OPENLDAP_OPTIONS=("-Xcc" "-I$include_dir" "-Xlinker" "-L$lib_dir")
		break
	fi
done


cd "$(dirname "$0")/.."

swift build $SANDBOX_FLAGS -c release "${SWIFT_BUILD_OPENLDAP_OPTIONS[@]}"
