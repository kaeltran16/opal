//
//  OpalRingsSnapshot.swift
//  OpalWidgets — the rings snapshot + how the widget fetches it.
//
//  A free Apple team can't provision an App Group, so the widget can't read the
//  app's local storage. Instead it fetches today's progress from the proxy
//  (`GET /v1/widget/snapshot`, written by the app on every change). The widget
//  authenticates with its own device token, self-registering once with the
//  provisioning key injected into this target's Info.plist at build time.
//
//  NOTE: edited on Windows where iOS can't be compiled — compile + verify on a
//  Mac. See docs/2026-06-12-mac-handoff-move-ring-kcal.md.
//

import Foundation

/// Today's progress the rings widget renders. Decoded straight from the server
/// JSON (the keys match `widgetSnapshotBody` on the server, camelCase).
struct RingsSnapshot: Codable {
  var moneyRing: Double
  var moveRing: Double
  var ritualsRing: Double
  var moneySpent: Double
  var dailyBudget: Double
  var moveKcal: Int
  var dailyMoveKcal: Int
  var ritualsDone: Int
  var dailyRitualTarget: Int

  /// Zeroed snapshot for "no data yet" (first fetch, offline cold start).
  static let empty = RingsSnapshot(
    moneyRing: 0, moveRing: 0, ritualsRing: 0,
    moneySpent: 0, dailyBudget: 0,
    moveKcal: 0, dailyMoveKcal: 0,
    ritualsDone: 0, dailyRitualTarget: 0)
}

/// Fetches the snapshot from the proxy, caching the last good value so a network
/// hiccup never blanks the widget. All failures degrade to the cached snapshot
/// (then `.empty`) — the widget must never crash or throw.
enum RingsSnapshotLoader {
  private static let store = UserDefaults.standard // widget's own sandbox; no sharing needed
  private static let tokenKey = "pal_widget_token"
  private static let deviceIdKey = "pal_widget_device_id"
  private static let lastSnapshotKey = "pal_widget_last_snapshot"

  // Injected into the OpalWidgets target's Info.plist at build time (see handoff).
  private static var baseUrl: URL? {
    guard let s = Bundle.main.object(forInfoDictionaryKey: "PAL_BASE_URL") as? String,
          !s.isEmpty else { return nil }
    return URL(string: s)
  }
  private static var provisioningKey: String? {
    Bundle.main.object(forInfoDictionaryKey: "PAL_PROVISIONING_KEY") as? String
  }

  /// Latest snapshot, or the last cached one, or `.empty`.
  static func load() async -> RingsSnapshot {
    if let fresh = await fetch() {
      cache(fresh)
      return fresh
    }
    return lastCached() ?? .empty
  }

  private static func fetch() async -> RingsSnapshot? {
    guard let base = baseUrl else { return nil }
    do {
      // first attempt with the cached token; a 401 clears it, then re-register once.
      if let snap = try await getSnapshot(base: base, token: token(base: base)) { return snap }
      return try await getSnapshot(base: base, token: token(base: base))
    } catch {
      return nil
    }
  }

  /// GET the snapshot. Returns nil on 401 (after clearing the stale token) so
  /// the caller re-registers; throws on other transport/parse errors.
  private static func getSnapshot(base: URL, token: String) async throws -> RingsSnapshot? {
    var req = URLRequest(url: base.appendingPathComponent("v1/widget/snapshot"))
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
    if code == 401 {
      store.removeObject(forKey: tokenKey)
      return nil
    }
    guard code == 200 else { throw URLError(.badServerResponse) }
    return try JSONDecoder().decode(RingsSnapshot.self, from: data)
  }

  /// Cached device token, self-registering once with the provisioning key.
  private static func token(base: URL) async throws -> String {
    if let t = store.string(forKey: tokenKey), !t.isEmpty { return t }
    guard let key = provisioningKey else { throw URLError(.userAuthenticationRequired) }

    var req = URLRequest(url: base.appendingPathComponent("v1/register"))
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(
      withJSONObject: ["provisioningKey": key, "deviceId": deviceId()])

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
      throw URLError(.userAuthenticationRequired)
    }
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let t = json?["token"] as? String else { throw URLError(.cannotParseResponse) }
    store.set(t, forKey: tokenKey)
    return t
  }

  private static func deviceId() -> String {
    if let id = store.string(forKey: deviceIdKey) { return id }
    let id = "widget-" + UUID().uuidString
    store.set(id, forKey: deviceIdKey)
    return id
  }

  private static func cache(_ snapshot: RingsSnapshot) {
    if let data = try? JSONEncoder().encode(snapshot) {
      store.set(data, forKey: lastSnapshotKey)
    }
  }

  private static func lastCached() -> RingsSnapshot? {
    guard let data = store.data(forKey: lastSnapshotKey) else { return nil }
    return try? JSONDecoder().decode(RingsSnapshot.self, from: data)
  }
}
