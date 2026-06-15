# Merge Ask Pal into the unified Pal composer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the Composer and Ask Pal chat surfaces into one — the composer's expanding bottom sheet — which gains Ask Pal's per-message undo; delete the Ask Pal screen, controller, and route.

**Architecture:** `PalComposerController`/`PalComposerSheet` survive as the superset surface. The undo mechanism (`_undo` map + `undo(index)`) is ported from `AskPalController`. The composer's `_Bubble` gains an undo footer. All Ask Pal code, its route, its overlay entry, and the dead `lib/screens/money/` dir are removed; the one detail-screen entry point is rewired to the composer.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation codegen), go_router, Drift, flutter_test.

**Spec:** `docs/superpowers/specs/2026-06-15-merge-ask-pal-into-composer-design.md`

> **Git note (overrides skill default):** per the repo's git workflow, do NOT commit per-task. Make all changes, verify, then do the single approval-gated commit in Task 5.

---

### Task 1: Port undo into `PalComposerController`

**Files:**
- Modify: `lib/controllers/pal_composer_controller.dart`
- Test: `test/controllers/pal_composer_controller_test.dart`

- [ ] **Step 1: Extend the test fake to carry actions, then write failing undo tests**

In `test/controllers/pal_composer_controller_test.dart`, update `_FakePal` to return actions:

```dart
class _FakePal implements PalService {
  _FakePal({this.reply = 'Got it.', this.fails = false, this.actions = const []});
  final String reply;
  final bool fails;
  final List<PalAction> actions;
  final List<({List<PalMessage> history, String message})> chatCalls = [];

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    chatCalls.add((history: history, message: message));
    if (fails) throw const PalException('unreachable');
    return PalChatResult(reply: reply, actions: actions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Add this group to the same file's `main()`:

```dart
  group('undo', () {
    test('an action turn logs an entry and undo deletes it', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final pal = _FakePal(reply: 'Logged it.', actions: const [
        LogEntryAction(type: EntryType.move, durationMinutes: 30, title: 'Run'),
      ]);
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('ran 30 min');
      expect(await EntryRepository(db).getAll(), hasLength(1));

      final idx = container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(idx);

      expect(await EntryRepository(db).getAll(), isEmpty);
      expect(container.read(palComposerControllerProvider()).messages[idx].undone, isTrue);
    });

    test('set_daily_budget applies; undo restores the prior value', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final goals = GoalsRepository(db);
      await goals.save(const Goals(dailyBudget: 85));
      final pal = _FakePal(reply: 'Set to \$60.', actions: const [
        SetGoalAction(target: GoalTarget.dailyBudget, value: 60),
      ]);
      final container = containerWith(db, pal);
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('set my budget to 60');
      expect((await goals.get()).dailyBudget, 60);

      final idx = container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(idx);
      expect((await goals.get()).dailyBudget, 85);
    });

    test('a non-action turn records no undo (undo is a no-op)', () async {
      final db = LoopDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerWith(db, _FakePal(reply: 'Just chatting.'));
      final notifier = container.read(palComposerControllerProvider().notifier);

      await notifier.send('how am I doing?');
      final idx = container.read(palComposerControllerProvider()).messages.length - 1;
      await notifier.undo(idx);

      expect(container.read(palComposerControllerProvider()).messages[idx].undone, isFalse);
    });
  });
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/controllers/pal_composer_controller_test.dart`
Expected: FAIL — the `undo` group fails (`undo` method not defined / `undone` never set). The existing groups still pass.

- [ ] **Step 3: Add the undo mechanism to the controller**

In `lib/controllers/pal_composer_controller.dart`, add the import for `AppliedActions` (it lives in `pal_action_executor.dart`, already imported).

Add the undo map field to the class (right after the class opening, before `build`):

```dart
  /// Reversal data per assistant message index (only for turns that mutated).
  final Map<int, AppliedActions> _undo = {};
```

Change `_reply` to record what `applyPalActions` applied. Replace the body's apply line:

```dart
      final result = await ref.read(palServiceProvider).chat(history, message);
      // apply any logging / goal / routine changes the reply carried, same as Ask-Pal
      await applyPalActions(ref, result.actions);
      _appendAssistant(result.reply, actions: result.actions);
```

with:

```dart
      final result = await ref.read(palServiceProvider).chat(history, message);
      // apply any logging / goal / routine changes the reply carried, same as Ask-Pal
      final applied = await applyPalActions(ref, result.actions);
      final index = state.messages.length; // index the assistant message will occupy
      if (!applied.isEmpty) _undo[index] = applied;
      _appendAssistant(result.reply, actions: result.actions);
```

Add the `undo` method (port from `AskPalController.undo`), placed after `_appendAssistant`:

```dart
  /// Reverses the actions applied by the assistant message at [index]: deletes
  /// the entries/routines it created and restores the prior goals. Marks the
  /// message [PalMessage.undone] so the UI can reflect it.
  Future<void> undo(int index) async {
    final rec = _undo.remove(index);
    if (rec == null) return;

    final entries = ref.read(entryRepositoryProvider);
    for (final id in rec.entryIds) {
      await entries.deleteById(id);
    }
    final routines = ref.read(routineRepositoryProvider);
    for (final id in rec.routineIds) {
      await routines.deleteById(id);
    }
    if (rec.priorGoals != null) {
      await ref.read(goalsRepositoryProvider).save(rec.priorGoals!);
    }

    if (index >= 0 && index < state.messages.length) {
      final messages = [...state.messages];
      messages[index] = messages[index].copyWith(undone: true);
      state = state.copyWith(messages: messages);
    }
  }
```

> Note on the index: `_appendAssistant` appends to `state.messages`, so the assistant message lands at the current `state.messages.length`. Capturing `index` *before* the append (as above) gives the correct slot. This matches `AskPalController`, which records against `messages.length - 1` *after* building the new list — same resulting index.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/controllers/pal_composer_controller_test.dart`
Expected: PASS — all groups (seed, send, offline behavior, undo) green.

---

### Task 2: Render the undo affordance in the composer sheet

**Files:**
- Modify: `lib/screens/pal/pal_composer_screen.dart`

- [ ] **Step 1: Add an `onUndo` callback to `_MessageList` and pass it to assistant bubbles**

In `lib/screens/pal/pal_composer_screen.dart`, update `_MessageList`:

```dart
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoading,
    required this.onUndo,
  });

  final ScrollController controller;
  final List<PalMessage> messages;
  final bool isLoading;
  final void Function(int index) onUndo;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isLoading ? 1 : 0);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xs),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (isLoading && i == itemCount - 1) {
          return const _Bubble.typing();
        }
        return _Bubble(message: messages[i], onUndo: () => onUndo(i));
      },
    );
  }
}
```

- [ ] **Step 2: Pass the controller's `undo` from the build method**

In `_PalComposerSheetState.build`, where `_MessageList` is constructed (around line 119), add the callback:

```dart
                  child: _MessageList(
                    controller: _scrollCtrl,
                    messages: state.messages,
                    isLoading: state.isLoading,
                    onUndo: (i) => _controller.undo(i),
                  ),
```

(`_controller` is the existing getter at `pal_composer_screen.dart:53` → `ref.read(palComposerControllerProvider(seed: widget.seed).notifier)`.)

- [ ] **Step 3: Add the undo footer to `_Bubble`**

Update `_Bubble` to accept `onUndo` and render the Undo / Undone footer below the assistant bubble, preserving the existing avatar-row layout:

```dart
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onUndo}) : isTyping = false;
  const _Bubble.typing()
      : message = null,
        onUndo = null,
        isTyping = true;

  final PalMessage? message;

  /// Reverses this turn's auto-applied actions. Shown only on assistant
  /// messages that applied something and haven't been undone.
  final VoidCallback? onUndo;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUser = !isTyping && message!.role == PalRole.user;
    const radius = Radius.circular(Radii.lg);
    const tail = Radius.circular(Radii.xs);
    final shape = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isUser ? radius : tail,
      bottomRight: isUser ? tail : radius,
    );
    final showUndo =
        !isTyping && message!.actions.isNotEmpty && !message!.undone;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: isUser ? c.accent : c.fill,
        borderRadius: shape,
      ),
      child: isTyping
          ? const _TypingDots()
          : Text(
              message!.text,
              style: AppType.subhead.copyWith(
                color: isUser ? c.onAccent : c.ink,
                letterSpacing: -0.24,
                height: 1.4,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _PalAvatar(size: 24, glyphSize: 11),
            const SizedBox(width: Spacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                if (showUndo)
                  GestureDetector(
                    onTap: onUndo,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs, left: Spacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon('arrow.uturn.backward', size: 12, color: c.accent),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            'Undo',
                            style: AppType.footnote.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.accent,
                              letterSpacing: -0.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isTyping && message!.undone)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs, left: Spacing.sm),
                    child: Text(
                      'Undone',
                      style: AppType.footnote.copyWith(
                        color: c.ink3,
                        letterSpacing: -0.08,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Confirm `AppIcon` is imported**

Check the import block of `pal_composer_screen.dart` for the symbol `AppIcon` (used in `_PalAvatar`/header already — verify). If `AppIcon` is not resolvable, add the same import `ask_pal_screen.dart` uses for it.

Run: `flutter analyze lib/screens/pal/pal_composer_screen.dart`
Expected: No errors (no undefined `AppIcon`, no unused warnings).

---

### Task 3: Delete Ask Pal and rewire its one entry point

**Files:**
- Delete: `lib/screens/pal/ask_pal_screen.dart`
- Delete: `lib/controllers/ask_pal_controller.dart`
- Delete: `lib/controllers/ask_pal_controller.g.dart`
- Delete: `test/ask_pal_test.dart`
- Delete: `test/ask_pal_controller_test.dart`
- Modify: `lib/router.dart` (remove enum value, GoRoute, import)
- Modify: `lib/app.dart` (remove `'/pal'` overlay entry)
- Modify: `lib/screens/detail/detail_screen.dart` (rewire pill)
- Remove: empty dir `lib/screens/money/`

- [ ] **Step 1: Rewire the detail-screen pill to the composer**

In `lib/screens/detail/detail_screen.dart:663`, change:

```dart
      onTap: () => context.pushNamed(AppRoute.askPal.name),
```

to:

```dart
      onTap: () => context.pushNamed(AppRoute.palComposer.name),
```

(Behavior preserved: this opens the composer's compact greeting; the pill never seeded a prompt.)

- [ ] **Step 2: Remove the route, its GoRoute, and the import**

In `lib/router.dart`:
- Delete the import line: `import 'screens/pal/ask_pal_screen.dart';` (line 15).
- Delete the enum value at line 79: `askPal('askPal', '/pal'), //                      U16`.
- Delete the entire `GoRoute` block for askPal (lines ~293–297):

```dart
      GoRoute(
        path: AppRoute.askPal.path,
        name: AppRoute.askPal.name,
        pageBuilder: (context, state) =>
            _sheetPage(state.pageKey, const AskPalScreen()),
      ),
```

- [ ] **Step 3: Remove the `/pal` overlay entry**

In `lib/app.dart`, delete the `'/pal',` line (line 98) from the `overlays` set in `_isOverlayRoute`.

- [ ] **Step 4: Delete the Ask Pal source and test files**

```bash
rm lib/screens/pal/ask_pal_screen.dart \
   lib/controllers/ask_pal_controller.dart \
   lib/controllers/ask_pal_controller.g.dart \
   test/ask_pal_test.dart \
   test/ask_pal_controller_test.dart
rmdir lib/screens/money
```

- [ ] **Step 5: Verify no dangling references**

Run: `grep -rn "askPal\|AskPal\|ask_pal" lib test`
Expected: no matches. (If `grep` exits non-zero with no output, that is the success case.)

Run: `grep -rn "screens/money" lib test`
Expected: no matches.

---

### Task 4: Full verification

- [ ] **Step 1: Regenerate codegen (safety net for the deleted controller)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes without error. Likely a no-op for the surviving files (deleting `ask_pal_controller.dart` + its part removes its provider; nothing else references it).

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: clean (the only pre-existing lint is the known one in `test/controllers/widget_sync_controller_test.dart`, unrelated to this change — confirm no *new* issues).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass. Net test count drops by the 2 deleted Ask Pal files and rises by the new undo group in the composer test.

---

### Task 5: Single commit (requires explicit approval)

- [ ] **Step 1: Show the diff summary and request approval**

Per the repo's git workflow, present the file list (M/A/D + path + one-line summary) and the proposed commit message, then ask "Awaiting approval. Proceed? (yes/no)". Do not commit until the user says yes.

Proposed message:

```
refactor(pal): merge Ask Pal into the unified composer sheet

Collapse the two overlapping user->Pal chat surfaces into one. The
composer sheet gains Ask Pal's per-message undo (closing the deferred
"composer auto-applies with no undo" audit item); the /pal route,
screen, and controller are removed. Inbox is unchanged.
```

- [ ] **Step 2: On approval, commit**

```bash
git add -A
git commit -m "refactor(pal): merge Ask Pal into the unified composer sheet" -m "..."
```

---

## Self-review notes

- **Spec coverage:** controller undo (Task 1) · UI undo affordance (Task 2) · delete screen/controller/route/import/overlay + rewire pill + delete tests + remove money dir (Task 3) · analyze+test gate (Task 4) · single approval-gated commit (Task 5). All spec sections mapped.
- **Type consistency:** `undo(int index)`, `_undo` (`Map<int, AppliedActions>`), `AppliedActions.{entryIds, routineIds, priorGoals, isEmpty}`, `PalMessage.copyWith(undone:)`, `AppRoute.palComposer.name`, `entryRepositoryProvider`/`routineRepositoryProvider`/`goalsRepositoryProvider` — all verified against current source.
- **Index correctness:** `index` is captured before `_appendAssistant` appends; documented inline in Task 1 Step 3.
```
