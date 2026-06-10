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
#   PAL_BASE_URL=https://pal.example.com \
#   PAL_PROVISIONING_KEY=secret \
#     ./scripts/build_ipa.sh               # point at a real Loop Pal backend
#
set -euo pipefail

# Homebrew flutter isn't always on PATH in non-login shells.
export PATH="/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="build/ios/iphoneos/Runner.app"
OUT_DIR="build/altstore"

DEFINES=()
if [[ -n "${PAL_BASE_URL:-}" ]]; then
  DEFINES+=(--dart-define=PAL_BASE_URL="$PAL_BASE_URL")
  echo "==> Backend: $PAL_BASE_URL"
  [[ -n "${PAL_PROVISIONING_KEY:-}" ]] && \
    DEFINES+=(--dart-define=PAL_PROVISIONING_KEY="$PAL_PROVISIONING_KEY")
else
  echo "==> Backend: standalone / mock (no PAL_BASE_URL set)"
fi

echo "==> flutter pub get"
flutter pub get >/dev/null

echo "==> Building unsigned release (this takes a few minutes)..."
flutter build ios --release --no-codesign "${DEFINES[@]}"

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
