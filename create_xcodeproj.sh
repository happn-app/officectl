#!/bin/bash

cd "$(dirname "$0")"

swift package generate-xcodeproj --xcconfig-overrides ./Package.xcconfig
