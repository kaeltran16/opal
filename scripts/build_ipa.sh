#!/usr/bin/env bash
#
# Build an UNSIGNED release .ipa of Opal for sideloading via AltStore / SideStore.
#
# AltStore re-signs the .ipa with your own (free) Apple ID at install time, so we
# deliberately build with codesigning disabled here. No paid Apple Developer
# account or DEVELOPMENT_TEAM is required.
#
# Output: build/altstore/Opal.ipa
#
# Usage:
#   ./scripts/build_ipa.sh                 # standalone / mock backend (default)
#
#   # point at a real Loop Pal backend, via individual env vars:
#   PAL_BASE_URL=https://pal.example.com \
#   PAL_PROVISIONING_KEY=secret \
#     ./scripts/build_ipa.sh
#
#   # ...or via a --dart-define-from-file JSON (same format Flutter expects),
#   # e.g. dart_defines/prod.json: {"PAL_BASE_URL": "...", "PAL_PROVISIONING_KEY": "..."}
#   ./scripts/build_ipa.sh dart_defines/prod.json
#   PAL_CONFIG=dart_defines/prod.json ./scripts/build_ipa.sh
#
# If both are given, env vars are applied last and override file values.
#
set -euo pipefail

# Homebrew flutter isn't always on PATH in non-login shells.
export PATH="/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="build/ios/iphoneos/Runner.app"
OUT_DIR="build/altstore"

DEFINES=()

# A --dart-define-from-file JSON, from the first arg or $PAL_CONFIG.
CONFIG_FILE="${1:-${PAL_CONFIG:-}}"
if [[ -n "$CONFIG_FILE" ]]; then
  [[ -f "$CONFIG_FILE" ]] || { echo "Config file not found: $CONFIG_FILE" >&2; exit 1; }
  DEFINES+=(--dart-define-from-file="$CONFIG_FILE")
  echo "==> Config: $CONFIG_FILE"
fi

# Individual env vars; applied after the file so they override its values.
if [[ -n "${PAL_BASE_URL:-}" ]]; then
  DEFINES+=(--dart-define=PAL_BASE_URL="$PAL_BASE_URL")
  echo "==> Backend: $PAL_BASE_URL"
  [[ -n "${PAL_PROVISIONING_KEY:-}" ]] && \
    DEFINES+=(--dart-define=PAL_PROVISIONING_KEY="$PAL_PROVISIONING_KEY")
elif [[ -z "$CONFIG_FILE" ]]; then
  echo "==> Backend: standalone / mock (no PAL_BASE_URL or config file set)"
fi

echo "==> flutter pub get"
flutter pub get >/dev/null

echo "==> Building unsigned release (this takes a few minutes)..."
flutter build ios --release --no-codesign ${DEFINES[@]+"${DEFINES[@]}"}

echo "==> Packaging .ipa"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
( cd "$OUT_DIR" && /usr/bin/zip -qr Opal.ipa Payload && rm -rf Payload )

echo ""
echo "✓ Built $ROOT/$OUT_DIR/Opal.ipa"
ls -lh "$OUT_DIR/Opal.ipa"
echo ""
echo "Next: open AltStore on your iPhone -> My Apps -> '+' -> pick Opal.ipa"
echo "(or drop it onto AltServer). AltStore signs it with your Apple ID."
