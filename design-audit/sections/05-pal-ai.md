# Pal & AI Surfaces

Audit of the Pal AI companion + reflective AI surfaces against the ExpensePal design handoff.
Design is the source of truth. Files read:

- Design: `pal-composer.jsx`, `ai-screens.jsx`, `new-screens.jsx` (Weekly Review / Streak / Evening Close-Out), `more-screens.jsx` (Pal Inbox), `README.md` (spec lines 277-338, 491-497, 795-809).
- Flutter: `pal_composer_screen.dart`, `ask_pal_screen.dart`, `pal_inbox_screen.dart`, `evening_close_out_screen.dart`, `streak_celebration_screen.dart`, `weekly_review_screen.dart`, `monthly_review_screen.dart`.

Severity tags: [MISSING] absent in Flutter · [DIFFERENT] behavior/structure differs · [COPY] text differs · [LAYOUT] ordering/spacing · [STYLE] color/typography/token · [SUBTAB] segmented-control / filter-chip / tab status.

---

## Subtab / Chip / Segmented-Control Inventory (focus area)

| Surface | Control | Design | Flutter | Status |
|---|---|---|---|---|
| Pal Composer | Starter "Try saying" chips (3) | present | present | OK (1 copy nuance, below) |
| Pal Composer | Compose mode toggle | none in design | none | N/A — single input surface by design |
| Ask Pal | Empty-state suggestion chips (3) | present | present | OK (1 copy diff) |
| Pal Inbox | Filter chips: All / Unread / Money / Workout / Rituals | 5 pills | 5 pills | OK — present & wired |
| Weekly Review | Period segmented control | none in design | none | N/A — fixed week |
| Monthly Review | Period segmented control | none in design | none | N/A — fixed month |
| Evening Close-Out | n/a (checklist, no chips) | — | — | N/A |
| Streak | 3 stat pills | present | present | OK |

Net: **no subtab/chip/segmented-control is missing.** All five inbox filter pills exist and are wired (`InboxFilter.all/unread/money/move/rituals`). Differences within these controls are copy/wiring nuances noted per-screen below.

---

## Pal Composer (`PalComposerSheet`)

- [DIFFERENT] **Send button icon mismatch.** Design uses `arrow.up` in the composer send button (`pal-composer.jsx` L268). Flutter also uses `arrow.up` (L664) — OK. (Note: the *standalone* Ask Pal screen differs; see that section.)
- [STYLE] **Send button color tracks `hasText` vs `input.trim()`.** Design colors the send button accent when `input.trim()` is truthy and disables only on empty/loading (L261-266). Flutter colors it accent on `hasText` but `onTap` is gated on `canSend = enabled && hasText` (L605/654). Equivalent behavior; minor: design keeps button accent even while loading if text present, Flutter keeps accent but disables tap — acceptable.
- [DIFFERENT] **Keyboard-lift mechanism.** Design measures `visualViewport` and translates the sheet up by a computed device-space lift (L44-71). Flutter uses `margin: EdgeInsets.only(bottom: keyboard)` from `viewInsets` (L103). Functionally equivalent on-device; not a visual defect.
- [STYLE] **Status dot color.** Design status-line dot is `theme.move` (green, L152). Flutter uses `c.move` (L189). OK.
- [COPY] **"Try saying" starter chip 3 label.** Design: `"How's my week so far?"` with a curly apostrophe `’` (L101). Flutter: `"How's my week so far?"` (L255) — verify the apostrophe glyph; Flutter source uses a straight `'`. Minor typographic difference.
- [STYLE] **"TRY SAYING" eyebrow.** Design renders label `Try saying` via CSS `textTransform: uppercase` (L213, content is lowercase "Try saying"). Flutter hard-codes the string `'TRY SAYING'` (L328). Same rendered result.
- [LAYOUT] **Starter-chip trailing icon.** Both use `arrow.up.right` (design L226 / Flutter L395). OK.
- OK: grabber (36×5, hair), gradient avatar (32, accent→rituals, sparkles), "Pal" title 15/600, status "Log, ask, or start anything", close `xmark` 30×30 fill circle, "Start a workout" moveTint card with `play.fill` + chevron, expanded 86% / max 92% sheet heights, bubbles (user accent/white radius 18 tail 5, assistant fill + 24px gradient avatar), typing dots — all match.
- OK: placeholders `'Log a coffee, ask about your week…'` (compact) / `'Reply or log something…'` (expanded) match design L248 verbatim.

## Ask Pal Screen (`AskPalScreen`)

> NOTE: The design intent (`pal-composer.jsx` header comment L2) is that the composer **replaces the standalone Ask Pal screen**. The Flutter app still ships and **routes** `AskPalScreen` at `/pal` (`router.dart` L80/315-319). So this screen is a design-superseded surface that nonetheless exists. Differences below are vs the original `AskPalScreen` in `ai-screens.jsx`.

- [COPY] **Subtitle differs.** Design: `"Your tracking companion"` (`ai-screens.jsx` L58). Flutter: `"Your money, workout & routines coach"` (L155).
- [COPY] **Empty-state greeting differs.** Design seeds the chat with a first assistant bubble: `"Hi Mira. I'm Pal — ask me anything about your money, workouts, or rituals. Or just tell me what you did and I'll log it."` (L6). Flutter shows a centered empty state with heading `"Hi there"` + body `"I'm Pal — ask me anything about your money, workouts, or routines. Or just tell me what you did and I'll log it."` (L334-349). Design says "rituals"; Flutter says "routines". Also Flutter drops the name ("Hi Mira" → "Hi there").
- [COPY] **Suggestion chip 3 differs.** Design: `"Suggest an evening ritual"` (L52). Flutter: `"Suggest an evening routine"` (L35). ("ritual" → "routine".)
- [DIFFERENT] **Empty-state layout.** Design renders suggestion chips inline under the seeded bubble with a `"Try asking"` uppercase label (L70-91). Flutter renders a centered card with a 56×56 accent-tint sparkles tile, `"Hi there"` headline, body, then chips — **no "Try asking" label** (L322-355). [MISSING] the "Try asking" label.
- [STYLE] **Send button icon.** Design send button uses `arrow.right` (L127). Flutter uses `arrow.up.right` (L498). [DIFFERENT].
- [STYLE] **Composer placeholder.** Design: `"Ask about your day or log something…"` (L108). Flutter: `"Message Pal"` (L475). [COPY].
- [STYLE] **Assistant bubble border.** Design assistant bubble = `theme.surface` background, no border (L155). Flutter adds `Border.all(c.hair, 0.5)` to assistant bubbles (L204). [STYLE].
- [STYLE] **Bubble font size.** Design bubbles 15px / letterSpacing -0.24 (L157). Flutter 16px / -0.31 (L208-212). [STYLE].
- [DIFFERENT] **Nav style.** Design uses the shared `NavBar` with a trailing `ellipsis` icon button (L58-60). Flutter uses a custom large-title header (back chevron + "Ask Pal" 34/700 + subtitle) and **no trailing ellipsis** (L114-166). [MISSING] trailing ellipsis.

## Pal Inbox (`PalInboxScreen`)

- [SUBTAB] **Filter chips — all present & wired.** Design pills `All (n) / Unread (n) / Money• / Workout• / Rituals•` (`more-screens.jsx` L645-650). Flutter has the same five (`pal_inbox_screen.dart` L175-208): All+count, Unread+count, Money(dot), Workout(dot), Rituals(dot), all wired to `controller.setFilter`. Match. Note design's `move` filter label is "Workout"; Flutter label is also "Workout" → "Routines" for rituals (Flutter uses `'Routines'` L206 vs design `'Rituals'` L650). [COPY] "Rituals" → "Routines" on the rituals chip.
- [STYLE] **Filter chip vertical padding.** Design `padding: '7px 12px'` (L655). Flutter chip has only horizontal padding 12 inside a fixed `SizedBox(height: 36)` row (L170/283). Visually similar; vertical metric not pinned.
- [COPY] **Title + sub.** Design `"Pal noticed"` 28/700 + `"{n} new · a quiet inbox, not an anxious one"` / `"All caught up · a quiet inbox, not an anxious one"` (L630-637). Flutter matches verbatim (L132-162). OK.
- [STYLE] **Avatar shadow.** Design sparkle avatar shadow `0 4px 14px {accent}55` (≈33% alpha, L622). Flutter shadow alpha 0.33 / blur 14 / offset (0,4) (L121-123). OK.
- [DIFFERENT] **Note kinds.** Design `KIND_META` has 6 kinds: Nudge(accent) / Spotted(rituals) / Pattern(rituals) / Win(move) / Reminder(money) / Recap(accent) (L575-582). Flutter `NoteKind` enum matches all 6 verbatim (`enums.dart` L76-82). OK.
- [DIFFERENT] **Note data source.** Design ships 8 fixed `INBOX_ITEMS` (L516-573). Flutter sources notes from the repository/DB seed (controller streams `PalInboxState`), so exact note copy is data-driven, not hard-coded. Structure (icon tile + meta row "{KIND} · {when}" + title + body + optional action pill + unread accent dot) matches design L685-744.
- [STYLE] **Unread indicator position.** Design places the accent dot absolutely at `left:6, top:50%` (vertically centered, L692-696). Flutter places it inline at the row start with `top:16` padding (top-aligned near the icon, L347-356). [LAYOUT] dot is vertically centered in design, near-top in Flutter.
- [DIFFERENT] **Action pill behavior.** Design action pill calls `onOpenPal(it.title)` → seeds Pal composer with the note title (L736). Flutter marks the note read then `context.go('/pal-composer?seed=…title…')` (L414-419). Matches intent; Flutter additionally marks-read.
- [COPY] **Empty + footer.** Empty: `"Nothing here. A quiet Pal is a happy Pal."` (design L754 / Flutter L218) match. Footer: `"Tune what Pal notices"` with `gearshape.fill` (design L765 / Flutter L243) match.

## Evening Close-Out (`EveningCloseOutScreen`)

- [STYLE] **Gradient stops.** Design `linear-gradient(180deg, #1a1340 0%, #2d1f5c 45%, #3d2a73 100%)` (L484). Flutter uses the same 3 colors with stops `[0.0, 0.45, 1.0]` (L83-84). OK.
- [COPY] **Hero copy.** `"Close out\nyour day."` 32/700 + `"{done} of {total} rituals done. One more to close the ring."` (design L508-515). Flutter matches (L133-148). OK.
- [DIFFERENT] **Checklist data source & subtitle format.** Design has 5 fixed items (`pages/inbox/spanish/read/reflect`) with subtitles `"06:42 · 15 min"`, `"21:30 · 28 min"`, `"5 min · tonight"` etc. (L470-476). Flutter flattens **every routine step** from `ritualsControllerProvider` into rows, subtitle = `"{routine} · {step note or time}"` (L268-271). [DIFFERENT] — design lists 5 discrete day rituals; Flutter lists routine *steps*. Different content model.
- [DIFFERENT] **"Active" / "Now" pill selection.** Design hard-codes the last item (`reflect`, `moon.stars.fill`) as `active:true` and shows the "Now" pill only when it is the active unchecked one (L475, L536). Flutter computes the active row as the **first incomplete step** across all routines (L60-75). Different selection rule; both render a purple-tinted highlight + "Now" pill.
- [MISSING] **"Reflect on the day" ritual.** Design's 5th item is a `moon.stars.fill` "Reflect on the day" / "5 min · tonight" row that is the seeded incomplete step (L475). Flutter has no equivalent synthetic reflect step — rows are purely routine steps, so this specific item is absent.
- [COPY] **Nav clock.** Design centerpiece is the literal `"21:30 · Thursday"` (L500). Flutter renders a **live** `HH:mm · {weekday}` from `DateTime.now()` (L50-52). [DIFFERENT] — dynamic vs fixed (acceptable, but won't read "21:30 · Thursday" in the demo).
- [COPY] **Pal nudge + CTA.** `"Ask Pal for a reflection prompt"` dashed button (seeds `"Give me a reflection prompt for tonight"`) and CTA `"Good night"` / `"{n} to go"` all match (design L591-620 / Flutter L205/199/234). OK.
- [STYLE] **Progress bar & checkbox accent.** `#BF5AF2` purple accent, 6px bar, 24px circular checkbox filled purple + checkmark — match (design L526/547-553 / Flutter L167/304-321). OK.

## Streak Celebration (`StreakCelebrationScreen`)

- [STYLE] **Radial glow + rays.** Design `radial-gradient(ellipse at 50% 38%, {move}33 0%, {bg} 60%)` (L327) and 12 rays at 0.35 opacity, strokeWidth 2, origin (195,250), length 280 (L332-343). Flutter: RadialGradient center `(0.0,-0.24)` radius 0.9, `move@0.20` → bg, stops [0,0.6] (L44-49); 12 rays alpha 0.35 strokeWidth 2 length 280 origin (w/2,250) (L356-378). [STYLE] glow alpha differs: design `0x33`≈20% — Flutter uses 0.20 → match; gradient *shape/position* differs slightly (ellipse@38% vs radius-0.9 @ -0.24) — minor.
- [COPY] **Eyebrow / number / copy.** `"STREAK UNLOCKED"` (design renders `"Streak unlocked"` uppercased, L361) → Flutter `'STREAK UNLOCKED'` (L88). Giant streak number 140/800 move green + glow → match (design L364-369 / Flutter L96-112). `"days moving"` 28/700 → match.
- [DIFFERENT] **Streak value source.** Design hard-codes `11` everywhere (number, copy, card, 11 filled dots) (L369/379/419/431). Flutter reads `profileStatsProvider.longestStreak` (fallback 11) and derives filled dots = `streak.clamp(0,16)` (L37-40). Dynamic vs fixed — acceptable.
- [COPY] **2-line copy "since {date}".** Design: `"You haven't missed a day since Apr 12.\nYour longest streak this year."` (L379). Flutter: `"You haven't missed a day in $streak days.\nYour longest streak this year."` (L123). [COPY] — design phrases it as "since Apr 12" (a date); Flutter says "in 11 days" (a count). README spec L803 pins `"You haven't missed a day since {date}."` → Flutter deviates from the pinned "since {date}" form.
- [COPY] **Share card handle.** Design share card reads `"@mira · ExpensePal"` (L423). Flutter reads `"Opal"` only (L309) — no "@mira", and brand renamed ExpensePal→Opal. [COPY]/[DIFFERENT].
- [STYLE] **Share card label.** Design `"Workout streak"` uppercased (L415). Flutter `'MOVE STREAK'` (L294). [COPY] "Workout streak" → "Move streak".
- [STYLE] **Stat pills.** 3 pills Total/Best day/Next milestone with values `486 min` / `Sat · 75m` / `14 days` — match (design L385-388 / Flutter L28-32). OK.
- [STYLE] **Share card rotation, dot grid.** −1.5° rotation, 16-dot 4×4 grid (filled = streak) — match (design L408/426-433 / Flutter L150/324-352). OK.
- [STYLE] **CTAs.** Green `"Share"` w/ `square.and.arrow.up` + outline `"Keep going"` — match (design L444-458 / Flutter L175-209). OK.

## Weekly Review (`WeeklyReviewScreen`)

- [COPY] **Lede sentence differs.** Design lede: `"Movement stayed consistent, rituals held together, and you came in under budget. Let's look closer."` (`new-screens.jsx` L46). Flutter: `"Workouts stayed consistent, routines held together, and you came in under budget. Let's look closer."` (L108-109). [COPY] — "Movement"→"Workouts", "rituals"→"routines".
- [COPY] **Win row 1 title.** Design: `"11-day workout streak"` (L7). Flutter: `"11-day move streak"` (L26). [COPY].
- [COPY] **Pattern card 2.** Design: `"You worked out 73 min on ritual days vs 42 min on skipped-ritual days."` (L14). Flutter: `"…on routine days vs 42 min on skipped-routine days."` (L42-43). [COPY] "ritual"→"routine".
- [STYLE] **Patterns lost bold spans.** Design pattern text has inline `<b>` emphasis ("2.8× an average day", "73 min on ritual days", "28 min") (L13-15). Flutter renders flat text — bold spans dropped (documented at L33-34). [STYLE] — intentional per code comment but a visual deviation from design.
- [STYLE] **"One thing to try" card gradient/border.** Design `{accent}12 → {rituals}12` gradient, border `{accent}33` (L144-145). Flutter uses `accent@0.07 → rituals@0.07` and border `accent@0.20` (L367-376). [STYLE] — gradient tint ~7% vs design ~7%(0x12≈7%) OK; border 0.20 vs 0x33≈20% OK. Effectively matches.
- [COPY] **"One thing" body bold + seed.** Design body bolds "Thursday evening" (L167); Flutter flat (L408-410). Seed string `"Tell me more about my Friday spending"` matches (design L169 / Flutter L358). OK.
- OK: eyebrow `"WEEKLY REVIEW · APR 17–23"` (design "Weekly Review · Apr 17–23" uppercased), headline `"Your steadiest week this month."`, three-ring stat tiles (Spent $435/of $595, Workout 296/of 420 min, Rituals 26/of 35) with `{color}14`≈8% tint, Wins inset list (icon+title+sub+check), accent-bar pattern cards (3px bar), footer `"Next review · Sunday, Apr 30"`, share nav icon — all match.

## Monthly Review (`MonthlyReviewScreen`)

- [DIFFERENT] **Narrative & patterns are data-driven.** Design hard-codes the April narrative and 3 patterns ("Morning rituals lower food spending" / "Friday is your spendiest day" / "Movement and sleep are linked", `ai-screens.jsx` L506-510). Flutter pulls narrative from `monthlyReviewControllerProvider` and uses **different** canned patterns: "Mornings set the tone", "Workouts are your anchor", "Weekends drift" (L32-45). [COPY]/[DIFFERENT] — pattern titles and bodies entirely differ from the design prototype's three.
- [DIFFERENT] **Patterns layout.** Design "Patterns Pal found" rows are bare rows with a leading `sparkles` icon on a section card without per-row icon tiles (L506-522, flat sparkles icon, no gradient circle). Flutter wraps each in an inset card row with a **30px gradient sparkle circle** tile (L348-361). [STYLE] — design uses a small flat accent sparkle; Flutter uses a gradient avatar circle.
- [STYLE] **Narrative card background tint.** Design narrative gradient `{accent}18 → {rituals}18` (≈9.4% alpha, L443). Flutter uses `c.accentTint → c.ritualsTint` which are **14%** (light) / **18%** (dark) alpha tokens (`app_colors.dart` L103-107/129-133). [STYLE] — Flutter tint is noticeably stronger (14-18% vs design ~9%).
- [DIFFERENT] **Regenerate label states.** Design Regenerate pill swaps to `"Writing…"` while loading (L469). Flutter shows static `"Regenerate"` (loading state instead replaces the narrative text with `"Pal is reading your month…"`, L242/199). [COPY] — missing the `"Writing…"` pill label.
- [DIFFERENT] **Title source.** Design title hard-codes `"April"` (L436). Flutter renders the current month name from `DateTime.now()` (L51). Dynamic vs fixed — acceptable.
- [DIFFERENT] **Stat rows data-driven.** Design 4 fixed rows (Total spent $1,840 ↓12% / Workout time 38 hrs / Rituals kept 112/150 / Streak 11 days) with sub-captions and 36px icon tiles (L477-501). Flutter computes rows from `monthlyStatsProvider` with 32px icon tiles, big value + unit, and **no sub-caption line** (L256-309). [LAYOUT]/[MISSING] — design stat rows include a secondary sub-line ("↓ 12% vs March", "23 active days", "best month yet", "Workouts, ongoing"); Flutter rows have value+unit only, **sub-caption omitted**.
- [STYLE] **Stat row value typography.** Design value SF Rounded 22/700 right-aligned (L498). Flutter value 24/700 + separate unit label (L291-302). [STYLE] size 22 vs 24, plus unit split.
- [COPY] **"Written by Pal" + nav.** Label `"WRITTEN BY PAL"` (design "Written by Pal" uppercased L454 / Flutter L188) and `"Monthly review"` subtitle + `ellipsis`/back nav — design uses trailing `ellipsis` (L437); Flutter `LargeTitleNavBar` has back leading and **no trailing ellipsis**. [MISSING] trailing ellipsis on monthly review nav.

---

## Summary of cross-cutting issues

- **"ritual(s)" → "routine(s)" rename** appears repeatedly (Ask Pal greeting/suggestion, Weekly Review lede/win/pattern, Pal Inbox "Rituals" chip). This is a deliberate vocabulary shift but diverges from the handoff's pinned copy.
- **"ExpensePal" → "Opal" / dropped "@mira"** on the streak share card.
- **Monthly Review patterns** are completely different content from the prototype, and stat-row sub-captions are dropped.
- **Trailing `ellipsis` nav buttons** dropped on Ask Pal and Monthly Review.
