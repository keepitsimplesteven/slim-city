#!/bin/zsh
# Builds SlimCity for the paired iPhone, installs it, and launches it.
#
# Flags that make xcodebuild work inside the Kiro sandbox:
#   -IDEPackageSupportDisableManifestSandbox=1  SwiftPM manifest eval skips sandbox-exec
#   -skipMacroValidation                        trust the SwiftData macro plugin
#   OTHER_SWIFT_FLAGS=-disable-sandbox          compiler plugin server skips sandbox-exec
#   -clonedSourcePackagesDirPath/-derivedDataPath keep caches inside the workspace
#
# Usage: scripts/deploy-device.sh [DEVICE_UDID]
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${1:-00008140-000610C21093C01C}"
BUNDLE_ID="com.stevenalberspersonalteam.SlimCity"
DERIVED=".build-sim/device"

xcodebuild -project SlimCity/SlimCity.xcodeproj -scheme SlimCity \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  -clonedSourcePackagesDirPath .build-sim/spm \
  -IDEPackageSupportDisableManifestSandbox=1 \
  -skipMacroValidation \
  -allowProvisioningUpdates \
  OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' \
  build | tail -3

APP="$DERIVED/Build/Products/Debug-iphoneos/SlimCity.app"
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"
