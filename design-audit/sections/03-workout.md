# Workout Flow

Audit of the full gym-workout flow: design (React/JSX `ExpensePal` prototype, source of truth) vs. current Flutter (`opal`). Each bullet is tagged `[MISSING]` (design element absent in Flutter), `[DIFFERENT]` (present but behaves/looks differently), `[COPY]` (text mismatch), `[LAYOUT]` (placement/ordering), or `[STYLE]` (color/type/token).

Design files: `workout-screens.jsx`, `workout-screens2.jsx`, `routine-generator.jsx`, `workout-data.jsx`, `more-screens.jsx`, README spec.
Flutter files: `lib/screens/workout/*.dart`, `lib/screens/library/exercise_library_screen.dart`, `lib/screens/move/weekly_plan_screen.dart`.

> Note on the rename handoff: `Handoff - Workout Rename & Budget Editor.md` renames the tracker "Move" → "Workout" (display copy only; data keys like `theme.move` unchanged). Several copy items below are evaluated against that rename, since the Flutter code is mid-migration (router paths are still `/move`, the start screen nav still says "Start workout"/"Pick a workout or freestyle").

---

## 08 · Start Workout (`start_workout_screen.dart` vs `PreWorkoutScreen` in workout-screens.jsx)

- **[COPY] Nav subtitle differs.** Design: `subtitle="Pick a routine or freestyle"` (workout-screens.jsx L31; README L426 "Pick a routine or freestyle"). Flutter: `subtitle: 'Pick a workout or freestyle'` (start_workout_screen.dart L70). "routine" → "workout".
- **[MISSING] Pal's-pick card is far simpler in Flutter.** Design's card (workout-screens.jsx L36-118) contains: two decorative radial blobs, a hardcoded title "Pull Day A", a `5 exercises · 58 min · last done 5 days ago` meta line, the AI suggestion paragraph, **an exercise-preview chip strip** (`['Deadlift','Pull-up','Barbell Row','Face Pull','Bicep Curl']` as rounded pills, L83-92), then Start + "Other" buttons. Flutter renders eyebrow + title + meta + rationale + Start/"Another" only — **no decorative blobs and no exercise-preview chip strip** (start_workout_screen.dart `_PalPickCard` L185-314).
- **[COPY] Regenerate pill label differs.** Design button reads `Other` (idle) / `Thinking…` (loading) (workout-screens.jsx L113). Flutter reads `Another` / `Thinking…` (start_workout_screen.dart L386).
- **[STYLE] Pal-pick card corner radius.** Design `borderRadius: 18` (L39). Flutter `BorderRadius.circular(20)` (L206).
- **[DIFFERENT] Strength card content omits the exercise mini-stack.** Design `RoutineCard` (workout-screens.jsx L167-259) shows a **colored header band with diagonal stripe texture**, then a body listing the **top-3 exercise names with bullet dots** + "+ N more", a divider, and two stats: `estMin` ("est", with an "m" suffix) and **total sets** ("sets"), plus a `lastDone` label ("3d ago"). Flutter `_RoutineCard` (start_workout_screen.dart L398-485) shows the colored band (no stripe texture), and a footer with only **EXERCISES** and **EST** mini-stats. Missing: exercise name mini-stack, "+N more", the **sets** stat, the **lastDone** label, and the diagonal-stripe decoration.
- **[DIFFERENT] EST value is computed, not the routine's `estMin`.** Design uses each routine's hardcoded `estMin` (55/58/62/45). Flutter derives minutes via `_estMinutes()` heuristic (`totalSets * (restSeconds + 35)`, rounded to 5) (start_workout_screen.dart L620-628), so displayed estimates will not match the design's per-routine numbers.
- **[MISSING] Cardio row is much richer in design.** Design `CardioRow` (workout-screens.jsx L262-325): left colored panel uses the **exercise's SF symbol** (`exMeta.sf`) over a 45° stripe texture; body shows the routine name, then **distance (km) or minutes**, a **pace** value ("pace"), and a `lastDone` label. Flutter `_CardioRow` (start_workout_screen.dart L488-574) hardcodes `figure.run`, shows only `{est} min`, and omits distance, pace, and lastDone.
- **[COPY/LAYOUT] Quick-actions section differs in items, order, copy, and icons.** Design `Section` (workout-screens.jsx L152-161), in order:
  1. `sparkles` / **"Generate with AI"** / "Describe the workout you want"
  2. `plus` / **"New routine"** / "Build from scratch"
  3. `books.vertical.fill` / **"Exercise library"** / "{N} exercises"
  4. `bolt.fill` / **"Freestyle session"** / "Log as you go"

  Flutter (start_workout_screen.dart L123-156), in order:
  1. `plus` / **"New workout"** / "Build from scratch"
  2. `sparkles` / **"Generate with Pal"** / "Describe a goal, Pal builds it"
  3. `dumbbell.fill` / **"Exercise library"** / "Browse all exercises"
  4. `play.fill` / **"Freestyle"** / "Log as you go"

  Differences: order (New first vs Generate first), titles ("New routine"→"New workout", "Generate with AI"→"Generate with Pal", "Freestyle session"→"Freestyle"), all three subtitles, and icons (`books.vertical.fill`→`dumbbell.fill`, `bolt.fill`→`play.fill`).
- **[STYLE] Section-header eyebrow casing.** Design renders "Strength · 4" / "Cardio · 1" as written (CSS `textTransform: 'uppercase'`). Flutter uppercases via `.toUpperCase()` (start_workout_screen.dart L172) — matches visually, no issue.

---

## 09 · Active Session (`active_session_screen.dart` vs `ActiveSessionScreen` in workout-screens.jsx)

- **[DIFFERENT] Rest-timer banner has no animated spinner or progress fill.** Design (workout-screens.jsx L428-470): an **animated spinning ring** (`animation: 'spin 1s linear infinite'`) plus a **left-anchored progress fill** whose width is `((120 - restSeconds)/120)*100%` (rgba white 0.12). Flutter `_RestBanner` (active_session_screen.dart L333-428) uses a **static `clock.fill` glyph inside a non-spinning ring** (comment at L364-365 explicitly drops the spinner) and has **no progress-fill bar**.
- **[COPY] Rest time format.** Design prints `0:${padStart(2)}` → e.g. "0:47" (workout-screens.jsx L451). Flutter prints `$m:$s` where `m = restRemaining ~/ 60` with no left-pad, so 47s → "0:47" (matches), but ≥10 min would read e.g. "10:00" — acceptable; minor.
- **[MISSING] Header session-time is the elapsed clock (good), but design shows a fixed mock `28:14`.** Not a defect — Flutter computes real elapsed (L236-242). Noting design used a static value.
- **[DIFFERENT] Header eyebrow text.** Design: `● ${routine.name.toUpperCase()}` e.g. "● PUSH DAY A" (workout-screens.jsx L381). Flutter: `'● ${name.toUpperCase()}'` (active_session_screen.dart L182) — matches. README L440 prefixes "ACTIVE · " ("ACTIVE · PUSH DAY A") — **neither the JSX nor Flutter includes the "ACTIVE · " prefix**; both follow the JSX, so this is a README-only discrepancy, not a Flutter defect.
- **[MISSING] Current-exercise card omits the trailing ellipsis (…) button.** Design has a 32×32 `fill`-bg circular `ellipsis` button at the top-right of the hero card (workout-screens.jsx L503-509). Flutter's `_CurrentExerciseCard` header has no ellipsis button (active_session_screen.dart L464-514).
- **[COPY] "Now" eyebrow casing.** Design: `● Now · exercise ${exIdx+1}` (mixed case, workout-screens.jsx L492). Flutter: `'● NOW · EXERCISE ${...}'` (all caps, active_session_screen.dart L489). Design is "Now · exercise N"; Flutter is "NOW · EXERCISE N".
- **[DIFFERENT] PR chip wording uses real PR; design appends "Beat it today?".** Both show `Your PR: {w}kg × {reps}` + "Beat it today?" — matches (workout-screens.jsx L513-533 vs active_session_screen.dart L537-573). OK.
- **[DIFFERENT] Active set card lacks the per-set "Target" inline + the value boxes are present.** Design active set (workout-screens.jsx L632-693): "SET N" pill + `Target: {weight}kg × {reps} reps` + "ACTIVE" tag, then Weight/Reps value boxes, then "Complete set". Flutter matches this layout (active_session_screen.dart L633-713). **However the weight/reps boxes are read-only display values in both** — neither is an actual input field (design uses static divs; Flutter uses `Text`), so no functional gap vs design.
- **[MISSING] Up-next card "chevron.right" present; design parity OK.** Matches (workout-screens.jsx L555-581 vs active_session_screen.dart L828-901).
- **[DIFFERENT] Header stat cells use a hardcoded translucent-black overlay.** Design cell bg `rgba(0,0,0,0.12)` (workout-screens.jsx L416). Flutter uses `Color(0x1F000000)` = ~12% black (active_session_screen.dart L289) — matches.
- **[DIFFERENT] Volume number formatting.** Design header Volume = `totalVolume.toLocaleString()` (thousands separator, workout-screens.jsx L413). Flutter passes `_trimDouble(volume)` with **no thousands separator** (active_session_screen.dart L229, L961-962). E.g. design "1,250" vs Flutter "1250".
- **[DIFFERENT] "Complete"/finish path.** Design Finish just calls `onFinish` (no confirm in the prototype). Flutter adds a confirm dialog: title **"Finish workout?"**, body **"This ends the session and shows your summary."**, actions "Keep going" / "Finish" (active_session_screen.dart L108-131). README L807 specifies different copy: body *"You'll save {N} sets and {volume}kg of volume."* and action *"Finish & save"*. **[COPY] Flutter's confirm body and button ("Finish") do not match the README spec ("Finish & save", with the sets/volume summary).**
- **[MISSING] `_CompleteCard` state is Flutter-only.** When all sets are logged Flutter shows an "All sets logged" / "Tap Finish to see your summary." card (active_session_screen.dart L904-932). No design equivalent — additive, low concern.
- **[STYLE] Done-set row omits the trailing per-set volume "{vol} kg".** Design done `SetCard` shows a right-aligned `{volume} kg` value (workout-screens.jsx L623-626). Flutter done row shows weight×reps and an optional PR star but **no trailing volume figure** (active_session_screen.dart L597-631).
- **[DIFFERENT] Done-set PR star.** Flutter adds a `star.fill` before the weight×reps when `set.isPR` (active_session_screen.dart L620-623). Design's active-session done card has **no PR star** (PR surfacing happens via the top PR chip only). Minor additive difference.

---

## 10 · Post-Workout Summary (`post_workout_screen.dart` vs `PostWorkoutScreen` in workout-screens.jsx)

- **[DIFFERENT] Hero is structurally different.** Design hero (workout-screens.jsx L734-802): gradient **`move → accent`**, decorative blobs + diagonal stripes, a "COMPLETE" pill, headline **"Nice session."** (SF 34/700), a sub-line **`★ You hit a new PR on bench · {routineName}`**, and a **4-column** stat grid: Time(min) / Volume(tonnes) / Sets(`{reps} reps`) / PRs(records). Flutter hero (post_workout_screen.dart L82-168): gradient **`move → move@0.88`** (not move→accent), a close `xmark`, a centered checkmark circle, headline **"Workout complete"** (SF 26), the workout name, and a **3-column** stat row: Time / Volume(t) / PRs. **Missing: accent gradient, "Nice session." headline, PR sub-line, the Sets stat column (and its "{reps} reps" unit), decorative blobs/stripes.**
- **[COPY] Headline.** Design **"Nice session."**; Flutter **"Workout complete"** (post_workout_screen.dart L136).
- **[COPY] Eyebrow/pill.** Design "COMPLETE" pill; Flutter has no eyebrow pill (replaced by a checkmark circle).
- **[STYLE] Volume unit label.** Design "tonnes"; Flutter "t" (post_workout_screen.dart L159).
- **[MISSING] Dedicated PR highlight card.** Design renders a full **"PERSONAL RECORD"** card after the hero (workout-screens.jsx L804-834): money-gradient star tile + "Personal record" eyebrow + **"Bench Press · 90kg × 5"** + **"+5kg from previous best · Oct 14"**. **Flutter has no PR highlight card at all.**
- **[DIFFERENT] "Muscles worked" rendering.** Design (workout-screens.jsx L836-872): **per-muscle rows**, each with name, a right-aligned volume (e.g. "1,910 kg"), a **percentage** (e.g. "45%"), and an **individual horizontal progress bar** per muscle. Flutter (post_workout_screen.dart L222-289): a **single proportional stacked bar** + a `Wrap` of **pills** (dot + name + "{kg}kg"). **No per-muscle percentages and no per-muscle bars.**
- **[DIFFERENT] Exercise recap loses the per-set bar chart.** Design (workout-screens.jsx L874-944): each exercise shows name + optional PR star + total volume, then a **mini bar chart of set volumes** (bars scaled to max, PR set in money color with a dot marker, "{weight}×{reps}" under each bar). Flutter (post_workout_screen.dart L336-448): name + a `Wrap` of **set chips** ("{kg} kg × {reps}", PR chips money-tinted). **Missing: the per-set volume bar chart / progression visualization; total-volume figure per exercise is also dropped.**
- **[MISSING] Pal's note card is Flutter-only here.** Flutter adds a `_PalNote` card (post_workout_screen.dart L452-500). Design's PostWorkout screen has **no** Pal note (that lives on Workout Detail, screen 12). Additive.
- **[DIFFERENT] Action bar.** Design (workout-screens.jsx L946-963): **Share** (outline, flex 1, `square.and.arrow.up` + "Share") + **"Save to timeline"** (filled move, flex 2). Flutter (post_workout_screen.dart L504-559): a **52px icon-only Share button** (no "Share" label) + "Save to timeline" (with a saving spinner state). **Share label text is missing; button is icon-only.**
- **[LAYOUT] Section header padding/casing.** Design headers "Muscles worked" / "Exercises · N" are eyebrow-styled (uppercase via CSS). Flutter `_SectionHeader` uppercases (post_workout_screen.dart L585-597) — OK.

---

## 11 · Exercise Library (`exercise_library_screen.dart` vs `ExerciseLibraryScreen` in workout-screens2.jsx)

- **[LAYOUT] Header is a plain row, not a NavBar.** Design uses `NavBar` with title **"Exercises"**, subtitle **"{N} in library"**, a **leading back button labeled "Move"** (with chevron), and a **trailing `+` NavIconButton** (workout-screens2.jsx L166-179). Flutter renders a custom `_Header` row: chevron-only back (no "Move" label) + title **"Exercise Library"** + **no subtitle and no trailing `+`** (exercise_library_screen.dart L137-164).
- **[COPY] Title differs.** Design **"Exercises"** (+ "{N} in library" subtitle); Flutter **"Exercise Library"** (exercise_library_screen.dart L154).
- **[MISSING] "{N} in library" count subtitle absent** in Flutter.
- **[MISSING] Trailing "+" add button absent** in Flutter (design L178).
- **[COPY] Back-button label.** Design back button reads "Move" (workout-screens2.jsx L176). Per the rename handoff this should now read "Workout". Flutter shows **no label at all** (chevron only) — so both the label and (per rename) the word are missing.
- **[DIFFERENT] Grouping key.** Design groups by **`e.group`** (Push/Pull/Legs/Core/Cardio) and section headers are the group names, derived from the active filter (workout-screens2.jsx L160-211). Flutter groups by **`e.muscle`** (Chest/Shoulders/Back/…) (exercise_library_screen.dart L57-63, L113-124). README L475 says "Grouped sections (per muscle group)" which is ambiguous, but the JSX source-of-truth groups by `group`, so **section headers differ** (e.g. "Push" vs "Chest"/"Shoulders").
- **[STYLE] Group-tinted icon backgrounds lost.** Design tints each row's icon tile by group: Cardio = solid `move`; Push = `move22`; Pull = `rituals22`; Legs = `money22`; else `accent22`, with matching icon color (workout-screens2.jsx L218-225). Flutter uses a **uniform `c.move` icon background** for every row (exercise_library_screen.dart L319, via `ListRow iconBg: c.move`).
- **[DIFFERENT] PR display.** Design shows the PR value (`{weight}kg` or `{reps} reps`) **with a small "PR" eyebrow under it** (money color), plus a chevron (workout-screens2.jsx L234-248). Flutter shows the PR value as the `ListRow` trailing `value` (ink2) with **no "PR" eyebrow and no chevron** (exercise_library_screen.dart L300-324).
- **[STYLE] Filter chip active color.** Design active chip = `theme.ink` bg, `theme.bg` text (workout-screens2.jsx L200-201). Flutter active chip = `c.ink` bg, `c.bg` text (exercise_library_screen.dart L269-278) — matches. Inactive: design `theme.surface` + hairline; Flutter `c.fill` (no hairline) — minor token difference.

---

## 12 · Workout Detail (`workout_detail_screen.dart` vs `WorkoutDetailScreen` in workout-screens2.jsx)

- **[DIFFERENT] Summary grid layout.** Design = **4 tiles in a 2×2 grid**, each with a decorative offset circle behind the icon, tinted icon chip, label, big value + unit (workout-screens2.jsx L277-321). Stats: Duration(move,`clock.fill`)/Volume(accent,`chart.bar.fill`)/Sets(rituals,`list.number`)/Personal records(money,`star.fill`). Flutter = 2×2 grid of `_SummaryTile` (workout_detail_screen.dart L88-142): Duration(move)/Volume(accent)/Sets(rituals)/PRs(money). Differences: **no decorative offset circle**; Sets icon is `chart.bar.fill` not **`list.number`** (L121); PRs label "PRs" not **"Personal records"** (L132); PR unit "new best" matches.
- **[STYLE] Summary value type size.** Design big value SF Rounded 26 (workout-screens2.jsx L310). README L484 says "SF Rounded 20/700". Flutter uses size 26 (workout_detail_screen.dart L257) — follows JSX.
- **[DIFFERENT] Volume chart.** Design = 8 hardcoded bars `[30,42,38,45,52,48,58,68]`, last bar highlighted with a **"4.3t" value label above it** and a **"+15% in 4 wks" trend pill** next to the "34.2t total" headline (workout-screens2.jsx L323-376). Flutter = `fl_chart` `BarChart` driven by `state.weeklyVolume`, last bar highlighted, **no per-bar value label and no "+X% in N wks" trend pill** (workout_detail_screen.dart L276-370). **Missing: trend pill, highlighted-bar value label.**
- **[DIFFERENT] Exercise set table header.** Design header row = `SET / KG / REPS / (PR col)` (workout-screens2.jsx L398-406). Flutter matches (`SET/KG/REPS/_`) (workout_detail_screen.dart L427-453). OK.
- **[DIFFERENT] Per-exercise volume label.** Design shows `{sets.length} × {vol}kg` (workout-screens2.jsx L392-395). Flutter shows `{sets.length} × {vol}kg` (workout_detail_screen.dart L405). OK.
- **[COPY] PR badge.** Design "PR" pill (money bg, white) (workout-screens2.jsx L426-431). Flutter `_PrTag` = star + "PR" (money bg, white) (workout_detail_screen.dart L501-529) — Flutter **adds a star icon** the design badge doesn't have. Minor.
- **[DIFFERENT] Pal's note copy is dynamic vs static.** Design hardcodes the note: *"New PR on bench at 90kg × 5 — that's 5kg up from last month. Next push day, try 92.5kg top set."* (workout-screens2.jsx L452-454). Flutter fetches via `workoutNoteProvider` with loading/error fallbacks (workout_detail_screen.dart L532-580). Functionally richer; content will differ.
- **[COPY] Back-button label.** Design back reads "Today" (workout-screens2.jsx L271). Flutter shows chevron-only (no label) via `LargeTitleNavBar` leading (workout_detail_screen.dart L80-84).

---

## Routine Editor (`routine_editor_screen.dart` vs `RoutineEditorScreen` in workout-screens2.jsx)

- **[COPY] Title.** Design **"Edit routine"** (workout-screens2.jsx L14). Flutter **"Edit workout"** / **"New workout"** (routine_editor_screen.dart L84). (Rename handoff would justify "Workout", but design says "routine".)
- **[DIFFERENT] Cancel affordance.** Design leading = chevron + **"Cancel"** text (workout-screens2.jsx L15-25). Flutter leading = chevron-only, no "Cancel" label (routine_editor_screen.dart L86-90).
- **[DIFFERENT] Save button styling.** Design Save = plain accent **text** button (no fill) (workout-screens2.jsx L27-32). Flutter Save = **accent-filled pill** (routine_editor_screen.dart L149-178).
- **[DIFFERENT] Name + Tag use a different control set.** Design: a read-only Name row showing `routine.name` and a **Tag chip row** `[Upper, Lower, Full, Cardio, Custom]` (workout-screens2.jsx L36-62). Flutter: an **editable `TextField` name** + a **`Segmented` tag control** (routine_editor_screen.dart L97-104, L248-276). Functionally improved (editable), structurally different.
- **[MISSING] Per-exercise set chips + drag-handle + "+ set" chip.** Design exercise rows (workout-screens2.jsx L66-111): a `≡` **drag handle glyph**, icon tile, name, `{muscle} · {N} sets` meta, a chevron, then a row of **set chips** (`{weight}×{reps}` or "{reps} reps") plus a dashed **"+ set"** chip. Flutter `_ExerciseTile` (routine_editor_screen.dart L461-553): icon tile, name, a single `{sets}×{reps} · {kg}` target string, an `xmark` delete, and a `slider.horizontal.3` edit glyph. **Missing: visible drag handle, per-set chips, the "+ set" affordance, the `{muscle}` in the subtitle, and the chevron.** (Reorder is implemented via `ReorderableListView` long-press, but there's no visible `≡` handle.)
- **[DIFFERENT] Section footer hint absent.** Design Exercises section has footer **"Drag ≡ to reorder · swipe left to remove · tap a set to edit targets"** (workout-screens2.jsx L67). Flutter has **no footer hint** (routine_editor_screen.dart L431).
- **[MISSING] "Generate routine with AI" gradient button absent.** Design places a prominent **move→accent gradient "Generate routine with AI"** button below the exercise list, plus an outline "Add exercise from library" (workout-screens2.jsx L114-134). Flutter has only the inset **"Add exercise"** ListRow (routine_editor_screen.dart L556-577) — **no in-editor AI-generate CTA**.
- **[COPY] "Add exercise" subtitle.** Design has no subtitle on that action (it's a button "Add exercise from library"). Flutter ListRow subtitle = "Pick from the library" (routine_editor_screen.dart L569). Minor.
- **[DIFFERENT] Session-settings section differs.** Design "Session settings" inset (workout-screens2.jsx L137-141): **"Rest timer default" = "2:00"**, **"Warm-up reminder" = "Off"** (`bell.fill`, #FF9500), **"Auto-progress weights" = "On"** (`arrow.triangle.2.circlepath`, move) — all **value rows**. Flutter splits this: a **"Rest between sets" `Segmented` control** with presets `[60,90,120,180]s` (routine_editor_screen.dart L278-306), and a **"Warmup reminder"/"Auto-progress" toggle section** with `Switch.adaptive` (L308-343). Differences: rest is a segmented picker (60/90/120/180s) not a "2:00" value row; warmup icon `flame.fill` (money) not `bell.fill` (#FF9500); auto-progress titled "Auto-progress" not "Auto-progress weights", icon `chart.bar.fill` not `arrow.triangle.2.circlepath`.
- **[MISSING] "Delete routine" button absent.** Design ends with a red **"Delete routine"** text button (workout-screens2.jsx L143-150). Flutter has **no delete action**.
- **[MISSING] Exercise targets editing UI is a Flutter-only sheet.** Flutter adds `_TargetsSheet` (sets/reps/weight steppers) + `_ExercisePickerSheet` (searchable catalog) (routine_editor_screen.dart L594-883). Design edits targets inline via the set chips. Functionally improved; structurally different.

---

## Routine Generator (`routine_generator_screen.dart` vs `RoutineGeneratorScreen` in routine-generator.jsx)

- **[COPY] Hero eyebrow.** Design **"Pal builds your routine"** (routine-generator.jsx L122). Flutter **"PAL BUILDS YOUR WORKOUT"** (routine_generator_screen.dart L197). "routine" → "workout".
- **[COPY] Hero example sub-line.** Design: *"A 30-min pull day I can do at the gym" or "legs at home with dumbbells."* (two examples, routine-generator.jsx L130). Flutter: *"A 30-min pull day I can do at the gym."* (single example, routine_generator_screen.dart L214). Second example dropped.
- **[COPY] Loading pill text.** Design **"Pal is building your routine…"** (routine-generator.jsx L230). Flutter **"Pal is building your workout…"** (routine_generator_screen.dart L497). "routine"→"workout".
- **[COPY] Save button.** Design **"Save routine"** (routine-generator.jsx L354). Flutter **"Save workout"** (routine_generator_screen.dart L828). "routine"→"workout".
- **[STYLE] Hero radial-tint alpha.** Design top tint `${theme.move}44` (~0.27), bottom `${theme.accent}33` (~0.2) (routine-generator.jsx L106-110). Flutter: move alpha 0.27, accent alpha 0.2 (routine_generator_screen.dart L174-179) — matches.
- **[DIFFERENT] Exercise-row subtitle uses group, not muscle.** Design result rows show `{muscle} · {equipment}` (routine-generator.jsx L313-315). Flutter shows `{group} · {equipment}` (routine_generator_screen.dart L667-675, prefers `exercise.group`). Muscle vs group mismatch.
- **[DIFFERENT] Result actions match well.** "Try again" (flex 1, `arrow.clockwise`) + "Save …" (move, flex 2) — parity (routine-generator.jsx L336-356 vs routine_generator_screen.dart L777-840). Only the save label copy differs (above).
- **[DIFFERENT] Quick-pick goals match (labels, icons, colors).** All six goals + icons + colors are 1:1 (routine-generator.jsx L11-18 vs routine_generator_screen.dart L50-57). OK. Note quick-pick label "Pull day focused on back" matches (design L14).
- **[COPY] Quick-pick header.** Design "Or try one of these" (routine-generator.jsx L185). Flutter "OR TRY ONE OF THESE" (uppercased, routine_generator_screen.dart L382) — visual match.
- **[DIFFERENT] Generated badge + result header.** Design "GENERATED" badge + name + tag pill + "{N} exercises · ~{estMin} min" + rationale, on a `move→accent` gradient (routine-generator.jsx L249-292). Flutter matches structurally (routine_generator_screen.dart L531-632). OK.

---

## 24 · Weekly Plan (`weekly_plan_screen.dart` vs `WeeklyPlanScreen` in more-screens.jsx)

- **[MISSING] Today-spotlight "Swap" CTA absent.** Design spotlight has **two** buttons: "Start workout" (colored, flex 1) **and a "Swap" outline button** (more-screens.jsx L373-389; README L326 lists both "Start workout" + "Swap"). Flutter renders **only** "Start workout" (full width) (weekly_plan_screen.dart L344-374). **"Swap" CTA missing.**
- **[COPY] Back-button label.** Design back reads "Move" (more-screens.jsx area). Flutter reads **"Workout"** (weekly_plan_screen.dart L66) — Flutter already applied the rename here (inconsistent with start_workout / router which still say "Move"/"/move").
- **[DIFFERENT] Title-block subtitle wording.** Design: "{done} of {total} done · {min} min planned" (README L324; more-screens.jsx). Flutter: `'{doneCount} of {totalCount} done · {totalMinutes} min planned'` (weekly_plan_screen.dart L103) — matches.
- **[DIFFERENT] `totalMinutes` counts rest days as 0 (OK), but design sums `est || 0` across all days incl. the planned ones.** Design `totalMin = WEEK_PLAN.reduce((s,d)=>s+(d.est||0),0)` = 55+58+62+30+45 = **250** (more-screens.jsx L255). Flutter `totalMinutes` folds `est ?? 0` identically (weekly_plan_controller.dart L76-77) = **250**. Matches. (README L324 example "290 min" in the docstring comment at controller L88 is stale — actual data sums to 250.)
- **[STYLE] Week-strip "planned" chip ring.** Design planned (not-done, not-rest, not-today) = **dashed ring**; Flutter uses a **solid 1.5px ring** at `color@0.33` (weekly_plan_screen.dart L198-200). README L325 says "planned = dashed ring" — **Flutter ring is solid, not dashed.**
- **[DIFFERENT] Week-strip completion dot.** Design: a completion dot under each chip (filled when done). Flutter renders the dot (weekly_plan_screen.dart L233-244): done = filled, rest/planned handling. Parity OK.
- **[DIFFERENT] Pal coach note copy.** Design "Pal · Weekly coach" gradient note (more-screens.jsx L328). Flutter hardcodes: *"You're on a **2-week 5/7 streak**. Legs day usually slips — want me to shorten it to 45 min?"* (weekly_plan_screen.dart L587-594). Design's exact note text was not in the read range; Flutter's is a plausible match but should be verified against the JSX body. Label "PAL · WEEKLY COACH" matches.
- **[STYLE] Today spotlight uses `c.surface` bg + radial wash; design uses a tone-tinted card.** Flutter spotlight is `c.surface` with a faint radial gradient at top-left `color@0.12` and a `color@0.27` hairline border (weekly_plan_screen.dart L260-279). Design "tone-tinted card" (README L326) — close; the dominant tint may read lighter than design.

---

## Cross-cutting / data-model notes

- **[COPY] "Workout" rename partially applied.** Per `Handoff - Workout Rename & Budget Editor.md`, user-facing "Move"/"routine" copy should read "Workout". Flutter is **inconsistent**: Weekly Plan back button says "Workout" (good), but Start Workout nav subtitle still says "Pick a workout or freestyle" (design wanted "routine"), router/path is still `/move`, and several screens that the design labels "routine" now say "workout" (New workout, Save workout, Edit workout, "Pal builds your workout") — these go **beyond** the rename scope (which targeted "Move"→"Workout", not "routine"→"workout"). Net: the word "routine" has been broadly swapped to "workout" across editor/generator, which the design copy did not ask for.
- **[DIFFERENT] PR detection / `isPR` flag.** Design marks PR sets statically in `PAST_SESSIONS` (`pr: true` on a set, workout-data.jsx L106). Flutter uses a `set.isPR` flag surfaced in active session (done-row star), post-workout (chip), and detail (PR tag). The detection logic lives in controllers (not in scope here) — UI surfaces exist in all three screens, matching design intent.
- **[DIFFERENT] Cardio set data (distance/pace) is under-surfaced.** Design routines carry `{ duration, distance, pace }` for cardio (workout-data.jsx L85, L92) and the Start screen's `CardioRow` displays distance/pace. Flutter's cardio rows show only minutes (see §08). The active-session/detail screens are strength-oriented in both.
- **[STYLE] `move` gradient direction.** Several Flutter headers use a top→bottom `[move, move@0.93/0.88]` gradient (active L162-166, post-workout L97-101), whereas design uses a diagonal `175deg`/`160deg move→accent` gradient with stripe/blob decorations. Flutter consistently drops the decorative stripe/blob layers and the accent endpoint.
