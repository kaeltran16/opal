# iOS Rings Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Medium (4×2) iOS home-screen widget showing today's three activity rings plus a "+" that deep-links to the Pal composer.

**Architecture:** A custom `MethodChannel('opal/widget_sync')` mirrors the existing `LiveActivityService` seam: Dart pushes today's snapshot, a Swift bridge in Runner writes it to a shared App Group and reloads WidgetKit, and the widget's `TimelineProvider` reads the same App Group. Deep links reuse the existing generic `opal://<host>` → `/<host>` routing — no native routing change.

**Tech Stack:** Flutter, Riverpod 3 (codegen), drift; Swift / SwiftUI / WidgetKit; `xcodeproj` Ruby gem for project wiring.

**Platform note:** Tasks 1–2 (Dart) run and test on any OS. Tasks 3–7 author text on any OS but **must be built/run on macOS + Xcode** (iOS toolchain). Each task is tagged `[any OS]` or `[macOS to build]`.

---

## File Structure

- `lib/services/widget_sync/widget_sync_service.dart` — `WidgetSyncService` interface, `NoopWidgetSyncService`, `MethodChannelWidgetSyncService`, and the pure `widgetSyncPayload(TodayState)` mapping.
- `lib/controllers/widget_sync_controller.dart` — `WidgetSyncController` (keepAlive) listening to `todayStateProvider`.
- `lib/controllers/providers.dart` — add `widgetSyncServiceProvider` (edit).
- `lib/app.dart` — instantiate the controller on launch (edit).
- `ios/OpalWidgets/OpalRingsSnapshot.swift` — App Group id + keys + `RingsSnapshot` model (shared: both targets).
- `ios/OpalWidgets/OpalRingsWidget.swift` — `Widget` + `TimelineProvider` + SwiftUI views.
- `ios/OpalWidgets/OpalWidgetsBundle.swift` — register the new widget (edit).
- `ios/Runner/Widgets/OpalWidgetSyncBridge.swift` — `opal/widget_sync` channel handler.
- `ios/Runner/AppDelegate.swift` — register the bridge (edit).
- `ios/Runner/Runner.entitlements`, `ios/OpalWidgets/OpalWidgets.entitlements` — App Group capability.
- `ios/configure_native_targets.rb` — register new Swift files + entitlements (edit).
- Tests: `test/services/widget_sync_service_test.dart`, `test/controllers/widget_sync_controller_test.dart`.

---

## Task 1: Dart WidgetSyncService + payload  `[any OS]`

**Files:**
- Create: `lib/services/widget_sync/widget_sync_service.dart`
- Test: `test/services/widget_sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/widget_sync_service_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/models/enums.dart';
import 'package:opal/models/goals.dart';
import 'package:opal/models/entry.dart';
import 'package:opal/services/widget_sync/widget_sync_service.dart';

TodayState _sampleState() => TodayState(
      entries: [
        Entry(id: '1', timestamp: DateTime(2026, 6, 11, 9), type: EntryType.money, title: 'Coffee', amount: -42.0, source: EntrySource.manual),
        Entry(id: '2', timestamp: DateTime(2026, 6, 11, 10), type: EntryType.move, title: 'Walk', duration: 18, source: EntrySource.manual),
        Entry(id: '3', timestamp: DateTime(2026, 6, 11, 8), type: EntryType.rituals, title: 'Meditate', source: EntrySource.manual),
        Entry(id: '4', timestamp: DateTime(2026, 6, 11, 8), type: EntryType.rituals, title: 'Journal', source: EntrySource.manual),
        Entry(id: '5', timestamp: DateTime(2026, 6, 11, 8), type: EntryType.rituals, title: 'Stretch', source: EntrySource.manual),
      ],
      goals: const Goals(dailyBudget: 60, dailyMoveMinutes: 40, dailyRitualTarget: 5),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widgetSyncPayload maps TodayState to the channel payload', () {
    final p = widgetSyncPayload(_sampleState());
    expect(p['moneyRing'], closeTo(0.7, 1e-9));
    expect(p['moveRing'], closeTo(0.45, 1e-9));
    expect(p['ritualsRing'], closeTo(0.6, 1e-9));
    expect(p['moneySpent'], 42.0);
    expect(p['dailyBudget'], 60.0);
    expect(p['moveMinutes'], 18);
    expect(p['dailyMoveMinutes'], 40);
    expect(p['ritualsDone'], 3);
    expect(p['dailyRitualTarget'], 5);
  });

  test('widgetSyncPayload sends 0 ring fraction when goal is 0', () {
    final s = TodayState(entries: const [], goals: const Goals(dailyBudget: 0, dailyMoveMinutes: 0, dailyRitualTarget: 0));
    final p = widgetSyncPayload(s);
    expect(p['moneyRing'], 0);
    expect(p['moveRing'], 0);
    expect(p['ritualsRing'], 0);
  });

  test('MethodChannelWidgetSyncService.sync invokes opal/widget_sync', () async {
    const channel = MethodChannel('opal/widget_sync');
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await const MethodChannelWidgetSyncService().sync(_sampleState());
    expect(captured?.method, 'sync');
    expect((captured?.arguments as Map)['ritualsDone'], 3);
  });

  test('MethodChannelWidgetSyncService.sync swallows MissingPluginException', () async {
    // No mock handler registered -> MissingPluginException; must not throw.
    await const MethodChannelWidgetSyncService().sync(_sampleState());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/widget_sync_service_test.dart`
Expected: FAIL — `widget_sync_service.dart` / `widgetSyncPayload` not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/services/widget_sync/widget_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../controllers/today_controller.dart';

/// Pushes today's progress snapshot to the iOS home-screen rings widget.
///
/// Mirrors the [LiveActivityService] seam: a thin Dart wrapper over the native
/// `opal/widget_sync` [MethodChannel]. The Swift side writes the values to the
/// shared App Group and asks WidgetKit to reload. No-op everywhere off iOS.
abstract interface class WidgetSyncService {
  /// Serializes [state] and pushes it to the widget. Safe to call often; a
  /// failed sync never throws (the widget keeps its last snapshot).
  Future<void> sync(TodayState state);
}

/// The exact channel payload for [state]. Pure + public so it is unit-testable
/// without a platform channel. Fractions are pre-computed (the widget does no
/// math), matching [TodayState]'s zero-goal guards.
Map<String, dynamic> widgetSyncPayload(TodayState state) => <String, dynamic>{
      'moneyRing': state.moneyRing,
      'moveRing': state.moveRing,
      'ritualsRing': state.ritualsRing,
      'moneySpent': state.moneySpent,
      'dailyBudget': state.goals.dailyBudget,
      'moveMinutes': state.moveMinutes,
      'dailyMoveMinutes': state.goals.dailyMoveMinutes,
      'ritualsDone': state.ritualsDone,
      'dailyRitualTarget': state.goals.dailyRitualTarget,
    };

/// No-op for non-iOS platforms, web, and tests.
class NoopWidgetSyncService implements WidgetSyncService {
  const NoopWidgetSyncService();

  @override
  Future<void> sync(TodayState state) async {}
}

/// iOS-backed impl over the `opal/widget_sync` [MethodChannel]. Any
/// [PlatformException] / [MissingPluginException] is swallowed so a failed sync
/// never breaks the app — it degrades to the no-op behaviour.
class MethodChannelWidgetSyncService implements WidgetSyncService {
  const MethodChannelWidgetSyncService({
    MethodChannel channel = const MethodChannel('opal/widget_sync'),
    // ignore: prefer_initializing_formals
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> sync(TodayState state) async {
    try {
      await _channel.invokeMethod<void>('sync', widgetSyncPayload(state));
    } on PlatformException catch (e) {
      debugPrint('WidgetSync.sync failed: ${e.message}');
    } on MissingPluginException {
      // No native side (non-iOS) — ignore.
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/widget_sync_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/widget_sync/widget_sync_service.dart test/services/widget_sync_service_test.dart
git commit -m "feat(widget): add WidgetSyncService + payload mapping"
```

---

## Task 2: Provider + controller wiring  `[any OS]`

**Files:**
- Create: `lib/controllers/widget_sync_controller.dart`
- Modify: `lib/controllers/providers.dart` (after the `liveActivityService` provider, ~line 291)
- Modify: `lib/app.dart` (`initState`, after the existing `ref.read(siriShortcutsServiceProvider)` line)
- Test: `test/controllers/widget_sync_controller_test.dart`

- [ ] **Step 1: Add the service provider in `providers.dart`**

Add after the `liveActivityService` provider:

```dart
/// Pushes today's progress to the iOS home-screen rings widget over the native
/// `opal/widget_sync` MethodChannel; no-op off iOS. See [WidgetSyncController].
@Riverpod(keepAlive: true)
WidgetSyncService widgetSyncService(Ref ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return const MethodChannelWidgetSyncService();
  }
  return const NoopWidgetSyncService();
}
```

Add the import near the other service imports at the top of `providers.dart`:

```dart
import '../services/widget_sync/widget_sync_service.dart';
```

- [ ] **Step 2: Create the controller**

```dart
// lib/controllers/widget_sync_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers.dart';
import 'today_controller.dart';

part 'widget_sync_controller.g.dart';

/// Keeps the iOS rings widget in sync with today's progress. Listens to
/// [todayStateProvider] and pushes each new snapshot to [WidgetSyncService].
/// Has no UI surface; instantiated once at app start (see `app.dart`).
@Riverpod(keepAlive: true)
class WidgetSyncController extends _$WidgetSyncController {
  @override
  void build() {
    final service = ref.watch(widgetSyncServiceProvider);
    ref.listen(todayStateProvider, (_, next) {
      final state = next.asData?.value;
      if (state != null) service.sync(state);
    }, fireImmediately: true);
  }
}
```

- [ ] **Step 3: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `providers.g.dart` and creates `widget_sync_controller.g.dart`; no errors.

- [ ] **Step 4: Write the failing controller test**

```dart
// test/controllers/widget_sync_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/controllers/today_controller.dart';
import 'package:opal/controllers/widget_sync_controller.dart';
import 'package:opal/models/goals.dart';
import 'package:opal/services/widget_sync/widget_sync_service.dart';

class _FakeWidgetSync implements WidgetSyncService {
  final calls = <TodayState>[];
  @override
  Future<void> sync(TodayState state) async => calls.add(state);
}

void main() {
  test('pushes each todayState emission to the service', () async {
    final fake = _FakeWidgetSync();
    final state = TodayState(entries: const [], goals: const Goals());
    final container = ProviderContainer(overrides: [
      widgetSyncServiceProvider.overrideWithValue(fake),
      todayStateProvider.overrideWith((ref) => Stream.value(state)),
    ]);
    addTearDown(container.dispose);

    container.read(widgetSyncControllerProvider); // instantiate -> sets listener
    await container.read(todayStateProvider.future); // drive the stream
    await Future<void>.delayed(Duration.zero); // let the listener microtask run

    expect(fake.calls, [state]);
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/controllers/widget_sync_controller_test.dart`
Expected: PASS. (If it fails on `overrideWithValue` for the generated provider, confirm codegen in Step 3 succeeded.)

- [ ] **Step 6: Instantiate the controller at app start in `app.dart`**

In `initState`, immediately after `final siri = ref.read(siriShortcutsServiceProvider);` and its `listen`, add:

```dart
// Start the rings-widget sync loop (listens to todayState internally).
ref.read(widgetSyncControllerProvider);
```

If not already imported, add at the top of `app.dart`:

```dart
import 'controllers/widget_sync_controller.dart';
```

- [ ] **Step 7: Verify the suite still passes + commit**

Run: `flutter test`
Expected: full suite PASS.

```bash
git add lib/controllers/widget_sync_controller.dart lib/controllers/widget_sync_controller.g.dart lib/controllers/providers.dart lib/controllers/providers.g.dart lib/app.dart test/controllers/widget_sync_controller_test.dart
git commit -m "feat(widget): drive rings-widget sync from todayState"
```

---

## Task 3: Shared RingsSnapshot model (Swift)  `[macOS to build]`

**Files:**
- Create: `ios/OpalWidgets/OpalRingsSnapshot.swift`

- [ ] **Step 1: Write the shared snapshot model**

```swift
//  OpalRingsSnapshot.swift
//  Shared by Runner (writer) and OpalWidgets (reader) via the App Group.

import Foundation

/// Shared App Group identifier — must match the entitlement on BOTH the Runner
/// app and the OpalWidgets extension.
let opalAppGroupId = "group.com.opal.opal"

/// Today's progress the rings widget renders. Written by the app
/// (OpalWidgetSyncBridge) and read by the widget's TimelineProvider, both via
/// the shared App Group UserDefaults. Compiled into both targets.
struct RingsSnapshot {
  var moneyRing: Double
  var moveRing: Double
  var ritualsRing: Double
  var moneySpent: Double
  var dailyBudget: Double
  var moveMinutes: Int
  var dailyMoveMinutes: Int
  var ritualsDone: Int
  var dailyRitualTarget: Int

  /// Zeroed snapshot for "no data yet" (fresh install / unprovisioned group).
  static let empty = RingsSnapshot(
    moneyRing: 0, moveRing: 0, ritualsRing: 0,
    moneySpent: 0, dailyBudget: 0,
    moveMinutes: 0, dailyMoveMinutes: 0,
    ritualsDone: 0, dailyRitualTarget: 0)

  private enum Key {
    static let moneyRing = "moneyRing"
    static let moveRing = "moveRing"
    static let ritualsRing = "ritualsRing"
    static let moneySpent = "moneySpent"
    static let dailyBudget = "dailyBudget"
    static let moveMinutes = "moveMinutes"
    static let dailyMoveMinutes = "dailyMoveMinutes"
    static let ritualsDone = "ritualsDone"
    static let dailyRitualTarget = "dailyRitualTarget"
    static let hasData = "hasData"
  }

  private static var store: UserDefaults? { UserDefaults(suiteName: opalAppGroupId) }

  /// Persists to the shared group; no-op if the group is unavailable.
  func save() {
    guard let d = Self.store else { return }
    d.set(moneyRing, forKey: Key.moneyRing)
    d.set(moveRing, forKey: Key.moveRing)
    d.set(ritualsRing, forKey: Key.ritualsRing)
    d.set(moneySpent, forKey: Key.moneySpent)
    d.set(dailyBudget, forKey: Key.dailyBudget)
    d.set(moveMinutes, forKey: Key.moveMinutes)
    d.set(dailyMoveMinutes, forKey: Key.dailyMoveMinutes)
    d.set(ritualsDone, forKey: Key.ritualsDone)
    d.set(dailyRitualTarget, forKey: Key.dailyRitualTarget)
    d.set(true, forKey: Key.hasData)
  }

  /// Reads the latest snapshot, or `.empty` if nothing has been written yet.
  static func load() -> RingsSnapshot {
    guard let d = store, d.bool(forKey: Key.hasData) else { return .empty }
    return RingsSnapshot(
      moneyRing: d.double(forKey: Key.moneyRing),
      moveRing: d.double(forKey: Key.moveRing),
      ritualsRing: d.double(forKey: Key.ritualsRing),
      moneySpent: d.double(forKey: Key.moneySpent),
      dailyBudget: d.double(forKey: Key.dailyBudget),
      moveMinutes: d.integer(forKey: Key.moveMinutes),
      dailyMoveMinutes: d.integer(forKey: Key.dailyMoveMinutes),
      ritualsDone: d.integer(forKey: Key.ritualsDone),
      dailyRitualTarget: d.integer(forKey: Key.dailyRitualTarget))
  }
}
```

- [ ] **Step 2: Commit** (compiles only after Task 6 wires it into the targets)

```bash
git add ios/OpalWidgets/OpalRingsSnapshot.swift
git commit -m "feat(widget): shared RingsSnapshot App Group model"
```

---

## Task 4: Native sync bridge (Swift, Runner)  `[macOS to build]`

**Files:**
- Create: `ios/Runner/Widgets/OpalWidgetSyncBridge.swift`
- Modify: `ios/Runner/AppDelegate.swift` (inside the `if let registrar` block, after `OpalIntentsBridge.shared.register(...)`)

- [ ] **Step 1: Write the bridge**

```swift
//  OpalWidgetSyncBridge.swift
//  Runner — receives today's progress over `opal/widget_sync`, writes it to the
//  shared App Group, and reloads WidgetKit. Mirrors OpalLiveActivityBridge.

import Flutter
import Foundation
import WidgetKit

enum OpalWidgetSyncBridge {
  static let channelName = "opal/widget_sync"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "sync":
        guard let a = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "expected map", details: nil))
          return
        }
        RingsSnapshot(
          moneyRing: a["moneyRing"] as? Double ?? 0,
          moveRing: a["moveRing"] as? Double ?? 0,
          ritualsRing: a["ritualsRing"] as? Double ?? 0,
          moneySpent: a["moneySpent"] as? Double ?? 0,
          dailyBudget: a["dailyBudget"] as? Double ?? 0,
          moveMinutes: a["moveMinutes"] as? Int ?? 0,
          dailyMoveMinutes: a["dailyMoveMinutes"] as? Int ?? 0,
          ritualsDone: a["ritualsDone"] as? Int ?? 0,
          dailyRitualTarget: a["dailyRitualTarget"] as? Int ?? 0
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
```

- [ ] **Step 2: Register it in AppDelegate**

In `didInitializeImplicitFlutterEngine`, inside the existing `if let registrar = pluginRegistry.registrar(forPlugin: "OpalNativeBridges")` block, after the two existing `register` calls, add:

```swift
      OpalWidgetSyncBridge.register(with: messenger)
```

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Widgets/OpalWidgetSyncBridge.swift ios/Runner/AppDelegate.swift
git commit -m "feat(widget): native opal/widget_sync bridge"
```

---

## Task 5: The rings widget (Swift, OpalWidgets)  `[macOS to build]`

**Files:**
- Create: `ios/OpalWidgets/OpalRingsWidget.swift`
- Modify: `ios/OpalWidgets/OpalWidgetsBundle.swift`

- [ ] **Step 1: Write the widget**

```swift
//  OpalRingsWidget.swift
//  OpalWidgets — Medium home-screen widget: three activity rings + "+" FAB.

import SwiftUI
import WidgetKit

// Tracker hues (match the Flutter side: money #FF9500, move #34C759, rituals #AF52DE).
private let moneyColor = Color(red: 1.0, green: 149.0 / 255.0, blue: 0.0)
private let moveColor = Color(red: 52.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0)
private let ritualsColor = Color(red: 175.0 / 255.0, green: 82.0 / 255.0, blue: 222.0 / 255.0)
private let fabColor = Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0)

struct RingsEntry: TimelineEntry {
  let date: Date
  let snapshot: RingsSnapshot
}

struct RingsProvider: TimelineProvider {
  func placeholder(in context: Context) -> RingsEntry {
    RingsEntry(date: Date(), snapshot: .empty)
  }
  func getSnapshot(in context: Context, completion: @escaping (RingsEntry) -> Void) {
    completion(RingsEntry(date: Date(), snapshot: RingsSnapshot.load()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<RingsEntry>) -> Void) {
    // Single entry; the app pushes reloads when data changes, so never auto-refresh.
    let entry = RingsEntry(date: Date(), snapshot: RingsSnapshot.load())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

private struct Ring: View {
  let fraction: Double
  let color: Color
  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(0.2), lineWidth: 11)
      Circle()
        .trim(from: 0, to: min(max(fraction, 0), 1))
        .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

private struct RingsStack: View {
  let s: RingsSnapshot
  var body: some View {
    ZStack {
      Ring(fraction: s.moneyRing, color: moneyColor)
      Ring(fraction: s.moveRing, color: moveColor).padding(14)
      Ring(fraction: s.ritualsRing, color: ritualsColor).padding(28)
    }
  }
}

private struct StatRow: View {
  let color: Color
  let value: String
  let suffix: String
  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(value).font(.system(size: 14, weight: .semibold))
      Text(suffix).font(.system(size: 12)).foregroundStyle(.secondary)
    }
  }
}

struct RingsWidgetView: View {
  let entry: RingsEntry
  var body: some View {
    let s = entry.snapshot
    ZStack(alignment: .bottomTrailing) {
      HStack(spacing: 14) {
        RingsStack(s: s).frame(width: 92, height: 92)
        VStack(alignment: .leading, spacing: 8) {
          StatRow(color: moneyColor, value: "$\(Int(s.moneySpent))", suffix: "/ $\(Int(s.dailyBudget)) spent")
          StatRow(color: moveColor, value: "\(s.moveMinutes)", suffix: "/ \(s.dailyMoveMinutes) min")
          StatRow(color: ritualsColor, value: "\(s.ritualsDone)", suffix: "/ \(s.dailyRitualTarget) rituals")
        }
        Spacer()
      }
      .padding(16)

      // The "+" FAB: opens the autofocused Pal composer via deep link.
      Link(destination: URL(string: "opal://pal-composer")!) {
        Image(systemName: "plus")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 38, height: 38)
          .background(Circle().fill(fabColor))
      }
      .padding(12)
    }
    // Tapping anywhere else opens Today.
    .widgetURL(URL(string: "opal://today"))
  }
}

struct OpalRingsWidget: Widget {
  let kind = "OpalRingsWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RingsProvider()) { entry in
      RingsWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Opal Today")
    .description("Your money, move, and rituals progress.")
    .supportedFamilies([.systemMedium])
  }
}
```

- [ ] **Step 2: Register the widget in the bundle**

In `ios/OpalWidgets/OpalWidgetsBundle.swift`, add `OpalRingsWidget()` to `body`:

```swift
  var body: some Widget {
    OpalWorkoutLiveActivity()
    OpalRingsWidget()
  }
```

- [ ] **Step 3: Commit**

```bash
git add ios/OpalWidgets/OpalRingsWidget.swift ios/OpalWidgets/OpalWidgetsBundle.swift
git commit -m "feat(widget): medium rings widget with + FAB"
```

---

## Task 6: App Group entitlements + project wiring  `[macOS to build]`

**Files:**
- Create: `ios/Runner/Runner.entitlements`
- Create: `ios/OpalWidgets/OpalWidgets.entitlements`
- Modify: `ios/configure_native_targets.rb`

- [ ] **Step 1: Create `ios/Runner/Runner.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.opal.opal</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Create `ios/OpalWidgets/OpalWidgets.entitlements`** (identical contents)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.opal.opal</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 3: Register the new Swift files in `configure_native_targets.rb`**

In the B1 section, after the four existing `add_source(... runner)` lines (after line 59), add a `Widgets` group for the Runner bridge:

```ruby
widgets_group = group_at(runner_group, 'Widgets')
add_source(project, widgets_group, 'OpalWidgetSyncBridge.swift', runner)
```

In the B2 section, after the existing `add_source(project, widget_group, 'OpalWidgetsBundle.swift', widget)` line (after line 74), add the widget view and the shared snapshot (snapshot is a member of BOTH targets):

```ruby
add_source(project, widget_group, 'OpalRingsWidget.swift', widget)
snapshot_ref = add_source(project, widget_group, 'OpalRingsSnapshot.swift', widget)
unless runner.source_build_phase.files_references.include?(snapshot_ref)
  runner.source_build_phase.add_file_reference(snapshot_ref)
end
```

- [ ] **Step 4: Wire the entitlements build settings in `configure_native_targets.rb`**

After the `runner` target is fetched (after line 26), add:

```ruby
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
```

Inside the existing `widget.build_configurations.each do |config|` loop (after line 84's `s = config.build_settings`), add:

```ruby
  s['CODE_SIGN_ENTITLEMENTS'] = 'OpalWidgets/OpalWidgets.entitlements'
```

- [ ] **Step 5: Run the wiring script (macOS)**

Run: `cd ios && ruby configure_native_targets.rb`
Expected: prints `OK — saved Runner.xcodeproj`; the "Widget sources" line lists `OpalRingsSnapshot.swift, OpalRingsWidget.swift, OpalWidgetsBundle.swift, OpalWorkoutLiveActivity.swift`; the "Runner sources" line includes `OpalRingsSnapshot.swift` and `OpalWidgetSyncBridge.swift`.

- [ ] **Step 6: Build to confirm everything compiles (macOS)**

Run: `flutter build ios --debug --no-codesign`
Expected: build succeeds. (If signing blocks the App Group on a free Personal Team, see the Caveat below; for a no-codesign build the entitlement is not validated.)

- [ ] **Step 7: Commit**

```bash
git add ios/Runner/Runner.entitlements ios/OpalWidgets/OpalWidgets.entitlements ios/configure_native_targets.rb ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore(ios): wire rings widget targets + App Group entitlements"
```

---

## Task 7: Manual verification (simulator)  `[macOS to build]`

No automated coverage exists for WidgetKit rendering (consistent with the Live Activity). Verify by hand on the iOS Simulator.

- [ ] **Step 1:** `flutter run` on an iOS Simulator. Log a money expense, a move entry, and a ritual in the app.
- [ ] **Step 2:** Add the **Opal Today** Medium widget to the home screen. Confirm the rings reflect the logged progress and the three numeric rows match the app's Today screen.
- [ ] **Step 3:** Log another entry in the app; background it; confirm the widget updates (within WidgetKit's reload latency).
- [ ] **Step 4:** Tap the **"+"** → app opens on the Pal composer with the keyboard up.
- [ ] **Step 5:** Tap anywhere on the rings/stats area → app opens on Today.
- [ ] **Step 6:** Fresh-install case: delete the app, re-add the widget before opening the app → widget shows empty rings and "$0 / $0", no crash.

---

## Caveat: App Group provisioning

Same family as the HealthKit note in `configure_native_targets.rb`: a **free Apple Personal Team may not provision App Groups for on-device builds**, which would break device signing. Mitigations, in order of preference:
1. Use a paid Apple Developer account (App Groups provision normally).
2. Develop against the **Simulator**, where the App Group works without provisioning.
3. If neither is available and device signing breaks, the rings render but stay at the placeholder/empty snapshot (the bridge's `UserDefaults(suiteName:)` returns nil and `save()`/`load()` no-op) — the app itself is unaffected.

---

## Self-review notes

- **Spec coverage:** rings snapshot (T5), "+" → composer (T5 Link + existing routing), rings tap → Today (T5 widgetURL), data flow (T1/T2/T3/T4), App Group (T6), edge cases — empty/zero-goal (T3 `.empty`, T1 zero-goal test), sync-failure swallow (T1), provisioning caveat (documented). All covered.
- **Type consistency:** payload keys in `widgetSyncPayload` (T1) === bridge reads in `OpalWidgetSyncBridge` (T4) === `RingsSnapshot` fields (T3) === widget reads (T5). Verified key-by-key.
- **No placeholders:** all steps carry real code/commands.
