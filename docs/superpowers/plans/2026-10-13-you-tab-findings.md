# You Tab and One Home for Patterns Implementation Plan

**Verify:** `flutter test --exclude-tags scenario`
**Setup:** `flutter pub get`
**Check:** `flutter analyze --fatal-infos`
**Final:** `flutter test --tags scenario test/scenario`
**Prototype:** C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first-you\project\Main.dc.html

**Goal:** Rebuild the You tab to the `onYou` branch of the oura-ai-first canvas and DESIGN.md
section 11 decision 2 (as committed in bd071f1): a header line, Pal's findings (lead, then Also
seen, each dismissable), a Pal group opening What Pal remembers and Autopilot, then seven
settings rows. Money spend patterns and Nutrition's takeout pattern become Pal findings, so
findings are the one home for patterns.

**Architecture:** A pure `PalFinding` model with one builder per source (on-device
correlations, spend patterns, Nutrition patterns, Pal's server memory patterns) lives in
`lib/analysis/pal_findings.dart`. One Riverpod notifier merges the sources, drops dismissed ids
(persisted in `SettingsRepository`), and owns `dismiss`/`dismissAll`. The You tab and What Pal
remembers both read that notifier, so a dismissal leaves both lists. What Pal remembers and
Autopilot are new screens pushed with `Navigator.push`, because `lib/router.dart` belongs to a
parallel run.

**Tech Stack:** Flutter, Riverpod 3 (codegen via build_runner), go_router 16, SharedPreferences,
flutter_test goldens and scenario tests.

**Design source.** No spec file: the canvas settles the design, and the decisions below were
approved in the `Spec review`. The Prototype is a copy of the `Main.dc.html` board of
`C:\Users\cktra\Projects\opal\.superpowers\design\oura-ai-first\project\`, in a folder of its own
so the widget board (owned by run d992017c) is not part of this run. Read it from its absolute
path (it is gitignored, not in the worktree). That folder holds only `Main.dc.html` (plus its
`support.js` and `canvas.json`): the rings widget board is not part of this run's canvas, and
run d992017c renders and verifies it. In this folder:
- The markup between `<sc-if value="{{onYou}}">` and its closing tag is You.
- The `sub.isMemory` and `sub.isAutopilot` blocks are the two sub-screens. Their back header is
  the shared `sub.open` header just above them.
- The script's `FINDINGS`, `shownFindings`, `findingView`, `memory`, `autopilot`, `palRows`,
  `settingRows`, `youLine` and `patternsMode` are its behaviour.

Its sentences and numbers are sample data. Inline styles are the measurements: map them onto
the existing tokens (`Spacing`, `AppType`, `context.colors`; the serif lead uses the bundled
`Newsreader` family as Today's lead does). Also read `DESIGN.md` sections 2, 4, 7, 9 and 11.

Out of scope: the board's other views (Today, Areas, Workout, area focus pages, meal detail), the
answer sheet, the composer's per-screen chip, and the tab bar.

## Approved decisions (beyond the canvas)

1. **One finding model.** `PalFinding` holds an id, area labels, a line, an optional serif lead,
   evidence, an optional a/b comparison and a composer question. It is built from four sources,
   in this order:
   - surfaced correlations, strongest first;
   - spend patterns as Money findings;
   - Nutrition's patterns, only when the first spark value is above 0 (there was takeout);
   - Pal's server memory patterns (`PalMemoryDigest.patterns`).
2. **Dismissal is persisted.** Dismissed ids are stored in SharedPreferences through
   `SettingsRepository` and survive restarts. An id encodes the claim, so a changed finding
   (another peak weekday, a flipped correlation sign) comes back as new.
3. **Lead.** The lead is the first finding, in source order, that has a comparison. Every other
   shown finding goes under Also seen, in order. A finding without a comparison shows its line and
   evidence only, with no bars. If no finding has a comparison, there is no lead and every finding
   is listed under Also seen, with the "Also seen" heading kept.
4. **Tap opens the composer.** Tapping a finding opens the Pal composer seeded with
   `finding.question`. Copy the existing seed pattern in `lib/widgets/correlation_card.dart`
   (`_AskPalButton`).
5. **States.** This is a spec change from the canvas, approved after plan review round 1.
   - **Still learning** (canvas `patternsLearning` block, same layout): shown when there are no
     findings and N < `kMinPairedDays` (21). N is the whole days from
     `ProfileStats.memberSince` to today, counting today, and 0 with no history. The canvas's 14
     days "across two areas" is replaced, because the correlation bar is 21 paired days and
     spend patterns need only Money. The block holds:
     - the Pal eyebrow;
     - the serif `Still learning your patterns.`;
     - the body `Patterns need 21 days of logging. You have N, so the first ones should show up
       <when>.`, where <when> is the weekday name (`Thursday`) when the 21st day is 1 to 6 days
       away and `on <kMonthsShort> <day>` (`on Nov 2`) when it is further. With N = 0 the body
       is `Patterns need 21 days of logging. Log a few things and Pal starts looking.`;
     - a 4 px bar filled N/21, with the caption `N of 21 days` and the semantics label
       `N of 21 days logged`.
   - **No patterns right now** (canvas copy): no findings and N >= 21.
   - **Couldn't load** (`Couldn't load Pal's findings.`): the findings notifier is in error.
   - The canvas's offline line is dropped: findings are computed on the device.
6. **Header.** `<name> · N-day workout streak` when `moveStreakDays` is above 0, else
   `<name> · Tracking since <Month Year>`. With no history it is `<name> · Just getting started`.
7. **Sub-screens.** What Pal remembers and Autopilot open with `Navigator.of(context).push` (a
   `CupertinoPageRoute`). No new routes; do not edit `lib/router.dart`.
8. **Clear what Pal remembers.** It uses the canvas's inline confirm, not a dialog. Yes calls
   `PalService.clearMemory()`, then dismisses every current finding. If the server call fails,
   nothing is dismissed and an error is shown.
9. **Autopilot is session state.** Switches live in a keep-alive provider for the app session and
   are not persisted. There is no server endpoint, so a switch cannot stop the task yet. This is
   flagged in the final report, not faked with persistence.
10. **Settings rows.**
    - Goals opens `AppRoute.budgetsGoals`.
    - Budgets opens `AppRoute.youBudgets`.
    - Reviews, value `Day · Week · Month`, opens `AppRoute.recap` with `range=day`.
    - Email sync opens `AppRoute.emailSync`, value `Gmail · On` or `Not connected` from
      `emailDashboardControllerProvider`.
    - Data and privacy opens `AppRoute.privacy`.
    - Appearance opens `AppRoute.appearance`.
    - About and help opens `AppRoute.about`.
    - The Privacy screen gains Export data (`AppRoute.exportData`) and Notifications
      (`AppRoute.notificationSettings`) rows.
    - All stats, Help & feedback, Daily budget, Workout goal and Daily routines rows leave You.
11. **What leaves You.** The What Pal noticed feed leaves You; `pal_noticed_section.dart` stays
    in the code, unlinked. `lib/screens/pal/pal_agenda_widgets.dart` is deleted: its only
    importer is `profile_screen.dart`.
12. **The Areas block** in `profile_screen.dart` (the `// --- Areas ---` comment through its
    `_Group` closing) stays byte-for-byte, placed after the Pal group and before Settings.
    - It is on neither the canvas nor DESIGN.md 11.2. It stays because it is the only way into
      the area pages until the parallel Areas-tab run lands the Areas tab, and that run deletes
      the block as one untouched unit. A moved or edited block would collide with its delete.
    - Its `_Group`, `_Label` and `ListRow` dependencies stay.
    - The Insights row is removed.
13. **Follow-up, not this run.** DESIGN.md makes findings the only patterns surface, but the old
    Insights (`/you/insights`) and Nutrition patterns (`/nutrition/patterns`) screens stay
    reachable:
    - their routes stay, because route changes belong to the Areas-tab run;
    - `nutrition_screen.dart` still links the patterns screen, and the Areas-tab run owns that
      file.
    Retiring both screens is a follow-up task for the run lead, recorded in the final report.
14. **The dismiss x on You findings** is beyond the canvas (approved in brainstorming: "both
    places").
15. **Paid entitlements.** None needed (personal app on AltStore, free Apple account).

## Global Constraints

- Do not edit files owned by parallel runs:
  - `lib/router.dart`, `lib/screens/shell/*`, `lib/widgets/glass_tab_bar.dart`;
  - the Areas tab and area pages (`lib/screens/detail/*`);
  - `lib/screens/nutrition/*`, `lib/screens/sleep/*`, `lib/screens/mood/*`;
  - the iOS widget and `lib/controllers/widget_sync_controller.dart`,
    `lib/services/widget_sync/*`;
  - `test/scenario/final_scenario_test.dart`.
- The old insights and nutrition patterns routes stay in place. Only You stops linking Insights.
- No emojis. Comments only for "why", lower case. Sentence-case copy, as in the canvas.
- Errors from the Pal service are shown to the user (floating SnackBar above the shell overlay,
  as `_showError` in `profile_screen.dart` does today) and logged with `debugPrint` with context.
  Never silently swallowed.
- A finding source that fails to load is logged with `debugPrint` and contributes no findings;
  the other sources still show.
- Every tappable control is at least 44 by 44 and carries a semantics label. Dismiss is
  `Dismiss: <line>`, forget is `Forget: <fact>`, switches use `role: switch` semantics with
  their title.
- Riverpod providers use codegen (`@riverpod`); regenerate with
  `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files.

## Review Focus

1. A dismissed finding after an app restart should stay gone, on You and in Patterns Pal uses
   (Task 1 test: a new container over the same prefs).
2. Dismissing the lead should promote the next finding with a comparison, not leave an empty lead
   (Task 1 and Task 5 tests).
3. A failed Clear (server error) should keep every fact and finding and say so (Task 4 test).
4. With the Pal backend unreachable, the on-device findings should still show (Task 1 test: memory
   source throws).
5. A long display name or 4-digit streak should wrap the header line, not overflow at large text
   sizes (Task 5 test at text scale 2).

---

### Task 1: Pal findings model, sources and dismissal
**Depends on:** none
**Files:** `lib/analysis/pal_findings.dart`, `test/analysis/pal_findings_test.dart`, `lib/controllers/pal_findings_controller.dart`, `lib/controllers/pal_findings_controller.g.dart`, `test/controllers/pal_findings_controller_test.dart`, `lib/data/repositories/settings_repository.dart`, `test/settings_repository_test.dart`

Build the one finding list both screens read.

**Interfaces (produced; Tasks 4 and 5 rely on these exact names):**

```dart
// lib/analysis/pal_findings.dart
class FindingSide { const FindingSide({required this.label, required this.value, required this.fraction}); final String label; final String value; final double fraction; } // fraction 0..1 of the larger side
class PalFinding {
  const PalFinding({required this.id, required this.areas, required this.line, this.lead, required this.evidence, this.a, this.b, required this.question});
  final String id; final List<String> areas; final String line; final String? lead;
  final String evidence; final FindingSide? a; final FindingSide? b; final String question;
  bool get hasComparison => a != null && b != null;
  String get areasLabel; // areas joined: 'Sleep', 'Sleep and Money', 'A, B and C'
}
List<PalFinding> findingsFromCorrelations(List<Correlation> correlations);
List<PalFinding> findingsFromSpendPatterns(SpendPatterns patterns, Currency currency);
List<PalFinding> findingsFromNutritionPatterns(List<NutritionPattern> patterns);
List<PalFinding> findingsFromPalPatterns(List<InsightPattern> patterns);

// lib/controllers/pal_findings_controller.dart
@riverpod class PalFindingsController // provider: palFindingsControllerProvider
  Future<List<PalFinding>> build();   // all sources in source order, dismissed ids removed
  Future<void> dismiss(String id);
  Future<void> dismissAll();          // dismisses every finding currently shown

// lib/data/repositories/settings_repository.dart
Set<String> get dismissedFindings;                    // key 'settings.pal.dismissedFindings'
Future<void> addDismissedFindings(Iterable<String> ids);
```

**Ids:** each id encodes the claim, so a changed finding is new:
- `corr:<a.name>-<b.name>:<+|->`;
- `money:biggest-day:<peakWeekday>`, `money:weekend-split:<weekend|weekday>`,
  `money:daypart-peak:<daypart.name>`, `money:no-spend-streak`, `money:unusual:<entry.id>`;
- `nutrition:<pattern.title>`;
- `pal:<pattern.title>`.

**Area labels:**
- Dimensions map to Money, Move, Routines (`rituals`), Nutrition, Sleep, Mood.
- `colorToken` maps the same way (`rituals` to Routines; an unknown token gives no area label).
- Nutrition findings are `['Nutrition', <tracker area>]`, without a duplicate when the tracker
  is nutrition.

**Wording.** Plain declaratives in the canvas's voice. The evidence line is short. `question` is
`'Tell me more: <line>'`.
- **Correlation with a breakdown.** Line: `<Continuous area> runs <higher|lower> on
  <activeDayLabel>.` Side a is the capitalised `activeDayLabel` with
  `formatValue(continuousDim, meanWhenActive)`; side b is the inactive side. Evidence:
  `<countActive> <activeDayLabel>, <countInactive> <inactiveDayLabel>`.
- **Correlation without a breakdown.** Line: `More <dimensionNoun(a)> goes with <more|less>
  <dimensionNoun(b)>.` No comparison. Evidence: `Over <n> days`.
- **biggestDay.** Line: `You spend most on <Peak weekday>s.` Side a is the peak weekday with
  `<amount> a day`; side b is the quiet weekday. Evidence: `Last 30 days`.
- **weekendSplit.** Line: `Weekends cost more than weekdays.` or the reverse. Sides: `Weekend
  days` and `Weekdays`, each `<amount> a day`.
- **daypartPeak.** Line: `<Daypart> takes <share>% of your spending.` Sides: the daypart total,
  and `Rest of the day` (window total minus it, from `total / share`).
- **noSpendStreak.** Line: `<n> days without spending.` No comparison. Evidence:
  `Ending yesterday`.
- **unusual.** Line: `<entry.title> was <multiple rounded>x your usual expense.` Side a is the
  entry with its amount; side b is `Your usual expense` (amount divided by the multiple).
  Evidence: the entry date as `kMonthsShort day`.
- **Nutrition.** Line: `pattern.body`. Sides: `Takeout meals` (`spark[0]`) and
  `Cooked at home` (`spark[1]`). Evidence: `This week`. Skipped when `spark` is empty or
  `spark[0] == 0`.
- **Server pattern.** Line: `title`. Evidence: `detail`. No comparison.

Money amounts use `formatCurrency` from `lib/util/format.dart`. The fraction of each side is its
value over the larger side's value, 0 when both are 0.

**Controller.** It reads:
- `surfacedCorrelationsProvider.future`;
- the first value of `spendPatternsProvider`;
- `nutritionControllerProvider`'s `patterns`;
- `palMemoryProvider.future`'s `patterns`;
- `appSettingsControllerProvider`'s currency.

It concatenates the sources in that order and filters out `SettingsRepository.dismissedFindings`.
Each source is awaited in its own try/catch: a failure is `debugPrint`ed with the source name and
yields no findings from that source. `dismiss` and `dismissAll` persist through
`addDismissedFindings`, then update `state` without a refetch, so both screens drop the row
immediately.

Do not edit `nutrition_controller.dart`, `spend_patterns_controller.dart` or
`correlations_controller.dart`.

**Acceptance and focused tests:**
- `test/analysis/pal_findings_test.dart`:
  - one test per builder covering line, sides, evidence, id and areas;
  - a correlation with `r < 0` gets a `:-` id;
  - a Nutrition pattern with `spark[0] == 0` yields nothing;
  - an unknown `colorToken` yields an empty areas list;
  - `areasLabel` for one, two and three areas.
- `test/controllers/pal_findings_controller_test.dart`, with providers overridden:
  - sources concatenate in source order;
  - `dismiss` removes the id from `state`;
  - a new `ProviderContainer` over the same SharedPreferences still omits it (restart);
  - `dismissAll` empties the list;
  - with `palMemoryProvider` throwing, correlation and money findings still return;
  - dismissing the lead leaves the next finding with a comparison first among those with one.
- `test/settings_repository_test.dart`: `addDismissedFindings` unions with the existing set, and
  the getter reads back.

Run: `flutter test test/analysis/pal_findings_test.dart test/controllers/pal_findings_controller_test.dart test/settings_repository_test.dart`

### Task 2: Autopilot screen and session switches
**Depends on:** none
**Files:** `lib/controllers/autopilot_controller.dart`, `lib/controllers/autopilot_controller.g.dart`, `lib/screens/you/autopilot_screen.dart`, `test/screens/you/autopilot_screen_test.dart`

Build the canvas's `sub.isAutopilot` screen.

**Interfaces (produced; Task 5 relies on these):**

```dart
// lib/controllers/autopilot_controller.dart
@Riverpod(keepAlive: true) class AutopilotSwitches // provider: autopilotSwitchesProvider
  Map<String, bool> build();            // overrides by item id; empty at start
  bool isOn(PalAutopilotItem item);     // override, else item.enabled
  void toggle(PalAutopilotItem item);
// lib/screens/you/autopilot_screen.dart
class AutopilotScreen extends ConsumerWidget { const AutopilotScreen({super.key}); }
```

**Screen layout:**
- A back control labelled `You`, which pops.
- Eyebrow `Pal`, title `Autopilot`.
- Intro: `What Pal handles quietly. Switch any of it off.`
- One hairline-topped row per `palAgendaProvider` autopilot item: title, subtitle, and a switch
  (`CupertinoSwitch`, track `c.ink` when on, as the canvas).
- While the agenda loads: nothing below the intro. With no items: `Nothing on autopilot yet.`
- On error: `Couldn't load autopilot.`

The switch flips through `autopilotSwitchesProvider` and survives popping and re-pushing the
screen. Do not import `pal_agenda_widgets.dart` (Task 5 deletes it).

**Acceptance and focused tests (`test/screens/you/autopilot_screen_test.dart`):**
- rows render from an overridden agenda;
- tapping a switch flips it, and its semantics report checked;
- the state survives pop and push in one `ProviderScope`;
- empty and error copy.

In the Final run, these views and interactions are shown by Task 5's scenario steps:
- `you_autopilot`: the rows, and flipping Coffee nudge (off by default) to on;
- `you_autopilot_empty`: the empty copy;
- `you_autopilot_error`: the error copy.

Run: `flutter test test/screens/you/autopilot_screen_test.dart`

### Task 3: Export data and Notifications under Privacy
**Depends on:** none
**Files:** `lib/screens/settings/privacy_screen.dart`, `test/screens/privacy_screen_test.dart`

You's `Data and privacy` row opens Privacy, so Privacy becomes the home of the two rows leaving
You. Add a section after the existing ones, in the same `InsetSection`/`ListRow` style, with:
- `Export data`, which pushes `AppRoute.exportData`;
- `Notifications`, which pushes `AppRoute.notificationSettings`.

The nav bar title becomes `Data and privacy`; the leading label stays `You`. Update the class doc
comment, which says "No toggles"; that stays true.

**Acceptance and focused tests (`test/screens/privacy_screen_test.dart`):**
- both rows render;
- tapping each lands on its screen, in a `GoRouter` test harness as the existing test builds it;
- the title reads `Data and privacy`.

The view is shown in the Final run by Task 5's scenario step `you_data_privacy`.

Run: `flutter test test/screens/privacy_screen_test.dart`

### Task 4: What Pal remembers screen
**Depends on:** Task 1
**Files:** `lib/screens/you/pal_memory_screen.dart`, `test/screens/you/pal_memory_screen_test.dart`

Build the canvas's `sub.isMemory` screen.

**Interface (produced; Task 5 relies on it):**
`class PalMemoryScreen extends ConsumerStatefulWidget { const PalMemoryScreen({super.key}); }`

**Consumes:** `palMemoryProvider` (facts), `palFindingsControllerProvider` (patterns),
`palServiceProvider` (`deleteFact`, `clearMemory`).

**Screen layout:**
- A back control labelled `You`. Eyebrow `Facts and preferences Pal uses`, title
  `What Pal remembers`.
- **Facts you told Pal:** one row per fact with an x (`Forget: <text>`). The x calls
  `deleteFact`, then invalidates `palMemoryProvider`. On failure the row stays, with
  `Couldn't forget that. Try again.`
- **Patterns Pal uses:** caption `The same patterns as Pal noticed on You. Dismiss one and it
  leaves both.` One row per shown finding: `line`, with `areasLabel` as meta, and an x
  (`Dismiss: <line>`) that calls `dismiss(id)`.
- **Empty** (no facts, no findings): `As we talk, I'll note facts you mention and patterns I
  learn here. You can delete anything.` The Clear row is hidden.
- **Clear** (inline, as the canvas):
  - Idle: a red `Clear what Pal remembers` button.
  - Asking: `Clear everything Pal remembers?` with `Cancel` and red `Clear`.
  - Clear calls `clearMemory()`; on success it calls `dismissAll()` and invalidates
    `palMemoryProvider`.
  - On failure nothing is dismissed, the confirm closes, and the screen shows
    `Couldn't clear what Pal remembers. Try again.`

Errors show as a SnackBar, as the Global Constraints say.

**Acceptance and focused tests (`test/screens/you/pal_memory_screen_test.dart`, with a fake
`PalService` and overridden providers):**
- forget removes the row;
- a failed forget keeps it and shows the message;
- dismissing a pattern removes it here and from `palFindingsControllerProvider`'s state;
- Clear asks inline first, and Cancel restores the idle button;
- Clear wipes facts and patterns;
- a failed Clear keeps every fact and pattern and shows the message;
- empty state copy;
- semantics labels on the x buttons.

In the Final run, these views and interactions are shown by Task 5's scenario steps:
- `you_memory`: both sections;
- `you_memory_forget`: forgetting a fact;
- `you_memory_clear_ask`: the inline confirm;
- `you_memory_cleared`: Clear confirmed, showing the empty copy;
- `you_memory_forget_failed` and `you_memory_clear_failed`: the error messages, with the rows
  kept.

Run: `flutter test test/screens/you/pal_memory_screen_test.dart`

### Task 5: Rebuild the You tab to the canvas
**Depends on:** Task 1, Task 2, Task 3, Task 4
**Files:** `lib/screens/profile/profile_screen.dart`, `lib/screens/pal/pal_agenda_widgets.dart`, `test/support/golden_harness.dart`, `test/profile_test.dart`, `test/pal_home_test.dart`, `test/screens/pal_home_memory_test.dart`, `test/deep_link_routing_test.dart`, `test/golden/goldens/profile_dark.png`, `test/golden/goldens/profile_light.png`, `test/scenario/you_scenario_test.dart`

Rebuild `ProfileScreen` to the `onYou` markup, top to bottom:

1. **Header.** Title `You` with the header line (decision 6) on the same row. It wraps under the
   title when it does not fit.
2. **Findings** from `palFindingsControllerProvider` (decisions 3 and 5).
   - The lead block: sparkles plus `Pal noticed · <areasLabel>`, the serif `lead ?? line`, the
     a/b bars when it has a comparison, then the evidence row with a chevron.
   - `Also seen`: hairline rows of `line` plus `<areasLabel> · <evidence>`, each with a chevron.
   - Each finding has a 44 by 44 x (`Dismiss: <line>`) that calls `dismiss(id)` (the approved
     "both places").
   - Tapping a finding opens the composer seeded with `question` (decision 4).
   - Loading shows nothing. An error shows `Couldn't load Pal's findings.`
3. **Pal group.** Heading `Pal`.
   - `What Pal remembers`, value `<n> facts` from `palMemoryProvider`, pushes `PalMemoryScreen`.
   - `Autopilot`, value `<n> on` from `palAgendaProvider` and
     `autopilotSwitchesProvider.isOn`, pushes `AutopilotScreen`.
   - Both push with `Navigator.of(context).push(CupertinoPageRoute(...))`.
4. **The Areas block**, byte-for-byte (decision 12).
5. **Settings** (decision 10): heading `Settings`, then the seven hairline rows with values and
   chevrons.

Remove the profile card, the old Goals/Money/Reviews/Integrations/Data/Account groups, the
BudgetSheet opener, `_StreakPill`, the What Pal noticed feed, the autopilot and dismissed-pattern
state, and the dialog-based wipe. Delete `lib/screens/pal/pal_agenda_widgets.dart` after grepping
that nothing else imports `MemoryCard`, `AutopilotCard`, `AutopilotRow` or the file.

Update tests that asserted the old You:
- `pal_home_test.dart`: drop the memory, autopilot and noticed-feed cases on You (Task 4 and
  Task 2 cover them) and the BudgetSheet case. Keep the proposal cases and the `/pal` lands on
  You cases, which assert `What Pal remembers` as a row.
- `pal_home_memory_test.dart`: assert a learned server pattern shows as a finding on You.
- `profile_test.dart`: the header line replaces the streak pill. Keep the Areas group tests
  unchanged.
- `deep_link_routing_test.dart`: only if it breaks.

Regenerate the profile goldens:
`flutter test --update-goldens test/golden/design_system_golden_test.dart --plain-name profile`

**Acceptance and focused tests (`test/profile_test.dart` and `test/pal_home_test.dart`):**
- the header line with a streak, without one, and with no history;
- the lead shows the first finding with a comparison, and Also seen the rest;
- dismissing the lead on You promotes the next one and removes it from Patterns Pal uses (push
  the memory screen in the same scope);
- the Still learning copy for N = 9 (weekday), N = 2 (`on <Mon d>`) and N = 0, with the bar
  caption and semantics label;
- the No patterns and Couldn't load states;
- the Pal rows show counts and push their screens;
- each settings row lands on its route (Reviews carries `range=day`);
- no `Insights` row exists;
- the `AREAS` group still opens Money as before;
- at text scale 2, a 40-character name with a 1000-day streak shows no overflow.

**Scenario harness change.** Add `List<Override> overrides = const []` to `bootApp` in
`test/support/golden_harness.dart`, appended after its three existing overrides. Existing
callers are unchanged.

**Scenario fixtures.** These live in `test/scenario/you_scenario_test.dart`, with no runtime
branching.

`_fixedFindings` is two `PalFinding`s copied from the canvas's `FINDINGS`:
- `sleepMoney`: id `corr:sleep-money:+`, areas `['Sleep', 'Money']`, line `Short nights cost you
  about $18 the next day.`, lead `Last night was short. Short nights cost you about $18 the next
  day.`, evidence `Seen after 9 of 11 short nights`. Side a is `After under 7 h`, `$71 a day`,
  fraction 71/80; side b is `After 7 h or more`, `$53 a day`, fraction 53/80.
- `moodMove`: id `corr:move-mood:+`, areas `['Move', 'Mood']`, line `Your better days follow a
  workout.`, evidence `12 workout days, 18 without`. Side a is `After a workout`, `4.1 of 5`,
  fraction 4.1/5; side b is `Other days`, `3.2 of 5`, fraction 3.2/5.

Both use `question: 'Tell me more: <line>'`.

`_FixedFindings extends PalFindingsController`: `build()` returns a list given to its
constructor; `dismiss` and `dismissAll` are inherited. It is installed with
`palFindingsControllerProvider.overrideWith(() => _FixedFindings(list))`. A `_ThrowingFindings`
whose `build()` throws `StateError('scenario')` covers the error state.

`_ScenarioPal extends MockPalService(latency: Duration.zero, seed: 0)` overrides:
- `memory()` and `refreshMemory()`: return its own `facts` list (seeded with the canvas's
  `No caffeine after 2 PM`, `Prefers to train before 6 PM` and `Dinner out with friends on
  Fridays`, ids `f1` to `f3`) and no patterns;
- `deleteFact()` and `clearMemory()`: act on that list, or throw `StateError('scenario')` when
  `failWrites` is true;
- `agenda()`: returns `super.agenda()` with the autopilot list replaced by `[]` when
  `autopilot == _Autopilot.empty`, or throws when it is `_Autopilot.error`. The default is
  `_Autopilot.seeded`.

Pass it through `bootApp(palService:)`. A `profileStatsProvider` override with
`memberSince` set to 9 days before `goldenClock`'s now covers Still learning.

**Scenario steps.** Each step asserts its view and calls `shot(tester, '<step>_<theme>')`.

`scenarioTest('you', ...)` uses `_FixedFindings(_fixedFindings)` and the default `_ScenarioPal`:
- `you_top`: tap the `You` tab; assert the header line, the sleepMoney lead with its bars and
  `Also seen` with moodMove.
- `you_finding_composer`: tap the lead; assert the composer opens with
  `Tell me more: Short nights cost you about $18 the next day.` in its field; close it.
- `you_dismissed`: tap `Dismiss: Short nights cost you about $18 the next day.`; assert moodMove
  now leads and `Also seen` is gone.
- `you_settings`: scroll to `Settings`; assert all seven rows and their values.
- `you_row_goals`, `you_row_budgets`, `you_row_reviews`, `you_row_email`, `you_row_appearance`,
  `you_row_about`: tap each row; assert its screen (`BudgetsGoalsScreen`, `BudgetsScreen`,
  `RecapScreen` with `initialRange == InsightRange.day`, `EmailIntroScreen`, `AppearanceScreen`, `AboutScreen`); go
  back.
- `you_data_privacy`: tap `Data and privacy`; assert the `Data and privacy` title and the
  `Export data` and `Notifications` rows; go back.
- `you_memory`: tap `What Pal remembers`; assert the three facts and `Patterns Pal uses` listing
  moodMove (sleepMoney was dismissed above, so the dismissal shows in both lists).
- `you_memory_forget`: tap `Forget: No caffeine after 2 PM`; assert the fact is gone.
- `you_memory_clear_ask`: tap `Clear what Pal remembers`; assert
  `Clear everything Pal remembers?` with `Cancel` and `Clear`.
- `you_memory_cleared`: tap `Clear`; assert the empty copy `As we talk, I'll note facts you
  mention and patterns I learn here. You can delete anything.`; go back.
- `you_autopilot`: tap `Autopilot`; assert the three rows; flip `Coffee nudge at $15 / wk`
  (enabled false in `MockPalService`) and assert its switch reports checked.

Then one `scenarioTest` per state, each named after its step and each with a single `bootApp`
call carrying that state's overrides:
- `you_learning`: empty `_FixedFindings` plus the 9-day `profileStatsProvider` override; assert
  `Still learning your patterns.`, the body ending `show up <weekday>.` and `9 of 21 days`.
- `you_no_patterns`: empty `_FixedFindings` on the seeded history; assert
  `No patterns right now. Pal looks again as new days come in.`
- `you_findings_error`: `_ThrowingFindings`; assert `Couldn't load Pal's findings.`
- `you_memory_forget_failed`: `_ScenarioPal(failWrites: true)`; open What Pal remembers; tap a
  forget; assert `Couldn't forget that. Try again.` and the fact still listed.
- `you_memory_clear_failed`: `_ScenarioPal(failWrites: true)`; open What Pal remembers; tap `Clear what Pal remembers`, then `Clear`; assert
  `Couldn't clear what Pal remembers. Try again.` and every fact still listed.
- `you_autopilot_empty`: `_ScenarioPal(autopilot: _Autopilot.empty)`; open Autopilot; assert
  `Nothing on autopilot yet.`
- `you_autopilot_error`: `_ScenarioPal(autopilot: _Autopilot.error)`; open Autopilot; assert
  `Couldn't load autopilot.`

Run: `flutter test test/profile_test.dart test/pal_home_test.dart test/screens/pal_home_memory_test.dart`, then `flutter test --tags scenario test/scenario/you_scenario_test.dart`
