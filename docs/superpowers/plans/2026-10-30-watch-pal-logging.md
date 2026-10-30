# Watch Pal Logging Implementation Plan

> Bounded run, executed inline in this worktree. No subagents.

**Goal:** The Watch logs to Pal through the system text input. The phone runs the
text through the composer's `/v1/chat` path, saves it, refreshes the rings widget and
answers with what it saved. Undo on the Watch deletes it again.

**Effort:** effort:01df7794-d257-4f9e-b898-17ada571922c (chunk 16)
**UI:** `docs/design/watch-app/Main.dc.html` (8 screens, Apple Watch SE 3 44 mm)
**Settled before this plan (chunks 4-7, 16):** relay through the phone, wake the phone
app with `sendMessage`, a headless engine when no app engine is running, save straight
away with Undo, and drop the log with Not logged and Try again when the iPhone is out of
reach.

## Design decisions made here

1. **One Dart handler, two hosts.** A `WatchLog` class (`lib/controllers/watch_log.dart`)
   does chat -> `applyPalActions` -> reply map, and undo -> `reversePalAction`. The
   app engine and the headless engine bind the same handler to an `opal/watch`
   MethodChannel. Why: the composer and the Watch then log the same way, and the
   only difference between the hosts is what happens after a change (below).
2. **Plain `Provider`, not `@riverpod`, for `watchLogProvider`.** `applyPalActions`
   needs a `Ref`; a codegen provider needs a `.g.dart` whose hash is the sha1 of the
   analyzer's reprint of the source, which I can't produce without a Dart SDK, and a
   wrong one fails app.yml's codegen diff. A manual `Provider<WatchLog>(WatchLog.new)` is
   public Riverpod API with no generated file. It is the repo's first non-codegen
   provider; I'll flag it in the commit body.
3. **The phone formats, the Watch renders.** The reply carries display-ready strings
   (`title`, `item`, `amount`, `detail`, `bars`, `reply`) formatted in Dart with the
   user's currency, plus an opaque `undo` token. The Watch has no money or kcal logic.
   Layout rule: exactly one money/move/ritual entry -> Logged (screen 4); exactly one
   meal -> Meal logged (screen 5); no actions -> Pal answered (screen 7, no Undo);
   anything else (goal change, routine, several items) -> Pal answered with Undo.
4. **The undo token carries everything needed to reverse the turn**: the entry, meal and
   routine ids and the goal values to put back (one map per `AppliedAction`). Why: the
   engine that logged it may be gone by the time Undo arrives (headless engine torn down,
   or the user opened the app since), so nothing can live in memory.
5. **Wire keys** live in `OpalWatchMessage.swift` (shared by both Swift targets, as now)
   and are mirrored as constants in `watch_log.dart`; the Dart tests pin them. The ping
   placeholder (Watch button, `ping`/`pong` keys, phone handler) is removed: the log
   round trip replaces it.
6. **Native relay** `ios/Runner/Watch/OpalWatchRelay.swift` owns engine choice and
   timing; `OpalWatchSession` hands `log`/`undo` messages to it.
   - The app engine registers its channel in `didInitializeImplicitFlutterEngine`;
     the relay drops it on `UIScene.didDisconnectNotification` (the scene's engine dies
     with the scene).
   - App engine present -> forward to it. Otherwise start a headless
     `FlutterEngine(name:project:allowHeadlessExecution: true)` on the `watchMain`
     entrypoint, register `GeneratedPluginRegistrant` and `OpalWidgetSyncBridge` on it.
   - Each endpoint queues messages until Dart sends `ready`.
   - After a headless log/undo succeeds and an app engine is ready, the relay sends it
     `changed`.
   - The headless engine is torn down (`destroyContext`) when Dart sends `idle` and no
     request is pending.
7. **Headless vs app engine after a change.** Headless: Dart pushes the widget snapshot
   (`buildWidgetSnapshot` over today's state, as `WidgetSyncController` does), then sends
   `idle`. App engine: `WidgetSyncController` already pushes on the DB change, so the
   handler does nothing extra; on `changed` it calls `db.markTablesUpdated` so drift
   streams pick up the other connection's write.

## Risk 1: iOS background time against `/v1/chat` latency

- The relay holds `beginBackgroundTask` from the first message until no request is
  pending and no headless engine is alive (typically about 30 s; Apple doesn't promise a
  number).
- Dart bounds the chat call at 15 s (`_watchChatTimeout`; the composer uses 12 s, the
  Watch gets a little more because nobody is staring at a spinner on the phone).
- The relay answers the Watch "Your iPhone took too long" if Dart hasn't replied within
  25 s, and its expiration handler answers every pending request the same way, tears
  down the headless engine and ends the task. Each reply is sent once.
- Dart replies to the Watch right after the save. The widget push comes after the reply,
  so the Watch never waits on it.
- NSLog lines for engine start -> `ready` and request -> reply durations, so chunk 18 can
  read the real numbers off a device.
- Accepted: a late `generateRoutine` (only for "build me a routine" from the Watch) is not
  bounded by the 15 s chat cap; if it outlives the 25 s deadline the Watch says it failed
  while the routine still lands. Rare, and visible on the phone.

## Risk 2: two engines opening the same drift DB

- Avoided by default: the headless engine starts only when no app engine exists, and
  stops when idle.
- Overlap (the user opens the app mid-log) is two SQLite connections to one file in one
  process, which SQLite locking handles. `LoopDatabase` adds
  `DriftNativeOptions(setup:)` with `PRAGMA busy_timeout = 5000`, so a writer waits
  instead of failing with SQLITE_BUSY.
- The app engine's streams don't see the headless write; the `changed` nudge (decision 7)
  fixes that.
- Not used: drift_flutter's `shareAcrossIsolates`. It parks the DB in an isolate spawned by
  whichever engine opens it first; if that is the headless engine, tearing it down kills
  the app engine's connection.
- Accepted: if the first launch after an app update is a Watch log and the user opens the
  app within those seconds, both engines may try the schema migration. Same window as
  above, only after an update.

## Risk 3 (found while planning): the device token is unreadable while the phone is locked

`FlutterTokenSecureStore` uses `FlutterSecureStorage()` defaults, which on iOS are
`kSecAttrAccessibleWhenUnlocked`. A Watch log usually arrives with the phone locked in a
pocket, so the token read would fail and every such log would show Not logged.
- `FlutterTokenSecureStore` switches to `IOSOptions(accessibility: first_unlock)`.
- Existing tokens: in flutter_secure_storage 9.2.4 a read ignores accessibility, and a
  write with different accessibility deletes and re-adds the item. `DeviceTokenStore`
  re-saves a cached token once per process, so the first app launch after this ships
  moves it to after-first-unlock. A Watch log before that first launch still fails once.
- Re-registering is not a fallback: Pal memory (`pal_facts`) is keyed by the token.

## Tasks (in order)

### Task 1: Dart handler
**Files:** `lib/controllers/watch_log.dart`, `test/controllers/watch_log_test.dart`
- `WatchLog(Ref)`: `Future<Map<String, Object?>> log(String text)` and
  `Future<Map<String, Object?>> undo(Object? token)`; `watchLogProvider`.
- Failures become `{error: ...}`: unreachable -> "Pal couldn't reach the server",
  failed or timed out -> "Pal couldn't answer that just now". Empty text -> error, no call.
- Money detail: "Spending today $18.50 of $60", or "Spent today $18.50" with no budget,
  from `TodayState(...).moneySpent` over `getToday()` and `goals.get()`. Meal: title
  "Logged · <slot>" with the saved meal's slot, amount "140–160 kcal", detail the
  confidence label, `bars` 1-3.
- Tests (in-memory DB + fake Pal, as `pal_composer_controller_test.dart`): a money log
  saves the entry and replies item/amount/detail/undo; a meal log saves the meal and
  replies slot/kcal/confidence; a question replies `reply` with no `undo`; a goal change
  replies `reply` with `undo`; unreachable and timeout reply errors and save nothing;
  undo of a money log deletes the entry; undo of a goal change restores the old value;
  undo of an entry already deleted on the phone succeeds; a bad token replies an error.

### Task 2: Dart channel and entrypoints
**Files:** `lib/services/watch/watch_channel.dart`, `lib/main.dart`,
`lib/data/db/database.dart`, `test/services/watch_channel_test.dart`
- `bindWatchChannel({log, undo, afterChange, onChanged})`: sets the `opal/watch` handler,
  then invokes `ready`. `afterChange` given (headless) -> after a successful log/undo
  run it, then invoke `idle`; without it, invoke `idle` right after the reply.
  `MissingPluginException` on `ready` is ignored (no native side off iOS).
- `main()`: on iOS, bind with `onChanged: markTablesUpdated(entries, nutritionMeals,
  goals, routines)`.
- `@pragma('vm:entry-point') watchMain()`: binding, `DartPluginRegistrant`, prefs,
  `ProviderContainer`, bind with `afterChange` = push today's widget snapshot. No seeding,
  no timezone init, no `runApp`.
- `LoopDatabase._open`: `busy_timeout` setup.
- Tests (mock method channel): `ready` is sent on bind; a `log` call returns the
  handler's map; with `afterChange`, it runs after the reply and before `idle`; an error
  reply skips `afterChange` but still sends `idle`; `changed` calls `onChanged`.

### Task 3: Token readable while locked
**Files:** `lib/services/pal/device_token_store.dart`,
`test/services/device_token_store_test.dart`
- First-unlock accessibility; re-save a cached token once per store instance.
- Tests: the first read of a cached token writes it back once; later reads don't write;
  a fresh registration writes once, not twice.

### Task 4: Phone relay (Swift)
**Files:** `ios/Runner/Watch/OpalWatchRelay.swift` (new),
`ios/Runner/Watch/OpalWatchSession.swift`, `ios/Runner/Watch/OpalWatchMessage.swift`,
`ios/Runner/AppDelegate.swift`
- As decisions 6 and 7 and Risk 1. `OpalWatchSession` keeps delegate duties; unknown
  types still answer an error.

### Task 5: Watch app (Swift)
**Files:** `ios/OpalWatch/OpalWatchApp.swift`, `ios/OpalWatch/OpalWatchLink.swift`,
`ios/OpalWatch/OpalWatchViews.swift` (new)
- `OpalWatchLink` publishes one state: ready, sending(text), result(reply, text),
  undone(reply), failed(text, reason). `log(text)`, `undo()`, `retry()`, `reset()`.
  `WCError.notReachable` -> "Your iPhone is out of reach"; a phone `error` -> its text.
- Screens per Main.dc.html: Ready ("Tell Pal anything", a `TextFieldLink` that opens the
  system input), Sending ("You said", progress where Undo will sit), Logged, Meal logged,
  Pal answered (scrolls with the Crown), Undone (struck through, "Say it again" opens the
  input), Not logged ("Try again" resends the kept words).
- Not drawn, so added minimally: a close button (top-left toolbar) on result screens to
  get back to Ready, and an error line under Undo when the undo message fails.

### Task 6: Xcode wiring
**Files:** `ios/configure_native_targets.rb`, `ios/Runner.xcodeproj/project.pbxproj`
- Add `OpalWatchRelay.swift` to Runner and `OpalWatchViews.swift` to OpalWatch in the
  script, and hand-edit the pbxproj to the same result (file ref, build file, group
  child, sources phase), matching the ids style already there.

## Verification

No Mac and no Dart SDK here, so:
1. Self-review the diff, then one commit
   (`feat(watch): log to Pal from the Watch through the phone`).
2. Ask the user to push from the main checkout to `ci/watch-pal-logging`, and whether to
   open a draft PR (app.yml runs only on PRs and pushes to main).
3. Dispatch `ios.yml` on that branch; read the result. Nothing is claimed to compile until
   it is green. Read app.yml's analyze and tests; known failures that are not mine:
   areas_screen and pal_lead `setUpAll`, 8 nutrition tests before about 07:50 UTC.
4. Fix and repeat through the same push path if either is red.

Not verifiable in this run (chunk 18, on the device): delivery to a suspended or
terminated phone app, the real background time against chat latency, the two-engine
overlap, the locked-phone token read, whether `TextFieldLink` can open straight into
dictation, and the look on the SE 3. `ios-testflight.yml` is never dispatched by this
run.
