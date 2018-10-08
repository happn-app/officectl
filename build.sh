#!/bin/bash

cd "$(dirname "$0")"
swift build -c release -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.13" --static-swift-stdlib
