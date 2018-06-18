#!/bin/bash

cd "$(dirname "$0")"
swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12"
