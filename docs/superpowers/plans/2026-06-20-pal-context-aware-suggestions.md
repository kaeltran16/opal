# Pal Context-Aware Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hard-coded quick-pick chips on three surfaces (Pal composer starters, New Entry quick-picks, Routine Generator goals) with Pal-generated, context-aware chips served by one reusable seam, falling back to the existing static lists when Pal is unreachable.

**Architecture:** One new client seam method `PalService.suggestions(surface)` and one new server endpoint `POST /v1/suggestions`, mirroring the existing `/agenda` pattern (LLM picks `kind` + copy; server derives icons from a safe map; zod `.catch`-clamps). A `palSuggestionsProvider(surface)` returns `[]` on any failure; each screen renders Pal's list when non-empty and its existing constants otherwise. The change is purely additive — offline behavior is unchanged.

**Tech Stack:** Flutter + Riverpod (riverpod_annotation codegen), Dart `http`; Node + Fastify + zod + Vitest server; OpenRouter via `CompletionClient`.

## Global Constraints

- Money amount convention on `StarterEntry.amount` and wire `entry.amount`: **signed, negative = expense, positive = income** (verbatim from `StarterEntry` doc).
- `colorToken` is one of `'money' | 'move' | 'rituals' | 'accent'`; unknown values clamp to a safe default (`accent`).
- Icons are SF-symbol names **derived server-side from the model's `kind`** — the model never names a glyph directly (mirrors `/agenda`).
- Server zod objects strip unknown keys by default — adding context fields is backward-compatible.
- No emojis, no markdown in model output. Calm, specific copy; no hype words.
- Never commit without the repo's conventional-commit format: `type(scope): description`.
- The feature must be additive: every surface keeps its current static list as the fallback, so offline / failure / loading reproduce today's exact behavior including offline quick-logging.

---

### Task 1: Shared `PalSuggestion` DTO, `SuggestionSurface`, and seam method (+ mock)

Move `StarterEntry` to the seam so the DTO and all surfaces share one definition, add the new types, extend the `PalService` interface, and implement the mock. This makes the seam compile and testable against `MockPalService` before any HTTP/server work.

**Files:**
- Modify: `lib/services/pal/pal_service.dart` (add types + interface method; host `StarterEntry`)
- Modify: `lib/controllers/pal_composer_controller.dart` (remove the local `StarterEntry`, import from seam)
- Modify: `lib/services/pal/mock_pal_service.dart` (implement `suggestions`)
- Test: `test/services/pal/mock_pal_service_suggestions_test.dart`

**Interfaces:**
- Produces:
  - `enum SuggestionSurface { composer, newEntry, routineGoal }`
  - `class StarterEntry { final EntryType type; final String title; final double? amount; final String? category; final int? durationMinutes; const StarterEntry({required this.type, required this.title, this.amount, this.category, this.durationMinutes}); }` (moved verbatim from the controller)
  - `class PalSuggestion { final String label; final String icon; final String colorToken; final StarterEntry? entry; }`
  - `Future<List<PalSuggestion>> suggestions(SuggestionSurface surface)` on `PalService`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/pal/mock_pal_service_suggestions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/mock_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('mock returns non-empty suggestions for each surface', () async {
    final pal = MockPalService(latency: Duration.zero);
    for (final surface in SuggestionSurface.values) {
      final out = await pal.suggestions(surface);
      expect(out, isNotEmpty, reason: 'surface $surface');
      expect(out.first.label, isNotEmpty);
      expect(out.first.icon, isNotEmpty);
    }
  });

  test('composer suggestions include at least one concrete log (entry payload)', () async {
    final pal = MockPalService(latency: Duration.zero);
    final out = await pal.suggestions(SuggestionSurface.composer);
    expect(out.any((s) => s.entry != null), isTrue);
  });

  test('routineGoal suggestions are label-only (no entry payload)', () async {
    final pal = MockPalService(latency: Duration.zero);
    final out = await pal.suggestions(SuggestionSurface.routineGoal);
    expect(out.every((s) => s.entry == null), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal/mock_pal_service_suggestions_test.dart`
Expected: FAIL — `SuggestionSurface`/`suggestions` undefined (compile error).

- [ ] **Step 3: Add the types and interface method to `pal_service.dart`**

Add near the other DTOs (e.g. just above `abstract interface class PalService`). Move `StarterEntry` here from the controller verbatim:

```dart
/// A structured quick-log payload attached to a concrete suggestion chip. When
/// Pal is offline, the composer writes this as a local [Entry] instead of
/// hanging; the New Entry sheet uses it to pre-fill the form. Open-prompt /
/// goal chips carry none (null). Money [amount] is pre-signed (negative =
/// expense), mirroring [Entry.amount].
class StarterEntry {
  const StarterEntry({
    required this.type,
    required this.title,
    this.amount,
    this.category,
    this.durationMinutes,
  });

  final EntryType type;
  final String title;
  final double? amount;
  final String? category;
  final int? durationMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarterEntry &&
          other.type == type &&
          other.title == title &&
          other.amount == amount &&
          other.category == category &&
          other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(type, title, amount, category, durationMinutes);
}

/// Which surface a [PalSuggestion] set is generated for. Tunes the server prompt
/// and selects the context the client sends.
enum SuggestionSurface { composer, newEntry, routineGoal }

/// One Pal-generated quick-pick chip (the `/suggestions` seam). [label] is both
/// the display text and the action text (chat message or routine goal). [icon]
/// is an SF-symbol name derived server-side from the model's kind; [colorToken]
/// is the pillar accent. [entry] is the optional structured quick-log used by
/// the composer (offline fallback) and New Entry (form prefill).
class PalSuggestion {
  const PalSuggestion({
    required this.label,
    required this.icon,
    required this.colorToken,
    this.entry,
  });

  final String label;
  final String icon;
  final String colorToken;
  final StarterEntry? entry;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PalSuggestion &&
          other.label == label &&
          other.icon == icon &&
          other.colorToken == colorToken &&
          other.entry == entry;

  @override
  int get hashCode => Object.hash(label, icon, colorToken, entry);
}
```

Add to the `PalService` interface (near `agenda()`):

```dart
  /// `/v1/suggestions`: Pal-generated, context-aware quick-pick chips for the
  /// given [surface]. Drives the composer starters, New Entry quick-picks, and
  /// Routine Generator goal chips.
  Future<List<PalSuggestion>> suggestions(SuggestionSurface surface);
```

- [ ] **Step 4: Remove the duplicate `StarterEntry` from the composer controller**

In `lib/controllers/pal_composer_controller.dart`, delete the `class StarterEntry { ... }` block (lines ~17–35) and its doc comment. The file already imports `../services/services.dart`; confirm `StarterEntry` resolves through that barrel (it re-exports `pal_service.dart`). If `services.dart` does not export `pal_service.dart`, add `import '../services/pal/pal_service.dart';` to the controller.

- [ ] **Step 5: Implement `suggestions` in `MockPalService`**

Add inside `MockPalService` (after `agenda()`):

```dart
  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface surface) async {
    await Future<void>.delayed(latency);
    switch (surface) {
      case SuggestionSurface.composer:
        return const [
          PalSuggestion(
            label: 'Verve coffee, \$5',
            icon: 'cup.and.saucer.fill',
            colorToken: 'money',
            entry: StarterEntry(
                type: EntryType.money, title: 'Verve coffee', amount: -5, category: 'Coffee'),
          ),
          PalSuggestion(
            label: 'Finished morning pages',
            icon: 'sparkles',
            colorToken: 'rituals',
            entry: StarterEntry(type: EntryType.rituals, title: 'Morning pages'),
          ),
          PalSuggestion(
            label: "How's my week so far?",
            icon: 'chart.bar.fill',
            colorToken: 'accent',
          ),
        ];
      case SuggestionSurface.newEntry:
        return const [
          PalSuggestion(
            label: 'Verve Coffee',
            icon: 'cup.and.saucer.fill',
            colorToken: 'money',
            entry: StarterEntry(
                type: EntryType.money, title: 'Verve Coffee', amount: -5, category: 'Coffee'),
          ),
          PalSuggestion(
            label: 'Lunch',
            icon: 'fork.knife',
            colorToken: 'money',
            entry: StarterEntry(
                type: EntryType.money, title: 'Lunch', amount: -14, category: 'Dining'),
          ),
          PalSuggestion(
            label: 'Run',
            icon: 'figure.run',
            colorToken: 'move',
            entry: StarterEntry(type: EntryType.move, title: 'Run', durationMinutes: 30),
          ),
          PalSuggestion(
            label: 'Morning pages',
            icon: 'sparkles',
            colorToken: 'rituals',
            entry: StarterEntry(type: EntryType.rituals, title: 'Morning pages'),
          ),
        ];
      case SuggestionSurface.routineGoal:
        return const [
          PalSuggestion(label: '45-min push for strength', icon: 'flame.fill', colorToken: 'move'),
          PalSuggestion(label: 'Quick full-body, no barbell', icon: 'figure.mixed.cardio', colorToken: 'accent'),
          PalSuggestion(label: 'Pull day focused on back', icon: 'figure.pullup', colorToken: 'rituals'),
          PalSuggestion(label: 'Short HIIT cardio', icon: 'bolt.fill', colorToken: 'money'),
        ];
    }
  }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/services/pal/mock_pal_service_suggestions_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Verify the wider build still compiles**

Run: `flutter analyze lib/services/pal/pal_service.dart lib/services/pal/mock_pal_service.dart lib/controllers/pal_composer_controller.dart`
Expected: No errors (warnings about unrelated files are acceptable).

- [ ] **Step 8: Commit**

```bash
git add lib/services/pal/pal_service.dart lib/services/pal/mock_pal_service.dart lib/controllers/pal_composer_controller.dart test/services/pal/mock_pal_service_suggestions_test.dart
git commit -m "feat(pal): add PalSuggestion seam + mock for context-aware chips"
```

---

### Task 2: Add time-of-day signal to the chat context

Context-aware chips ("morning pages" at 8am vs a wind-down at 9pm) need the current time. Add `hourOfDay` (0–23) and `weekday` (1–7) to the Dart `buildChatContext` map and the server `chatContext` zod schema. Additive and backward-compatible (`/agenda` and `/chat` reuse this context and ignore the new fields until they use them).

**Files:**
- Modify: `lib/services/pal/pal_context_builder.dart` (`buildChatContext`)
- Modify: `server/src/schemas.ts` (`chatContext`)
- Test: `test/services/pal/pal_context_builder_test.dart` (extend existing or create)

**Interfaces:**
- Consumes: `buildChatContext(...)` (existing function).
- Produces: chat context map gains keys `hourOfDay: int`, `weekday: int`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/pal/pal_context_builder_test.dart  (add this test; create file if absent)
import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/pal_context_builder.dart';

void main() {
  test('buildChatContext includes hourOfDay and weekday from now', () {
    final ctx = buildChatContext(
      userName: 'Kael',
      goals: const Goals(dailyBudget: 50, dailyMoveKcal: 400, dailyRitualTarget: 3),
      todayEntries: const [],
      weekEntries: const [],
      moveStreakDays: 0,
      now: DateTime(2026, 6, 20, 8), // Saturday 08:00
    );
    expect(ctx['hourOfDay'], 8);
    expect(ctx['weekday'], DateTime.saturday); // 6
  });
}
```

If `Goals` has a different constructor, copy the shape used elsewhere in `test/` (search an existing `Goals(` usage). The assertion on the two new keys is the point.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal/pal_context_builder_test.dart`
Expected: FAIL — `buildChatContext` has no `now` parameter / keys absent.

- [ ] **Step 3: Add an optional `now` and the two keys to `buildChatContext`**

In `lib/services/pal/pal_context_builder.dart`, change the signature and body:

```dart
Map<String, Object?> buildChatContext({
  required String userName,
  required Goals goals,
  required List<Entry> todayEntries,
  required List<Entry> weekEntries,
  required int moveStreakDays,
  int routineCount = 0,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final ritualTarget = effectiveDailyRitualTarget(routineCount, goals);
  return {
    'userName': userName,
    'todayEntries': todayEntries.map(formatEntryLine).toList(),
    'dailyBudget': goals.dailyBudget,
    'moveGoalKcal': goals.dailyMoveKcal,
    'ritualGoal': ritualTarget,
    'spentToday': _spent(todayEntries),
    'movedTodayKcal': _movedKcal(todayEntries),
    'ritualsDoneToday': _rituals(todayEntries),
    'weekSpent': _spent(weekEntries),
    'weekBudget': goals.dailyBudget * 7,
    'weekMovedKcal': _movedKcal(weekEntries),
    'weekRitualsDone': _rituals(weekEntries),
    'weekRitualGoal': ritualTarget * 7,
    'moveStreakDays': moveStreakDays,
    'hourOfDay': clock.hour,
    'weekday': clock.weekday,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/pal/pal_context_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the two fields to the server `chatContext` schema**

In `server/src/schemas.ts`, inside `chatContext`, add after `moveStreakDays: z.number(),`:

```ts
  hourOfDay: z.number(),
  weekday: z.number(),
```

- [ ] **Step 6: Run the full client + server test suites to catch fallout**

Run: `flutter test`
Run: `cd server && npm test`
Expected: PASS. If a context-builder or golden test asserted the exact chat-context map, update its expected map to include `hourOfDay` and `weekday`. (The new keys are additive; only exact-equality assertions need updating.)

- [ ] **Step 7: Commit**

```bash
git add lib/services/pal/pal_context_builder.dart server/src/schemas.ts test/services/pal/pal_context_builder_test.dart
git commit -m "feat(pal): add hourOfDay/weekday to chat context for time-aware grounding"
```

---

### Task 3: Server `/v1/suggestions` endpoint

Add the body schema, the model-output schema + safe icon map, the prompt, the `Pal.suggestions` handler, and the route — mirroring `/agenda`.

**Files:**
- Modify: `server/src/schemas.ts` (`suggestionsBody`)
- Modify: `server/src/prompts.ts` (`suggestionsPrompt`)
- Modify: `server/src/pal.ts` (`suggestionsModelSchema`, `SUGGESTION_ICON`, `SuggestionsResult`, `Pal.suggestions`)
- Modify: `server/src/app.ts` (route)
- Test: `server/src/pal.test.ts` (add suggestions cases)

**Interfaces:**
- Consumes: `chatContext`, `suggestContext` (existing); `extractJson`, `colorToken` const, `CompletionClient` (existing in `pal.ts`).
- Produces:
  - `suggestionsBody = z.object({ surface: z.enum(['composer','newEntry','routineGoal']), context: z.union([chatContext, suggestContext]) })`
  - `Pal.suggestions(surface, context): Promise<SuggestionsResult>` where `SuggestionsResult = { suggestions: Array<{ label: string; icon: string; colorToken: string; entry: { type: 'money'|'move'|'rituals'; title: string; amount: number | null; category: string | null; minutes: number | null } | null }> }`

- [ ] **Step 1: Write the failing test**

```ts
// server/src/pal.test.ts  (add these; reuse the file's existing fake CompletionClient pattern)
import { Pal } from './pal.js'

// A stub client that returns a fixed raw string for .complete(). Match the
// existing fake in this file; if it is named differently, reuse that one.
function fakeClient(raw: string) {
  return { complete: async () => raw, completeWithTools: async () => ({ content: '', toolCalls: [] }) } as any
}

const chatCtx = {
  userName: 'Kael', todayEntries: [], dailyBudget: 50, moveGoalKcal: 400, ritualGoal: 3,
  spentToday: 0, movedTodayKcal: 0, ritualsDoneToday: 0, weekSpent: 0, weekBudget: 350,
  weekMovedKcal: 0, weekRitualsDone: 0, weekRitualGoal: 21, moveStreakDays: 0,
  hourOfDay: 8, weekday: 6,
}

describe('Pal.suggestions', () => {
  it('maps model output to chips and derives icons from kind', async () => {
    const raw = JSON.stringify({
      suggestions: [
        { kind: 'log_money', colorToken: 'money', label: 'Coffee, $5',
          entry: { type: 'money', title: 'Coffee', amount: -5, category: 'Coffee', minutes: null } },
        { kind: 'ask', colorToken: 'accent', label: "How's my week?" },
      ],
    })
    const pal = new Pal(fakeClient(raw))
    const out = await pal.suggestions('composer', chatCtx as any)
    expect(out.suggestions).toHaveLength(2)
    expect(out.suggestions[0].icon).toBe('dollarsign.circle.fill') // derived from kind
    expect(out.suggestions[0].entry?.amount).toBe(-5)
    expect(out.suggestions[1].entry).toBeNull()
  })

  it('coerces unknown kind/colorToken to safe defaults', async () => {
    const raw = JSON.stringify({ suggestions: [{ kind: 'bogus', colorToken: 'neon', label: 'X' }] })
    const pal = new Pal(fakeClient(raw))
    const out = await pal.suggestions('composer', chatCtx as any)
    expect(out.suggestions[0].icon).toBe('sparkles') // generic
    expect(out.suggestions[0].colorToken).toBe('accent')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: FAIL — `Pal.suggestions` is not a function.

- [ ] **Step 3: Add `suggestionsBody` to `schemas.ts`**

After `agendaBody`:

```ts
export const suggestionsBody = z.object({
  surface: z.enum(['composer', 'newEntry', 'routineGoal']),
  // composer/newEntry send chat context; routineGoal sends suggest context.
  context: z.union([chatContext, suggestContext]),
})
```

- [ ] **Step 4: Add the model schema, icon map, result type, and handler to `pal.ts`**

Place the schema/maps next to the agenda block (after `AgendaResult`). The kinds cover the three surfaces; the server derives the SF-symbol icon so the model can never name a bad glyph:

```ts
// --- Pal quick-pick suggestions (/v1/suggestions) ---------------------------
// The model picks each chip's `kind` (and the copy); the server derives the
// SF-symbol icon from that kind. Off-list kinds coerce to 'generic'.
const suggestionKinds = ['log_money', 'log_move', 'log_ritual', 'ask', 'routine_goal', 'generic'] as const

const SUGGESTION_ICON: Record<(typeof suggestionKinds)[number], string> = {
  log_money: 'dollarsign.circle.fill',
  log_move: 'figure.run',
  log_ritual: 'sparkles',
  ask: 'chart.bar.fill',
  routine_goal: 'flame.fill',
  generic: 'sparkles',
}

const suggestionEntry = z.object({
  type: z.enum(['money', 'move', 'rituals']),
  title: z.string(),
  amount: z.number().nullable().optional(),
  category: z.string().nullable().optional(),
  minutes: z.number().nullable().optional(),
}).nullable().optional()

export const suggestionsModelSchema = z.object({
  suggestions: z.array(z.object({
    kind: z.enum(suggestionKinds).catch('generic'),
    colorToken,
    label: z.string(),
    entry: suggestionEntry,
  })).default([]),
})

export interface SuggestionsResult {
  suggestions: Array<{
    label: string
    icon: string
    colorToken: string
    entry: { type: 'money' | 'move' | 'rituals'; title: string; amount: number | null; category: string | null; minutes: number | null } | null
  }>
}
```

Add the method inside `class Pal` (after `agenda`):

```ts
  async suggestions(surface: 'composer' | 'newEntry' | 'routineGoal', ctx: ChatContext | SuggestContext): Promise<SuggestionsResult> {
    const raw = await this.client.complete(
      [{ role: 'user', content: suggestionsPrompt(surface, ctx) }],
      { json: true, maxTokens: INSIGHTS_MAX_TOKENS, temperature: 0 },
    )
    const parsed = suggestionsModelSchema.parse(extractJson(raw))
    return {
      suggestions: parsed.suggestions.map((s) => ({
        label: s.label,
        icon: SUGGESTION_ICON[s.kind],
        colorToken: s.colorToken,
        entry: s.entry
          ? {
              type: s.entry.type,
              title: s.entry.title,
              amount: s.entry.amount ?? null,
              category: s.entry.category ?? null,
              minutes: s.entry.minutes ?? null,
            }
          : null,
      })),
    }
  }
```

Add `suggestionsPrompt` to the import from `./prompts.js` at the top of `pal.ts` (the line that imports `agendaPrompt`, etc.).

- [ ] **Step 5: Add `suggestionsPrompt` to `prompts.ts`**

After `agendaPrompt`:

```ts
export function suggestionsPrompt(
  surface: 'composer' | 'newEntry' | 'routineGoal',
  c: ChatContext | SuggestContext,
): string {
  const shape = `{"suggestions":[{"kind":"log_money"|"log_move"|"log_ritual"|"ask"|"routine_goal"|"generic","colorToken":"money"|"move"|"rituals"|"accent","label":string,"entry":{"type":"money"|"move"|"rituals","title":string,"amount":number|null,"category":string|null,"minutes":number|null}|null}]}`
  const tail = `\nCalm and specific. No hype words, no emoji, never markdown. Return strictly this JSON shape; the array may be empty but must be present: ${shape}\nNo prose, no code fence. Output only the JSON object.`

  if (surface === 'routineGoal') {
    const sc = c as SuggestContext
    const recent = sc.recentWorkouts.length
      ? sc.recentWorkouts.map((w) => `${w.routineName} — ${w.date} — ${w.muscles}`).join('\n')
      : '(none this week)'
    return `You are Pal, a workout coach. Propose up to 6 short workout-goal chips the user can tap to generate a routine. Recent workouts:
${recent}
Today is ${sc.dayOfWeek}. Vary muscle groups vs recent volume; keep each label under ~5 words. Every chip: kind "routine_goal", colorToken one of money/move/rituals/accent, label is the goal text, entry null.${tail}`
  }

  const cc = c as ChatContext
  const entries = cc.todayEntries.length ? cc.todayEntries.join('\n') : '(none yet)'
  const name = cc.userName || 'the user'
  const numbers = `Daily budget $${cc.dailyBudget}, move goal ${cc.moveGoalKcal}kcal, ritual goal ${cc.ritualGoal}. So far today: $${cc.spentToday} spent, ${cc.movedTodayKcal}kcal moved, ${cc.ritualsDoneToday}/${cc.ritualGoal} rituals. Local hour ${cc.hourOfDay}, weekday ${cc.weekday} (1=Mon). ${cc.moveStreakDays}-day move streak.`

  if (surface === 'newEntry') {
    return `You are Pal in a money/movement/rituals app. Propose up to 6 one-tap LOG presets for ${name} to record quickly — this surface has no chat, so NO questions. Today's entries:
${entries}
${numbers}
Ground each in what is NOT yet logged today, recent categories, and the time of day. Each chip MUST carry an "entry": pick "kind" log_money / log_move / log_ritual to match entry.type (money/move/rituals), set colorToken to the matching pillar (money/move/rituals), and a short "label". For money, entry.amount is SIGNED (negative = expense); set category; minutes null. For move, set minutes; amount/category null. For rituals, amount/category/minutes null.${tail}`
  }

  // composer
  return `You are Pal in a money/movement/rituals app. Propose exactly 3 quick chips for ${name}: a mix of one-tap LOGS and short ASKS, grounded in time of day, what is not yet logged today, recent categories, and budget pace. Today's entries:
${entries}
${numbers}
For a LOG chip: set "kind" log_money / log_move / log_ritual matching entry.type, colorToken to the pillar, "label" the phrase the user would say (e.g. "Verve coffee, $5"), and a matching "entry" (money amount SIGNED, negative = expense, with category; move with minutes; rituals title only). For an ASK chip: kind "ask", colorToken "accent", a short question label, entry null.${tail}`
}
```

Confirm `SuggestContext` is exported/available in `prompts.ts` (it is already used by `suggestPrompt`); `ChatContext` is already used by `agendaPrompt`.

- [ ] **Step 6: Add the route to `app.ts`**

Add `suggestionsBody` to the schemas import line, then register near the `/v1/agenda` route:

```ts
  app.post('/v1/suggestions', guard(suggestionsBody, async (b) => deps.pal.suggestions(b.surface, b.context)))
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd server && npx vitest run src/pal.test.ts`
Expected: PASS (both new cases). Then `npm test` to confirm nothing else broke.

- [ ] **Step 8: Commit**

```bash
git add server/src/schemas.ts server/src/prompts.ts server/src/pal.ts server/src/app.ts server/src/pal.test.ts
git commit -m "feat(server): add /v1/suggestions seam for context-aware quick-picks"
```

---

### Task 4: `HttpPalService.suggestions` (wire encode/decode + caching)

Implement the client transport: build the right context per surface, POST `{surface, context}` with caching, and decode the wire into `PalSuggestion`s (dropping malformed items).

**Files:**
- Modify: `lib/services/pal/http_pal_service.dart` (`suggestions`; extend `_cachedPost` to accept extra body)
- Test: `test/services/pal/http_pal_service_suggestions_test.dart`

**Interfaces:**
- Consumes: `PalContextSource.chat`, `PalContextSource.suggest` (existing); `PalSuggestion`/`SuggestionSurface`/`StarterEntry` (Task 1).
- Produces: `HttpPalService.suggestions(surface)` decoding the `/v1/suggestions` wire.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/pal/http_pal_service_suggestions_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

PalContextSource _ctx() => PalContextSource(
      chat: () async => {'userName': 'Kael'},
      review: (_, __) async => {},
      insights: (_) async => {},
      suggest: (_, __) async => {'dayOfWeek': 'Sat'},
      postWorkout: (_) async => {},
      resolveRoutineTitle: (_) async => null,
    );

HttpPalService _svc(MockClient client) => HttpPalService(
      baseUrl: 'https://x.test',
      httpClient: client,
      tokens: TokenProvider(token: () async => 't', clear: () async {}),
      context: _ctx(),
    );

void main() {
  test('decodes suggestions and drops malformed items', () async {
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['surface'], 'composer');
      return http.Response(
        jsonEncode({
          'suggestions': [
            {
              'label': 'Coffee, \$5',
              'icon': 'dollarsign.circle.fill',
              'colorToken': 'money',
              'entry': {'type': 'money', 'title': 'Coffee', 'amount': -5, 'category': 'Coffee', 'minutes': null},
            },
            {'label': "How's my week?", 'icon': 'chart.bar.fill', 'colorToken': 'accent'},
            {'icon': 'x'}, // malformed: no label → dropped
          ],
        }),
        200,
      );
    });
    final out = await _svc(client).suggestions(SuggestionSurface.composer);
    expect(out, hasLength(2));
    expect(out[0].entry?.type, EntryType.money);
    expect(out[0].entry?.amount, -5);
    expect(out[1].entry, isNull);
  });

  test('routineGoal posts the suggest context', () async {
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['surface'], 'routineGoal');
      expect((body['context'] as Map)['dayOfWeek'], 'Sat');
      return http.Response(jsonEncode({'suggestions': []}), 200);
    });
    final out = await _svc(client).suggestions(SuggestionSurface.routineGoal);
    expect(out, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/pal/http_pal_service_suggestions_test.dart`
Expected: FAIL — `suggestions` not implemented on `HttpPalService`.

- [ ] **Step 3: Extend `_cachedPost` to accept extra body fields**

In `http_pal_service.dart`, change `_cachedPost` so callers can add fields beyond `context` (keeps it DRY; the cache key still namespaces by `kind`):

```dart
  Future<Map<String, dynamic>> _cachedPost(
    String kind,
    String path,
    Map<String, Object?> ctx, {
    Map<String, Object?> extra = const {},
  }) async {
    final key = '$kind:${jsonEncode(ctx)}';
    final hit = await cache.get(key);
    if (hit != null) {
      try {
        return jsonDecode(hit) as Map<String, dynamic>;
      } catch (_) {
        // corrupt entry — fall through and refetch.
      }
    }
    final json = await _post(path, {'context': ctx, ...extra});
    await cache.put(key, jsonEncode(json));
    return json;
  }
```

- [ ] **Step 4: Implement `suggestions`**

Add after `agenda()`:

```dart
  static String _surfaceWire(SuggestionSurface s) => switch (s) {
        SuggestionSurface.composer => 'composer',
        SuggestionSurface.newEntry => 'newEntry',
        SuggestionSurface.routineGoal => 'routineGoal',
      };

  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface surface) async {
    final wire = _surfaceWire(surface);
    // composer/newEntry are grounded in the chat context; routineGoal in the
    // suggest context (recent workouts + day of week).
    final ctx = surface == SuggestionSurface.routineGoal
        ? await context.suggest(false, null)
        : await context.chat();
    final json = await _cachedPost('suggestions:$wire', '/v1/suggestions', ctx,
        extra: {'surface': wire});
    return ((json['suggestions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_suggestionFromWire)
        .whereType<PalSuggestion>()
        .toList();
  }

  /// Decodes one wire suggestion. Returns null when the required [label] is
  /// missing/empty so a malformed item is dropped (newer-server-safe).
  PalSuggestion? _suggestionFromWire(Map<String, dynamic> s) {
    final label = (s['label'] as String?)?.trim();
    if (label == null || label.isEmpty) return null;
    final rawEntry = s['entry'];
    StarterEntry? entry;
    if (rawEntry is Map<String, dynamic>) {
      final title = (rawEntry['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) {
        entry = StarterEntry(
          type: _entryTypeFromWire(rawEntry['type'] as String? ?? 'money'),
          title: title,
          amount: (rawEntry['amount'] as num?)?.toDouble(),
          category: rawEntry['category'] as String?,
          durationMinutes: (rawEntry['minutes'] as num?)?.round(),
        );
      }
    }
    return PalSuggestion(
      label: label,
      icon: s['icon'] as String? ?? 'sparkles',
      colorToken: s['colorToken'] as String? ?? 'accent',
      entry: entry,
    );
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/pal/http_pal_service_suggestions_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/services/pal/http_pal_service.dart test/services/pal/http_pal_service_suggestions_test.dart
git commit -m "feat(pal): HttpPalService.suggestions wire + cached transport"
```

---

### Task 5: `palSuggestions` provider with graceful degradation

A Riverpod family provider that returns `[]` on any failure, so each screen falls back to its static constants.

**Files:**
- Create: `lib/controllers/pal_suggestions_controller.dart`
- Test: `test/controllers/pal_suggestions_controller_test.dart`
- (Generated) `lib/controllers/pal_suggestions_controller.g.dart` via build_runner

**Interfaces:**
- Consumes: `palServiceProvider` (existing), `PalService.suggestions` (Task 1/4).
- Produces: `palSuggestionsProvider(SuggestionSurface surface)` → `AsyncValue<List<PalSuggestion>>`; resolves to `const []` on `PalException` or any error.

- [ ] **Step 1: Write the failing test**

```dart
// test/controllers/pal_suggestions_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/controllers/providers.dart';
import 'package:opal/services/pal/http_pal_service.dart';
import 'package:opal/services/pal/pal_service.dart';

class _ThrowingPal implements PalService {
  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface s) async =>
      throw const PalException('down');
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _OkPal implements PalService {
  @override
  Future<List<PalSuggestion>> suggestions(SuggestionSurface s) async =>
      const [PalSuggestion(label: 'x', icon: 'sparkles', colorToken: 'accent')];
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('returns [] when the service throws', () async {
    final c = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(_ThrowingPal())]);
    addTearDown(c.dispose);
    final out = await c.read(palSuggestionsProvider(SuggestionSurface.composer).future);
    expect(out, isEmpty);
  });

  test('returns the service list on success', () async {
    final c = ProviderContainer(overrides: [palServiceProvider.overrideWithValue(_OkPal())]);
    addTearDown(c.dispose);
    final out = await c.read(palSuggestionsProvider(SuggestionSurface.newEntry).future);
    expect(out, hasLength(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/pal_suggestions_controller_test.dart`
Expected: FAIL — `pal_suggestions_controller.dart` does not exist.

- [ ] **Step 3: Create the provider**

```dart
// lib/controllers/pal_suggestions_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/pal/pal_service.dart';
import 'providers.dart';

part 'pal_suggestions_controller.g.dart';

/// Pal-generated quick-pick chips for [surface] (the `/suggestions` seam).
/// One-shot, family-keyed by surface. An unreachable backend / timeout /
/// malformed payload degrades to an empty list, so each surface renders its
/// own static fallback (mirrors [palAgenda]'s graceful-degradation boundary).
@riverpod
Future<List<PalSuggestion>> palSuggestions(Ref ref, SuggestionSurface surface) async {
  final pal = ref.watch(palServiceProvider);
  try {
    return await pal.suggestions(surface);
  } catch (_) {
    return const [];
  }
}
```

- [ ] **Step 4: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/controllers/pal_suggestions_controller.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/controllers/pal_suggestions_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/controllers/pal_suggestions_controller.dart lib/controllers/pal_suggestions_controller.g.dart test/controllers/pal_suggestions_controller_test.dart
git commit -m "feat(pal): palSuggestions provider with graceful degradation"
```

---

### Task 6: Wire the composer starters to Pal

Make `_CompactBody` read `palSuggestions(SuggestionSurface.composer)`, render Pal's chips when present, and fall back to the existing `_starters` constant otherwise. Tap behavior unchanged (`sendStarter(label, entry)`).

**Files:**
- Modify: `lib/screens/pal/pal_composer_screen.dart`
- Test: `test/screens/pal/pal_composer_starters_test.dart`

**Interfaces:**
- Consumes: `palSuggestionsProvider` (Task 5), `PalSuggestion`/`StarterEntry` (Task 1).
- `_Starter` already has `(icon, colorToken, label, {payload})`; map `PalSuggestion` → `_Starter(s.icon, s.colorToken, s.label, payload: s.entry)`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/screens/pal/pal_composer_starters_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  testWidgets('composer renders Pal-provided starter labels when present', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        palSuggestionsProvider(SuggestionSurface.composer).overrideWith(
          (ref) async => const [
            PalSuggestion(label: 'Pal-made coffee, \$4', icon: 'cup.and.saucer.fill', colorToken: 'money'),
          ],
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: PalComposerSheet())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pal-made coffee, \$4'), findsOneWidget);
  });
}
```

If `PalComposerSheet` requires router/providers that make a bare pump fail, mirror the harness used by the existing composer test (search `test/` for `PalComposerSheet`/`palComposerControllerProvider`) and reuse it. The assertion — Pal's label appears — is the deliverable.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/pal/pal_composer_starters_test.dart`
Expected: FAIL — Pal's label not found (still rendering the hard-coded `_starters`).

- [ ] **Step 3: Convert `_CompactBody` to a ConsumerWidget reading the provider**

In `pal_composer_screen.dart`:

1. Change `class _CompactBody extends StatelessWidget` to `class _CompactBody extends ConsumerWidget` and `Widget build(BuildContext context)` to `Widget build(BuildContext context, WidgetRef ref)`.
2. Keep the existing `static const _starters` list — it becomes the fallback.
3. At the top of `build`, resolve the effective starters:

```dart
    final palStarters = ref
        .watch(palSuggestionsProvider(SuggestionSurface.composer))
        .maybeWhen(
          data: (list) => list.isEmpty
              ? null
              : list
                  .map((s) => _Starter(s.icon, s.colorToken, s.label, payload: s.entry))
                  .toList(),
          orElse: () => null,
        );
    final starters = palStarters ?? _starters;
```

4. In the `for` loop that renders chips, iterate `starters` instead of `_starters`:

```dart
          for (var i = 0; i < starters.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.sm),
            _StarterChip(
              starter: starters[i],
              onTap: () => onSendStarter(starters[i]),
            ),
          ],
```

`_StarterChip` and `onSendStarter` are unchanged. `_CompactBody` is built by the parent `build` as `_CompactBody(onSendStarter: _sendStarter)` — no change needed since `ConsumerWidget` still takes constructor args.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/pal/pal_composer_starters_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the existing composer tests for regressions**

Run: `flutter test test/screens/pal/ test/controllers/pal_composer_controller_test.dart`
Expected: PASS (offline fallback still uses `_starters` payloads since the provider yields `[]` in those tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/pal/pal_composer_screen.dart test/screens/pal/pal_composer_starters_test.dart
git commit -m "feat(pal): composer starters from Pal with static fallback"
```

---

### Task 7: Wire the New Entry quick-picks to Pal

Make `_buildQuickPicks` use `palSuggestions(SuggestionSurface.newEntry)` when present, mapping each `PalSuggestion.entry` to the existing `_QuickPick`; fall back to the static `_picks`. Tap behavior (form prefill) unchanged.

**Files:**
- Modify: `lib/screens/entry/new_entry_sheet.dart`
- Test: `test/screens/entry/new_entry_quick_picks_test.dart`

**Interfaces:**
- Consumes: `palSuggestionsProvider` (Task 5).
- `_QuickPick` fields: `kind` (`_Kind`), `icon`, `title`, `label`, `amount` (positive magnitude), `minutes`, `category`, `detail`. Map from `PalSuggestion`:
  - `kind`: from `entry.type` → `_Kind` (money→expense, move→workout, rituals→ritual)
  - `amount`: `entry.amount?.abs()` (the tile expects a positive magnitude)
  - `label`: a display token derived from the entry (money → currency of amount; move → "N min"; ritual → "Routine")

- [ ] **Step 1: Write the failing widget test**

```dart
// test/screens/entry/new_entry_quick_picks_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/models/models.dart';
import 'package:opal/screens/entry/new_entry_sheet.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  testWidgets('New Entry renders Pal quick-pick titles when present', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        palSuggestionsProvider(SuggestionSurface.newEntry).overrideWith(
          (ref) async => const [
            PalSuggestion(
              label: 'Oat latte',
              icon: 'cup.and.saucer.fill',
              colorToken: 'money',
              entry: StarterEntry(type: EntryType.money, title: 'Oat latte', amount: -6, category: 'Coffee'),
            ),
          ],
        ),
      ],
      child: const MaterialApp(home: NewEntrySheet()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Oat latte'), findsOneWidget);
  });
}
```

If `NewEntrySheet` needs additional provider overrides (e.g. `appSettingsControllerProvider`/`sharedPreferencesProvider`), reuse the harness from any existing `new_entry` test under `test/`. The assertion — a Pal-provided title renders — is the deliverable.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/entry/new_entry_quick_picks_test.dart`
Expected: FAIL — only the static `_picks` titles render.

- [ ] **Step 3: Add a `PalSuggestion` → `_QuickPick` adapter and read the provider**

The widget is already a `ConsumerStatefulWidget`, so `ref` is available in `_buildQuickPicks(AppColors c)`. Add a mapper (top-level or private static in the State):

```dart
  _Kind _kindForEntryType(EntryType t) => switch (t) {
        EntryType.money => _Kind.expense,
        EntryType.move => _Kind.workout,
        EntryType.rituals => _Kind.ritual,
      };

  /// Maps a Pal suggestion's entry to the sheet's quick-pick tile. Suggestions
  /// without an entry can't pre-fill the form, so they are skipped.
  _QuickPick? _pickFromSuggestion(PalSuggestion s) {
    final e = s.entry;
    if (e == null) return null;
    final kind = _kindForEntryType(e.type);
    final currency = ref.read(appSettingsControllerProvider).currency;
    final label = switch (e.type) {
      EntryType.money when e.amount != null =>
        formatCurrency(e.amount!.abs(), currency),
      EntryType.move when e.durationMinutes != null => '${e.durationMinutes} min',
      _ => 'Routine',
    };
    return _QuickPick(
      kind: kind,
      icon: s.icon,
      title: e.title,
      label: label,
      amount: e.amount?.abs(),
      minutes: e.durationMinutes,
      category: e.category,
      detail: e.category,
    );
  }
```

(`formatCurrency` is already imported via `../../util/format.dart`.)

At the start of `_buildQuickPicks`, choose the source list:

```dart
  Widget _buildQuickPicks(AppColors c) {
    final palPicks = ref
        .watch(palSuggestionsProvider(SuggestionSurface.newEntry))
        .maybeWhen(
          data: (list) {
            final mapped = list.map(_pickFromSuggestion).whereType<_QuickPick>().toList();
            return mapped.isEmpty ? null : mapped;
          },
          orElse: () => null,
        );
    final picks = palPicks ?? _picks;
    // ... existing rendering, iterating `picks` instead of `_picks`
  }
```

Replace the `_picks` reference inside the method body's rendering with `picks`. (Leave `static const _picks` in place as the fallback.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/entry/new_entry_quick_picks_test.dart`
Expected: PASS.

- [ ] **Step 5: Run existing New Entry tests for regressions**

Run: `flutter test test/screens/entry/`
Expected: PASS (provider yields `[]` in those tests → static `_picks` render as before).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/entry/new_entry_sheet.dart test/screens/entry/new_entry_quick_picks_test.dart
git commit -m "feat(pal): New Entry quick-picks from Pal with static fallback"
```

---

### Task 8: Wire the Routine Generator goals to Pal

Make the goal chips read `palSuggestions(SuggestionSurface.routineGoal)` when present, mapping `PalSuggestion` → `_QuickGoal`; fall back to the static `_goals`. Tap behavior (`_runQuickGoal`) unchanged.

**Files:**
- Modify: `lib/screens/workout/routine_generator_screen.dart`
- Test: `test/screens/workout/routine_generator_goals_test.dart`

**Interfaces:**
- Consumes: `palSuggestionsProvider` (Task 5).
- `_QuickGoal(label, icon, color)`. Map `PalSuggestion` → `_QuickGoal(s.label, s.icon, c.forType(s.colorToken))` — `colorToken` resolves to a `Color` via the existing `AppColors.forType` used elsewhere in the codebase (e.g. `pal_composer_screen.dart`).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/screens/workout/routine_generator_goals_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/screens/workout/routine_generator_screen.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  testWidgets('Routine Generator renders Pal goal labels when present', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        palSuggestionsProvider(SuggestionSurface.routineGoal).overrideWith(
          (ref) async => const [
            PalSuggestion(label: 'Mobility + core, 20 min', icon: 'figure.cooldown', colorToken: 'accent'),
          ],
        ),
      ],
      child: const MaterialApp(home: RoutineGeneratorScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mobility + core, 20 min'), findsOneWidget);
  });
}
```

If the screen needs extra overrides (e.g. `routineGeneratorControllerProvider`), reuse the harness from an existing routine-generator test under `test/`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/workout/routine_generator_goals_test.dart`
Expected: FAIL — only static `_goals` labels render.

- [ ] **Step 3: Read the provider and map to `_QuickGoal`**

In `_RoutineGeneratorScreenState.build`, where `_QuickPicks(goals: _goals(c), ...)` is built, compute the effective goals first:

```dart
    final palGoals = ref
        .watch(palSuggestionsProvider(SuggestionSurface.routineGoal))
        .maybeWhen(
          data: (list) => list.isEmpty
              ? null
              : list.map((s) => _QuickGoal(s.label, s.icon, c.forType(s.colorToken))).toList(),
          orElse: () => null,
        );
    final goals = palGoals ?? _goals(c);
```

Then pass `goals` to the widget:

```dart
              child: _QuickPicks(
                goals: goals,
                disabled: isLoading,
                onPick: _runQuickGoal,
              ),
```

`ref` is available — the screen is a `ConsumerStatefulWidget` (`ref.watch` already used for `routineGeneratorControllerProvider`). Keep `_goals(AppColors c)` as the fallback. Confirm `AppColors.forType(String)` exists (used in `pal_composer_screen.dart`); if the method name differs, use the same accessor that screen uses.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/workout/routine_generator_goals_test.dart`
Expected: PASS.

- [ ] **Step 5: Run existing routine-generator + full suite**

Run: `flutter test test/screens/workout/`
Run: `flutter analyze`
Expected: PASS; no analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/workout/routine_generator_screen.dart test/screens/workout/routine_generator_goals_test.dart
git commit -m "feat(pal): Routine Generator goals from Pal with static fallback"
```

---

### Task 9: Full-suite verification

- [ ] **Step 1: Run the complete client suite**

Run: `flutter test`
Expected: PASS. Fix any golden/context-equality failures introduced by Task 2's new context keys.

- [ ] **Step 2: Run the complete server suite**

Run: `cd server && npm test`
Expected: PASS.

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: No new errors.

- [ ] **Step 4: Commit any test fixups**

```bash
git add -A
git commit -m "test(pal): stabilize suite after context-aware suggestions"
```

(Skip this commit if Steps 1–3 produced no changes.)

---

## Self-Review

**Spec coverage:**
- Client DTO `PalSuggestion` + `SuggestionSurface` + moved `StarterEntry` → Task 1. ✓
- Seam method `suggestions(surface)` on interface + mock → Task 1. ✓
- Data flow (context per surface, cached POST, wire decode) → Task 4. ✓
- Graceful degradation provider → Task 5. ✓
- Three surface adaptations with static fallback → Tasks 6, 7, 8. ✓
- Server endpoint (schema, prompt, model schema + icon map, handler, route) → Task 3. ✓
- Time-of-day context addition → Task 2. ✓
- Caching reuse → Task 4 (`_cachedPost` extended). ✓
- Testing across server/client/surfaces → each task + Task 9. ✓
- Out of scope (notifications, hint text, streaming) → not planned. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. Two tests note "reuse the existing harness if a bare pump fails" — this is a real, actionable instruction (mirror an existing test), not a placeholder; the asserted deliverable is explicit in each.

**Type consistency:**
- `StarterEntry` single definition (moved in Task 1; consumed in Tasks 4, 6, 7). ✓
- `SuggestionSurface` wire mapping (`composer`/`newEntry`/`routineGoal`) consistent across Task 1 (enum), Task 3 (zod enum + prompt switch), Task 4 (`_surfaceWire`). ✓
- Wire `entry` shape `{type,title,amount,category,minutes}` consistent: server output (Task 3) ↔ client decode (Task 4). Note the naming seam: server/wire uses `minutes`; client `StarterEntry` uses `durationMinutes` — Task 4's decoder maps `minutes` → `durationMinutes` explicitly. ✓
- `colorToken` set `money|move|rituals|accent` consistent (Task 1 free string clamped client-side; Task 3 `colorToken` const). ✓
- `PalSuggestion` field names (`label`,`icon`,`colorToken`,`entry`) identical across Tasks 1, 4, 5, 6, 7, 8. ✓

No issues found requiring rework.
