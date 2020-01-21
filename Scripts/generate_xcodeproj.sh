#!/bin/bash
set -e

cd "$(dirname "$0")/.."
swift package generate-xcodeproj --xcconfig-overrides "./Configs/Package.xcconfig"
