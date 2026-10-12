//
//  OpalRingsWidget.swift
//  OpalWidgets — Medium home-screen widget: Move and Routines rings, Money as a
//  what's-left row, and a round "+" that opens the Pal composer.
//
//  The provider fetches the v2 snapshot from the proxy (RingsSnapshotLoader); the
//  app POSTs it on every change and calls reloadAllTimelines() to refresh us
//  immediately, with a ~20-min timeline fallback for when the app isn't running.
//  The snapshot carries each row's state changes until midnight, so the timeline
//  holds one entry per change and the word flips on time with the app closed.
//  Every value and word comes from the app (area_state.dart); nothing here
//  computes a state. The "+" deep-links to the autofocused Pal composer; tapping
//  anywhere else opens Today. Both routes resolve through the existing
//  `opal://<host>` -> `/<host>` mapping (OpalIntentsBridge).
//
//  NOTE: edited on Windows where iOS can't be compiled — compile + verify on a
//  Mac. See docs/2026-06-14-mac-handoff-widget-proxy.md, "Rings widget v2".
//

import SwiftUI
import WidgetKit

private let composerURL = URL(string: "opal://pal-composer")!
private let todayURL = URL(string: "opal://today")!

// canvas Widget board geometry
private let ringsSize: CGFloat = 104
private let outerRadius: CGFloat = 46
private let innerRadius: CGFloat = 32
private let ringStroke: CGFloat = 12
private let trackOpacity = 0.2
private let emptyValue = "–"

struct RingsEntry: TimelineEntry {
  let date: Date
  /// Nil before the first fetch, or when the cache held an undecodable (v1) body.
  let snapshot: RingsSnapshot?
}

struct RingsProvider: TimelineProvider {
  func placeholder(in context: Context) -> RingsEntry {
    RingsEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (RingsEntry) -> Void) {
    if context.isPreview {
      completion(RingsEntry(date: Date(), snapshot: nil))
      return
    }
    Task {
      let snapshot = await RingsSnapshotLoader.load()
      completion(RingsEntry(date: Date(), snapshot: snapshot))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RingsEntry>) -> Void) {
    Task {
      let snapshot = await RingsSnapshotLoader.load()
      let now = Date()
      // The app nudges an immediate reload on change; this is just a fallback for
      // when the app isn't foregrounded to push (WidgetKit throttles either way).
      let next = Calendar.current.date(byAdding: .minute, value: 20, to: now)
        ?? now.addingTimeInterval(20 * 60)
      completion(Timeline(entries: Self.entries(for: snapshot, now: now), policy: .after(next)))
    }
  }

  /// One entry now, one per scheduled state change, and one at `until` where the
  /// view falls back to dashes.
  static func entries(for snapshot: RingsSnapshot?, now: Date) -> [RingsEntry] {
    var entries = [RingsEntry(date: now, snapshot: snapshot)]
    guard let snapshot else { return entries }
    let nowSeconds = Int(now.timeIntervalSince1970)
    let changes = Set([snapshot.move, snapshot.routines, snapshot.money].flatMap { $0.states.map(\.at) })
      .filter { $0 > nowSeconds && $0 < snapshot.until }
      .sorted()
    for at in changes {
      entries.append(RingsEntry(date: Date(timeIntervalSince1970: TimeInterval(at)), snapshot: snapshot))
    }
    if snapshot.until > nowSeconds {
      entries.append(RingsEntry(date: Date(timeIntervalSince1970: TimeInterval(snapshot.until)), snapshot: snapshot))
    }
    return entries
  }
}

/// Canvas `THEMES` per appearance; the area hues are app_colors.dart move and rituals.
private struct Palette {
  let surface: Color
  let ink: Color
  let ink2: Color
  let onInk: Color
  let move: Color
  let routines: Color
  let watch: Color
  let care: Color
  let thriving: Color

  static let dark = Palette(
    surface: Color(hex: 0x1A1F24), ink: Color(hex: 0xF7F1E8), ink2: Color(hex: 0xD3D1CE),
    onInk: Color(hex: 0x101418), move: Color(hex: 0x30D158), routines: Color(hex: 0xBF5AF2),
    watch: Color(hex: 0xE0B060), care: Color(hex: 0xF58A78), thriving: Color(hex: 0x7FB0F5))

  static let light = Palette(
    surface: Color(hex: 0xFEFAEF), ink: Color(hex: 0x1E2427), ink2: Color(hex: 0x4A4741),
    onInk: Color(hex: 0xF7F1E8), move: Color(hex: 0x34C759), routines: Color(hex: 0xAF52DE),
    watch: Color(hex: 0x86570F), care: Color(hex: 0xB32410), thriving: Color(hex: 0x2056A6))

  /// Ink for a state word; nil for `good` (no word shown) and for unknown states.
  func stateInk(_ state: String) -> Color? {
    switch state {
    case "watch": return watch
    case "care": return care
    case "thriving": return thriving
    default: return nil
    }
  }
}

private extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

private struct Ring: View {
  let radius: CGFloat
  let fraction: Double
  let color: Color
  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(trackOpacity), lineWidth: ringStroke)
      Circle()
        .trim(from: 0, to: min(max(fraction, 0), 1))
        .stroke(color, style: StrokeStyle(lineWidth: ringStroke, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .frame(width: radius * 2, height: radius * 2)
  }
}

private struct LegendItem {
  enum Marker {
    case swatch(Color)
    case dollar
  }

  let title: String
  let marker: Marker
  let value: String
  let word: (text: String, ink: Color)?
}

private struct LegendRow: View {
  let item: LegendItem
  let palette: Palette
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        switch item.marker {
        case .swatch(let color):
          Circle().fill(color).frame(width: 8, height: 8)
        case .dollar:
          Image(systemName: "dollarsign").font(.system(size: 12, weight: .semibold))
        }
        Text(item.title)
        if let word = item.word {
          Text(word.text).foregroundStyle(word.ink)
        }
      }
      .font(.system(size: 13, weight: .medium))
      .tracking(0.3)
      .foregroundStyle(palette.ink2)
      .lineLimit(1)

      Text(item.value)
        .font(.system(size: 15))
        .tracking(-0.23)
        .monospacedDigit()
        .foregroundStyle(palette.ink)
        .lineLimit(1)
    }
  }
}

struct RingsWidgetView: View {
  let entry: RingsEntry
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = colorScheme == .dark ? Palette.dark : Palette.light
    let snapshot = liveSnapshot
    let items = legendItems(snapshot, palette)
    ZStack(alignment: .topTrailing) {
      HStack(spacing: 14) {
        ZStack {
          Ring(radius: outerRadius, fraction: snapshot?.move.fraction ?? 0, color: palette.move)
          Ring(radius: innerRadius, fraction: snapshot?.routines.fraction ?? 0, color: palette.routines)
        }
        .frame(width: ringsSize, height: ringsSize)

        VStack(alignment: .leading, spacing: 4) {
          ForEach(items, id: \.title) { LegendRow(item: $0, palette: palette) }
        }
        Spacer(minLength: 0)
      }
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel(items, synced: snapshot != nil))

      Link(destination: composerURL) {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(palette.onInk)
          .frame(width: 38, height: 38)
          .background(Circle().fill(palette.ink))
      }
      .padding(12)
      .accessibilityLabel("Tell Pal anything")
    }
    .widgetURL(todayURL)
    .containerBackground(palette.surface, for: .widget)
  }

  /// Nil (dashes) when never synced or past `until`, so yesterday never shows as today.
  private var liveSnapshot: RingsSnapshot? {
    guard let snapshot = entry.snapshot, !snapshot.isExpired(at: entry.date) else { return nil }
    return snapshot
  }

  private func legendItems(_ snapshot: RingsSnapshot?, _ palette: Palette) -> [LegendItem] {
    func item(_ title: String, _ marker: LegendItem.Marker, _ row: RingsSnapshot.Row?) -> LegendItem {
      LegendItem(title: title, marker: marker, value: row?.value ?? emptyValue, word: word(row, palette))
    }
    return [
      item("Move", .swatch(palette.move), snapshot?.move),
      item("Routines", .swatch(palette.routines), snapshot?.routines),
      item("Money", .dollar, snapshot?.money),
    ]
  }

  private func word(_ row: RingsSnapshot.Row?, _ palette: Palette) -> (text: String, ink: Color)? {
    guard let change = row?.state(at: entry.date), let ink = palette.stateInk(change.state) else { return nil }
    return (change.word, ink)
  }

  private func accessibilityLabel(_ items: [LegendItem], synced: Bool) -> String {
    guard synced else { return "Opal. Not synced yet. Opens Today" }
    let rows = items.map { item in
      "\(item.title) \(item.value)" + (item.word.map { ", \($0.text)" } ?? "")
    }
    return "Opal. " + rows.joined(separator: ". ") + ". Opens Today"
  }
}

struct OpalRingsWidget: Widget {
  let kind = "OpalRingsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RingsProvider()) { entry in
      RingsWidgetView(entry: entry)
    }
    .configurationDisplayName("Opal")
    .description("Move, routines and what's left to spend.")
    .supportedFamilies([.systemMedium])
    // the view pads itself to the canvas's 16 (12 for the "+")
    .contentMarginsDisabled()
  }
}

#if DEBUG
// fixtures match the canvas cases in test/controllers/widget_sync_controller_test.dart (11:00, 2026-10-13)
private let previewNow = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 11))!
private let previewMidnight = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14))!

private func previewRow(_ fraction: Double?, _ value: String, _ state: String, _ word: String) -> RingsSnapshot.Row {
  RingsSnapshot.Row(
    fraction: fraction, value: value,
    states: [.init(at: Int(previewNow.timeIntervalSince1970), state: state, word: word)])
}

private func previewSnapshot(money: RingsSnapshot.Row, move: RingsSnapshot.Row, routines: RingsSnapshot.Row) -> RingsSnapshot {
  RingsSnapshot(until: Int(previewMidnight.timeIntervalSince1970), move: move, routines: routines, money: money)
}

private let watchSnapshot = previewSnapshot(
  money: previewRow(nil, "$22 left of $60", "watch", "Worth watching"),
  move: previewRow(0.62, "310 of 500 kcal", "good", "On track"),
  routines: previewRow(0.5, "2 of 4 done", "good", "On track"))

private let careSnapshot = previewSnapshot(
  money: previewRow(nil, "$4 over $60", "care", "Needs care"),
  move: previewRow(0.62, "310 of 500 kcal", "good", "On track"),
  routines: previewRow(0.5, "2 of 4 done", "good", "On track"))

private let aheadSnapshot = previewSnapshot(
  money: previewRow(nil, "$31 left of $60", "good", "On track"),
  move: previewRow(1.0, "520 of 500 kcal", "thriving", "Ahead"),
  routines: previewRow(1.0, "4 of 4 done", "thriving", "Ahead"))

// a v1 body (the old nine numbers) must decode to nil and render as dashes
private let v1Snapshot = try? JSONDecoder().decode(RingsSnapshot.self, from: Data(#"""
  {"moneyRing":0.6,"moveRing":0.62,"ritualsRing":0.5,"moneySpent":38,"dailyBudget":60,
   "moveKcal":310,"dailyMoveKcal":500,"ritualsDone":2,"dailyRitualTarget":4}
  """#.utf8))

#Preview("Watch", as: .systemMedium) {
  OpalRingsWidget()
} timeline: {
  RingsEntry(date: previewNow, snapshot: watchSnapshot)
}

#Preview("Care", as: .systemMedium) {
  OpalRingsWidget()
} timeline: {
  RingsEntry(date: previewNow, snapshot: careSnapshot)
}

#Preview("Ahead", as: .systemMedium) {
  OpalRingsWidget()
} timeline: {
  RingsEntry(date: previewNow, snapshot: aheadSnapshot)
}

#Preview("Empty", as: .systemMedium) {
  OpalRingsWidget()
} timeline: {
  RingsEntry(date: previewNow, snapshot: nil)
}

#Preview("Cached v1", as: .systemMedium) {
  OpalRingsWidget()
} timeline: {
  RingsEntry(date: previewNow, snapshot: v1Snapshot)
}
#endif
