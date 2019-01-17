#!/bin/bash

set -e

readonly OFFICECTL_BUILDER_IMAGE_NAME="officectl-builder:latest"

readonly SCRIPT_DIR="$(pwd)/$(dirname "$0")"
readonly ASSETS_DIR="$SCRIPT_DIR/zz_assets"
readonly ASK_PASS_PATH="$SCRIPT_DIR/ask_pass.sh"

readonly treeish="$1"

cd "$SCRIPT_DIR/.."


if [ "$(uname)" != "Darwin" ]; then
	echo "This script should be run on macOS" >/dev/stderr
	exit 1
fi

if [ ! -x "$ASK_PASS_PATH" ]; then
	echo "$ASK_PASS_PATH: executable not found (needed to input the password of the ssh key; can be an empty script if key does not have a password)." >/dev/stderr
	exit 1
fi


docker build -t "$OFFICECTL_BUILDER_IMAGE_NAME" "$ASSETS_DIR"

echo
echo
echo
echo "*** Building officectl with treeish ${treeish:-<none, just merging current upstream if possible>}."
echo

BUILD_FOLDER_PATH="$(pwd)/linux_build"
docker run --rm -v "$BUILD_FOLDER_PATH":"/mnt/output" -v "$HOME/.ssh/id_rsa":"/root/.ssh/id_rsa" -v "$ASK_PASS_PATH":"/usr/local/bin/ask_pass.sh" -e SSH_ASKPASS="/usr/local/bin/ask_pass.sh" -e DISPLAY="dummy" "$OFFICECTL_BUILDER_IMAGE_NAME" "git@github.com:happn-app/officectl.git=$treeish"
