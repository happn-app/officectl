#!/bin/zsh
#emulate -LR zsh
set -euo pipefail

cd "$(dirname "$0")"/zz_assets

# TODO: Make this path configurable via command line options
readonly DEST="/usr/local/lib/pkgconfig"

readonly TMPL="./pkgconfig_template"
readonly XATTR_NAME="com.happn.spm-workaround"

# Process and install the .pc files.
# Note:
#    - If the template has some files that are removed at some point, these will
#      never be cleaned from the destination.
PREFIX="`brew --prefix openldap`"
VERSION="`brew info openldap --json | jq -r '.[0].installed[-1].version'`"
# First let’s check we’ll be able to install the files we want. We check the
# files do not exist, or if they do, they have the com.happn.spm-workaround
# xattr (with any value for now we don’t care, we assume they will be from us).
for f in "$TMPL"/*.pc; do
	DESTFILE="$DEST/$(basename "$f")"
	if [ -e "$DESTFILE" ]; then
		if [ ! -f "$DESTFILE" ]; then
			echo "File $DESTFILE already exist and is not a regular file. Bailing." >&2
			exit 1
		fi
		# Let’s check if the file has the xattr we expect
		if ! xattr -p "$XATTR_NAME" "$DESTFILE" >/dev/null 2>&1; then
			echo "File $DESTFILE does not seem to have the $XATTR_NAME xattr. Bailing." >&2
			exit 1
		fi
	fi
done
for f in "$TMPL"/*.pc; do
	DESTFILE="$DEST/$(basename "$f")"
	sed -E -e "s|__PREFIX__|$PREFIX|g" -e "s|__VERSION__|$VERSION|g" "$f" >"$DESTFILE"
	xattr -w "$XATTR_NAME" "author: officectl" "$DESTFILE"
done
