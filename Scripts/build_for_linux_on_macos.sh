#!/bin/bash

set -e

readonly OFFICECTL_BUILDER_IMAGE_NAME="officectl-builder:latest"

readonly SCRIPT_DIR="$(pwd)/$(dirname "$0")"
readonly ASSETS_DIR="$SCRIPT_DIR/zz_assets"

readonly treeish="$1"

cd "$SCRIPT_DIR/.."


if [ "$(uname)" != "Darwin" ]; then
	echo "This script should be run on macOS" >/dev/stderr
	exit 1
fi


docker build -t "$OFFICECTL_BUILDER_IMAGE_NAME" "$ASSETS_DIR"

echo
echo
echo
echo "*** Building officectl with treeish ${treeish:-<none, just merging current upstream if possible>}."
echo

BUILD_FOLDER_PATH="$(pwd)/linux_build"
docker run --rm -v "$BUILD_FOLDER_PATH":"/mnt/output" "$OFFICECTL_BUILDER_IMAGE_NAME" "https://github.com/happn-tech/officectl.git=$treeish"
