#!/bin/zsh
# Runs SlimCityCore build + tests with SwiftPM configured to work inside the
# Kiro sandbox:
#   - caches redirected into a workspace-local .swiftpm-home (the default
#     ~/Library/org.swift.swiftpm location is not writable under the sandbox)
#   - --disable-sandbox so SwiftPM does not try to nest its own sandbox-exec
#     inside the Kiro sandbox (which fails with "sandbox_apply: Operation not
#     permitted")
#
# Usage:
#   ./scripts/test.sh          # build + test
#   ./scripts/test.sh build    # build only
set -euo pipefail

cd "$(dirname "$0")/.."

SWIFTPM_HOME="$PWD/.swiftpm-home"
mkdir -p "$SWIFTPM_HOME/cache" "$SWIFTPM_HOME/config" "$SWIFTPM_HOME/security"

FLAGS=(
  --cache-path "$SWIFTPM_HOME/cache"
  --config-path "$SWIFTPM_HOME/config"
  --security-path "$SWIFTPM_HOME/security"
  --disable-sandbox
)

if [[ "${1:-}" == "build" ]]; then
  exec swift build "${FLAGS[@]}"
else
  exec swift test "${FLAGS[@]}"
fi
