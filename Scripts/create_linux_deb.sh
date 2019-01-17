#!/bin/bash

set -e

readonly SCRIPT_DIR="$(pwd)/$(dirname "$0")"
readonly LINUX_BUILD_PRODUCTS_DIR="$SCRIPT_DIR/../linux_build/products/"
readonly BUILT_PRODUCT_NAME="officectl"
readonly BUILT_PRODUCT_DIR="$LINUX_BUILD_PRODUCTS_DIR/release/"
readonly BUILT_PRODUCT_PATH="$BUILT_PRODUCT_DIR/$BUILT_PRODUCT_NAME"
readonly BUILT_PRODUCT_ARCHIVE_PATH="$SCRIPT_DIR/../linux_build/products/release.tar.gz"

readonly DESTINATION_ASSETS_FOLDER="/usr/share/officectl"

readonly VERSION="$1"
readonly REVISION="${2:-1}"
if [ -z "$VERSION" ]; then
	echo "usage: $0 version [revision]" >/dev/stderr
	echo "   Default revision is 1" >/dev/stderr
	exit 255
fi


echo "ASSUMING:"
echo "   - The “build_for_linux” script has been called and resulting binary is there: $BUILT_PRODUCT_PATH"
echo "   - The assets folders are “Public” and “Resources”"
echo "   - The destination folder for the assets is $DESTINATION_ASSETS_FOLDER"
echo "Note: If any of these assumption changes, either this script or the recipe.yaml (or both) will have to be modified."
echo


echo
echo "***** Generating full archive (with binary and assets)"
echo

temp_archive_path="$(mktemp -t "officectl.tar")"
trap "rm -f $temp_archive_path" EXIT
export COPYFILE_DISABLE=1; # Stops macOS’ tar for copying xattr
# Adding officectl binary to archive
cd "$BUILT_PRODUCT_DIR"
tar -cf "$temp_archive_path" "$BUILT_PRODUCT_NAME"
# Adding assets to archive
cd "$SCRIPT_DIR/.."
tar --exclude ".DS_Store" -rf "$temp_archive_path" "Public" "Resources"
# The variant below is the same as the line above but put the assets in an “assets” folder. Cannot be used correctly with mkdeb though :(
#tar --exclude ".DS_Store" -s ':\(.*\):assets/\1:g' -rf "$temp_archive_path" "Public" "Resources"

# Apparently mkdeb does not support uncompressed tar files
tar -cjf "$temp_archive_path.tar.bz2" @"$temp_archive_path"
#tar tf "$temp_archive_path.tar.bz2"
rm -f "$temp_archive_path"
trap "rm -f $temp_archive_path.tar.bz2" EXIT


echo
echo "***** Running mkdeb"
echo

# Running mkdeb
cd "$LINUX_BUILD_PRODUCTS_DIR"
mkdeb build --revision "$REVISION" --from "$temp_archive_path.tar.bz2" --recipe "$SCRIPT_DIR/zz_assets/mkdeb" officectl:amd64="$VERSION"
