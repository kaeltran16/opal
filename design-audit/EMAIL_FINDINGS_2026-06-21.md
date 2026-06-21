# Opal — Email/Connection audit findings (2026-06-21)

Focused code-level audit of the email sync feature (intro, setup, dashboard,
connection state), tracing 06-20 finding #8 (connection state contradicts across
screens). Companion to `UX_FINDINGS_2026-06-20.md`. No code changed.

File references are grounded by reading the named lines.

---

## Severity legend
- **P1** — broken core action / user-visible wrong state.
- **P2** — conditional/stale state; not data-destructive.
- **P3** — polish / latent.

---

## Verified fixed since 06-20
- **#8 "Email state contradicts across screens":** the You-tab Integrations row
  now reads the **same** source as the dashboard —
  `emailDashboardControllerProvider.isConnected`
  (`profile_screen.dart:42–44`, with a comment explicitly preventing the "On vs
  not connected" split) and `email_dashboard_screen.dart:65, 76`. Both resolve to
  `account != null` (`email_sync_controller.dart:116`). The two-source split is
  gone.
- **Disconnected-CTA P3** ("Sync now" unusable when not connected): the
  disconnected hero now offers **Connect Gmail** instead
  (`email_dashboard_screen.dart:145–147, 233–234, 485`).

---

## P2 — conditional stale state

### 1. Connecting an account doesn't propagate to already-mounted watchers
- **Seen (by code):** the connect and disconnect paths are asymmetric:
  - **Disconnect** updates the dashboard state directly —
    `state = const EmailDashboardState()` (`email_sync_controller.dart:234`) — so
    every watcher of `emailDashboardControllerProvider` (incl. the profile row)
    refreshes.
  - **Connect** goes through a *different* controller:
    `EmailSetupController.save()` calls `service.connect()` and nothing else
    (`email_sync_controller.dart:72–74`). It does **not** update the dashboard
    state or `ref.invalidate(emailDashboardControllerProvider)`.
- **Root:** `EmailDashboardController.build()` reads `service.account` once
  (`:153`) and watches `emailSyncServiceProvider` — a singleton service whose
  identity doesn't change when `connect()` mutates its private `_account` field
  (`mock_email_sync_service.dart:22, 41–43`; the status stream only emits on
  syncNow/disconnect, per `:86`). So the provider isn't re-run on connect.
- **Impact:** `autoDispose` masks this in the usual flow (navigate away → provider
  drops → re-subscribe rebuilds fresh, reading the now-connected account). But a
  watcher that stays subscribed *across* the connect event — e.g. the You-tab
  Integrations row (`profile_screen.dart:44`) while the dashboard/setup is pushed
  above it — keeps showing "not connected" until the provider is disposed and
  rebuilt. Same symptom class as 06-20 #8, now reactivity-based.
- **Fix direction:** have `save()` invalidate/refresh the dashboard provider after
  `connect()` (mirror what disconnect does), or expose the connected account as a
  reactive provider that both the dashboard and the profile row watch — one
  source that actually emits on change.

---

## P3 — latent

### 2. `EmailDashboardState.copyWith` can't clear `account`
- **Seen (by code):** `copyWith(account: account ?? this.account)`
  (`email_sync_controller.dart:129`) — the standard Dart null-coalescing footgun
  means `copyWith` can never set `account` back to null. Not triggered today
  (disconnect uses a fresh `const EmailDashboardState()` instead, `:234`), but the
  method silently can't express "now disconnected", so any future caller that
  reaches for `copyWith` to clear it will be surprised.
- **Fix direction:** if a clear-via-copyWith is ever needed, use a sentinel/
  `Object?`-wrapper pattern; otherwise leave a note that disconnect must replace
  state wholesale.

---

## Coverage
Covered: `email_sync_controller` (setup/dashboard/sync), the connection-state
source shared by the dashboard + profile row, the mock service's account/status
model. Not covered: `real_email_sync_service` IMAP behavior (device-only) and the
setup form's credential-handling/secure-storage path.
