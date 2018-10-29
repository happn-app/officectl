#!/bin/bash

cd "$(dirname "$0")"
swift build -c release -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.13" --static-swift-stdlib

# For the Linux version, on macOS:
#BUILD_FOLDER_PATH="/Volumes/Exchanges/DockerExchanges/officectlBuild"
#docker run --rm -v "$BUILD_FOLDER_PATH":/mnt/output -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)/ask_pass.sh":/usr/local/bin/ask_pass.sh -e SSH_ASKPASS=/usr/local/bin/ask_pass.sh -e DISPLAY=dummy eu.gcr.io/happn-infra/swift-builder:4.2-RELEASE "git@github.com:happn-app/officectl.git=master" zlib1g-dev libssl1.0-dev libldap2-dev pkg-config
