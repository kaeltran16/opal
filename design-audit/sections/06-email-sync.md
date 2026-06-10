# Email Sync

Feature: auto-import receipts + subscriptions from Gmail/Outlook over IMAP. Three states in the design: Intro/Empty (`EmailSyncEmptyScreen`), App-password Setup (`EmailSyncConnectScreen`), Synced Dashboard (`EmailSyncedScreen`), plus the `GmailGlyph` SVG mark.

Source of truth: `C:\Users\cktra\Downloads\expensepal (4)\src\email-sync.jsx` (JSX prototype). Where the reference spec `design_handoff_expensepal\README.md` (screens 20/21/22) adds elements the JSX never built, those are flagged as spec-vs-prototype divergences but still audited because the task names them explicitly (provider toggles, subscriptions tab, filters).

Flutter files: `lib\screens\email\email_intro_screen.dart`, `email_setup_screen.dart`, `email_dashboard_screen.dart`, `email_nav.dart`.

---

## Cross-cutting

- **[STYLE]** GmailGlyph missing entirely in Flutter. Design ships a 5-color Gmail SVG mark (`GmailGlyph`, lines 546–556) used on the Intro CTA (size 18), the Setup how-to header (18), and the Dashboard hero (32). Flutter has no equivalent — the CTA button shows text only, and the dashboard hero uses a generic `envelope.fill` accent tile (`email_dashboard_screen.dart:105`). The brand glyph is absent in all three places.
- **[SUBTAB]** No provider segmented control / toggle anywhere. The README spec (screen 20, line 517) calls for an inset **"Gmail (Recommended) / Outlook / Other (IMAP)"** provider list. The JSX prototype does NOT implement this (it hardcodes Gmail and shows a static "iCloud, Outlook, any IMAP coming" caption). Flutter matches the JSX (caption only, `email_intro_screen.dart:161`), so relative to the prototype this is faithful — but relative to the written spec the provider picker is **[MISSING]**. No Gmail/Outlook toggle exists.
- **[SUBTAB]** No receipts-vs-subscriptions tab / segmented control anywhere in the Dashboard. The feature is described as "receipts + subscriptions" and the Dashboard `detections` array tags one row as `recurring` (Netflix, line 286), but neither design nor Flutter splits them into tabs. The JSX surfaces subscriptions only via the "Pal noticed" card ("7 recurring subscriptions… Review subscriptions"). Flutter drops that card entirely (see Dashboard below), so the only subscription affordance in the prototype is **[MISSING]** in Flutter.
- **[SUBTAB]** No category filter chips. README screen 22 (line 545) lists a **"Filters" button**; the JSX prototype did not build it. Flutter also omits it. Filter chips for synced-item categories do not exist in the prototype or the app.

---

## Intro / Empty state (`EmailSyncEmptyScreen` → `EmailIntroScreen`)

- **[COPY]** Nav leading label differs. Design: **"You"** with chevron (line 17), back to the You/profile tab. Flutter: **"Settings"** (`email_intro_screen.dart:50`). Mismatched destination label.
- **[LAYOUT/STYLE]** Headline line break dropped. Design renders two lines via `<br/>`: **"Stop logging card"** / **"charges by hand."** (line 43) with `textWrap: 'balance'`. Flutter passes a single string "Stop logging card charges by hand." (`:62`) — same words, no forced break, no balance wrap.
- **[STYLE]** Glyph gradient opacity mismatch. Design background gradient is `linear-gradient(135deg, ${accent}18, ${money}22)` = accent @ ~9%, money @ ~13% (line 24). Flutter uses `c.accentTint` and `c.moneyTint`, both 14% (`email_intro_screen.dart:191`). Slightly stronger tint than designed.
- **[STYLE]** Glyph badge shadow dropped. Design's sparkles badge has `boxShadow: 0 4px 12px ${money}55` (line 35) and the outer tile has a `0 0 0 0.5px hair` hairline (line 27). Flutter omits both the badge glow and the tile hairline.
- **[MISSING]** "How it works" middle step lost its accent color token. Design step 2 ("Pal reads only those") uses `color: theme.accent` (line 55). Flutter passes `''` as the token (`email_intro_screen.dart:29`) and resolves via `c.forType('')` — verify this yields accent; if `forType` falls back to a default, step 2's icon tile color is wrong.
- **[STYLE]** Step icon tile tint opacity differs. Design tile bg is `${color}22` = 13% (line 63). Flutter uses `withValues(alpha: 0.13)` (`:238`) — matches. (No issue; noted for completeness.)
- **[COPY]** Reassurance note copy trimmed. Design: "…Pal stores it encrypted in the **iOS keychain**. Revoke it anytime **from Gmail** without touching anything else." (line 91). Flutter: "…encrypted in the **keychain**. Revoke it anytime without touching anything else." (`:116-119`) — drops "iOS" and "from Gmail".
- **[MISSING]** Secondary CTA is a real button in design, plain text in Flutter. Design's "iCloud, Outlook, any IMAP coming" is a `<button>` (line 107). Flutter renders it as a non-interactive `Text` (`:160`). Functionally both are inert mocks, but the design models it as tappable.
- **[STYLE]** Primary CTA shadow dropped. Design CTA has `boxShadow: 0 4px 14px ${ink}33` (line 102). Flutter CTA has no shadow (`:139-144`).
- **[STYLE]** Primary CTA missing leading glyph + gap. Design CTA is `GmailGlyph(18)` + 10px gap + "Set up Gmail sync" (lines 104–106). Flutter shows the label only, centered, no glyph (`:146`).
- **[LAYOUT]** Bottom padding differs. Design `paddingBottom: 110` (line 7); Flutter `EdgeInsets.only(bottom: 48)` (`:46`). Likely intentional (no floating tab bar in this route) but noted.

---

## Setup / App-password (`EmailSyncConnectScreen` → `EmailSetupScreen`)

- **[COPY]** Seed email differs. Design prefills `mira@gmail.com` (line 119). Flutter prefills `alex@gmail.com` (`email_setup_screen.dart:33`). Cosmetic mock data.
- **[COPY]** App-password app label differs. Design step 3: `Create an app password labeled "ExpensePal"` (line 182). Flutter: `Create an app password labeled "Pal"` (`:284`). String mismatch.
- **[STYLE/COPY]** "Open Google app passwords" button icon differs. Design uses `square.and.arrow.up` (line 190). Flutter uses `arrow.up.right` (`:332`). Different SF symbol.
- **[STYLE]** How-to step 2 link styling dropped. Design renders `myaccount.google.com/apppasswords` underlined in accent color (`<u style={{color: accent}}>`, line 181). Flutter renders the URL as plain ink2 text inside the sentence (`:283`) — no accent, no underline, not visually a link.
- **[MISSING]** How-to header glyph dropped. Design header row is `GmailGlyph(18)` + "Generate a Gmail app password" (lines 170–173). Flutter shows the title text alone, no glyph (`:296`).
- **[DIFFERENT]** Test-connection success/idle background tint. Design success bg `${move}22` (13%) with border `${move}44` (line 200, 205); idle bg `theme.surface` (line 200). Flutter success bg `c.move.withValues(alpha:0.13)`, border 0.27 (`:373,399`) — matches. Idle/testing bg `c.surface` — matches. (No issue.)
- **[MISSING / DIFFERENT]** Error state added in Flutter, not in design. Design `runTest` only toggles testing→ok (lines 125–128); there is no error path. Flutter adds a `TestState.error` branch with `xmark` + "Connection failed — check the password" (`:375-380`). This is an addition beyond the prototype (the README spec line 532 does call for an Error state, so it aligns with the written spec).
- **[STYLE]** Test button leading icon: design idle uses `bolt.fill` accent (line 209) — Flutter matches (`:382`). Testing spinner color design `ink2` (line 207) — Flutter `c.ink2` (`:364`). Matches.
- **[COPY]** Advanced "Encryption" value matches ("SSL / TLS", line 247 vs `:217`). Host/Port defaults match (`imap.gmail.com` / `993`). No issue.
- **[BEHAVIOR]** Advanced section in design has NO chevron rotation state persisted beyond local; Flutter mirrors with `_advancedOpen` toggling `chevron.down`/`chevron.right` (`:182`). Matches.
- **[STYLE]** How-to card border. Design card uses `boxShadow: 0 0 0 0.5px hair` (line 167). Flutter uses `Border.all(color: c.hair, width: 0.5)` (`:291`). Equivalent rendering; acceptable.
- **[BEHAVIOR]** Save gating matches intent (disabled until test succeeds): design `disabled={!ok}` (line 141), Flutter `trailingEnabled: setup.canSave` (`:90`). Matches.

---

## Synced Dashboard (`EmailSyncedScreen` → `EmailDashboardScreen`)

### Nav bar
- **[LAYOUT]** Design uses the **small-title** `NavBar` (`large` defaults true but title is "Email sync" with a **subtitle "Gmail · connected"**, line 293). Flutter uses `LargeTitleNavBar` with title "Email sync" and **no subtitle** (`email_dashboard_screen.dart:64`). The "Gmail · connected" subtitle is **[MISSING]**.
- **[COPY]** Leading label "You" (design, line 302) vs "Settings" (Flutter, `:73`). Same mismatch as Intro.
- Trailing `ellipsis` icon button present in both. Matches.

### Sync-job hero
- **[STYLE]** Hero avatar. Design uses `GmailGlyph(32)` (line 314). Flutter uses a 32×32 accent-tinted tile with `envelope.fill` (`:97-107`). Brand glyph replaced by generic envelope.
- **[DIFFERENT]** Connection chip identity row. Design shows the **email address** `mira@gmail.com` next to the chip (line 319). Flutter shows the account address (`alex@gmail.com` fallback, `:57,116`). Address source differs but structure matches.
- **[DIFFERENT]** Status line copy / staging differs substantially. Design `lastMsg` cycles verbatim: "Last sync 4 min ago" (idle) → "Connecting to imap.gmail.com…" → "Scanning INBOX · 1,847 messages" → "Filtering by sender · 62 matches" → "Parsing 3 new receipts…" → "Pal categorized 3 · 1 duplicate skipped" → "Last sync just now · 3 new" (lines 261–278). Flutter uses generic short stages: "Scanning INBOX…", "Filtering by sender…", "Pal is categorizing…", "Up to date · just now", and an idle "Last sync N min ago" / "Never synced" (`:29-44`). The message-count details ("1,847 messages", "62 matches", "3 new", "1 duplicate skipped") and the "Connecting to imap.gmail.com…" / "Parsing N new receipts…" stages are **[MISSING]**.
- **[DIFFERENT]** Progress stages. Design step progresses 10→28→55→80→100% (lines 266–270). Flutter maps 0/0.28/0.55/0.80/1.0 by status (`:29-37`) — close but drops the 10% "connecting" stage and the explicit 100% "done" message.
- **[STYLE]** Completed-bar color flash. Design bar turns `theme.move` (green) when `syncState === 'done'` (line 346); Flutter sets color to `c.move` when `SyncStatus.upToDate` (`:144`). Matches.
- **[COPY]** Sync-now button icon differs. Design idle uses `arrow.triangle.2.circlepath` (line 367); Flutter idle uses `paperplane.fill` (`:331`). Design syncing has a Spinner + "Syncing…" (line 363); Flutter syncing uses `arrow.up.right` icon + "Syncing…" (`:328`) — **no spinner**, wrong icon. Done state: both `checkmark` + "Done". 
- Schedule chip "Every 15m" present in both; design icon `timer` (line 376) vs Flutter `clock.fill` (`:372`). **[STYLE]** icon mismatch.

### Stats tiles — MISSING
- **[MISSING]** The 3-up stats grid is absent in Flutter. Design renders a `surface` card with three tiles: **"This month" 147** (accent), **"All time" 2,143** (money), **"Recurring" 7** (rituals) (lines 384–406). Flutter's Dashboard has no stats row at all.

### Pal-noticed card — MISSING
- **[MISSING]** The "Pal noticed" subscription-insight card is absent in Flutter. Design renders an `accentTint` card (lines 409–429): eyebrow "PAL NOTICED", body "You have **7 recurring subscriptions** totaling $84/mo. Two of them you haven't opened in 30+ days — want me to flag cancel candidates?", and a **"Review subscriptions"** pill button. This is the only subscriptions affordance in the prototype and it is entirely **[MISSING]** — removing the feature's subscription half from the dashboard.

### Recently-synced list
- **[DIFFERENT]** Per-row category icon + color are hardcoded in Flutter. Design assigns each detection its own `catIcon`/`catColor` (e.g. Blue Bottle → `cup.and.saucer.fill` move-green; Uber → `figure.walk` accent; Netflix → `star.fill` rituals-purple; Whole Foods → `basket.fill` money-orange; lines 283–288). Flutter hardcodes **every** row to `basket.fill` with `c.money` tint (`email_dashboard_screen.dart:446`). All category icons/colors are wrong except groceries.
- **[MISSING]** Recurring indicator dropped. Design shows an `arrow.triangle.2.circlepath` glyph next to recurring merchants (Netflix, lines 453–455). Flutter renders no recurring marker on import rows.
- **[MISSING]** Row meta line is reduced. Design subtitle is `category · [tray.fill] source · time` (e.g. "Food & Drink · Chase · 2h ago", lines 463–473). Flutter shows only `item.category ?? 'Uncategorized'` (`:488`) — **no source (card) and no relative time**.
- **[STYLE]** Amount color. Design amount is `theme.ink` SF-Rounded (line 476). Flutter uses `c.ink` SF-Rounded (`:494-499`). Matches the JSX. (README line 543 says amount should be "money orange" — divergence is spec-vs-prototype; Flutter follows the JSX.)
- **[BEHAVIOR]** NEW badge fade. Design fades the accent-tint row highlight over 400ms and tags fresh rows with a "NEW" pill while `syncState === 'done'` (lines 438, 456–461). Flutter implements a 6s timer that fades both the row tint and the badge (`:398-484`) — aligns with README "fades after 6s" (line 543/765); reasonable, but the design JSX ties the tint to `syncState==='done'` rather than a 6s timer.
- **[MISSING]** Empty-list state is a Flutter addition. Design always renders the 6-item `detections` list. Flutter adds a "No imports yet — tap Sync now." placeholder when `imports` is empty (`:181-196`). Addition beyond prototype (acceptable for a real data-backed screen).

### Sync settings — MISSING
- **[MISSING]** The entire "Sync settings" section is absent in Flutter. Design renders a `Section` with four `ListRow`s (lines 484–493): **"Background sync" → "Every 15 min"**, **"Notify on new detection" → "Off"**, **"Pal auto-categorize" → "On"**, **"Detected senders" → "47"**. None exist in Flutter.

### Disconnect
- **[COPY]** Present and matching: "Disconnect Gmail" in red (design line 501, Flutter `:212`). Behavior differs — Flutter actually disconnects via controller and pops (`:203-207`); design is a static mock. Acceptable.

---

## Summary of structural gaps (Dashboard)

Flutter's dashboard is missing three whole design sections — **Stats tiles**, **Pal-noticed subscriptions card**, and **Sync settings list** — plus the nav subtitle, per-row category coloring, recurring markers, and the source/time meta. These are the highest-impact differences. Combined with the absent provider toggle and the absent receipts/subscriptions split, the "subscriptions" half of "receipts + subscriptions" has effectively no UI surface in the current Flutter build.
