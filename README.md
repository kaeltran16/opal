# Opal

One app for money, movement, and the little rituals that hold your day together.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Sideloading to a physical iPhone (AltStore / SideStore)

The iOS-native features (Live Activities, App Intents/Siri, local notifications)
only run on a real device. Opal signs cleanly with a **free Apple ID** — it
declares no App Groups and no special entitlements, and the HealthKit
entitlement is intentionally omitted (HealthKit needs a paid account; the
service degrades gracefully without it).

Build an unsigned release `.ipa`:

```bash
./scripts/build_ipa.sh                 # standalone / mock backend (default)

# or point at a real Loop Pal backend:
PAL_BASE_URL=https://pal.example.com PAL_PROVISIONING_KEY=secret \
  ./scripts/build_ipa.sh
```

Output: `build/altstore/Opal.ipa`. AltStore/SideStore re-signs it with your
Apple ID at install time. AirDrop the `.ipa` to the phone → open in AltStore,
or AltStore → My Apps → "+" → pick the file.

Notes:
- The deployment target is **iOS 26.0**; the device must be on iOS 26+.
- Enable **Settings → Privacy & Security → Developer Mode** on first install.
- Free-signed apps expire after **7 days** and need re-signing (AltStore
  auto-refreshes over Wi-Fi while AltServer runs; SideStore refreshes on-device
  without a computer).
