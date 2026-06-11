//
//  OpalRingsWidget.swift
//  OpalWidgets — Medium home-screen widget: three activity rings + a "+" FAB.
//
//  Static snapshot (no live animation): the app pushes data via
//  OpalWidgetSyncBridge and reloads timelines, so the provider just reads the
//  shared RingsSnapshot. The "+" deep-links to the autofocused Pal composer;
//  tapping anywhere else opens Today. Both routes already resolve through the
//  existing `opal://<host>` -> `/<host>` mapping (OpalIntentsBridge).
//

import SwiftUI
import WidgetKit

// Tracker hues (match the Flutter side: money #FF9500, move #34C759, rituals #AF52DE).
private let moneyColor = Color(red: 1.0, green: 149.0 / 255.0, blue: 0.0)
private let moveColor = Color(red: 52.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0)
private let ritualsColor = Color(red: 175.0 / 255.0, green: 82.0 / 255.0, blue: 222.0 / 255.0)
private let fabColor = Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0)

struct RingsEntry: TimelineEntry {
  let date: Date
  let snapshot: RingsSnapshot
}

struct RingsProvider: TimelineProvider {
  func placeholder(in context: Context) -> RingsEntry {
    RingsEntry(date: Date(), snapshot: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (RingsEntry) -> Void) {
    completion(RingsEntry(date: Date(), snapshot: RingsSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RingsEntry>) -> Void) {
    // Single entry; the app pushes reloads when data changes, so never auto-refresh.
    let entry = RingsEntry(date: Date(), snapshot: RingsSnapshot.load())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

private struct Ring: View {
  let fraction: Double
  let color: Color
  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(0.2), lineWidth: 11)
      Circle()
        .trim(from: 0, to: min(max(fraction, 0), 1))
        .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

private struct RingsStack: View {
  let s: RingsSnapshot
  var body: some View {
    ZStack {
      Ring(fraction: s.moneyRing, color: moneyColor)
      Ring(fraction: s.moveRing, color: moveColor).padding(14)
      Ring(fraction: s.ritualsRing, color: ritualsColor).padding(28)
    }
  }
}

private struct StatRow: View {
  let color: Color
  let value: String
  let suffix: String
  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(value).font(.system(size: 14, weight: .semibold))
      Text(suffix).font(.system(size: 12)).foregroundStyle(.secondary)
    }
  }
}

struct RingsWidgetView: View {
  let entry: RingsEntry
  var body: some View {
    let s = entry.snapshot
    ZStack(alignment: .bottomTrailing) {
      HStack(spacing: 14) {
        RingsStack(s: s).frame(width: 92, height: 92)
        VStack(alignment: .leading, spacing: 8) {
          StatRow(color: moneyColor, value: "$\(Int(s.moneySpent))", suffix: "/ $\(Int(s.dailyBudget)) spent")
          StatRow(color: moveColor, value: "\(s.moveMinutes)", suffix: "/ \(s.dailyMoveMinutes) min")
          StatRow(color: ritualsColor, value: "\(s.ritualsDone)", suffix: "/ \(s.dailyRitualTarget) rituals")
        }
        Spacer()
      }
      .padding(16)

      // The "+" FAB: opens the autofocused Pal composer via deep link.
      Link(destination: URL(string: "opal://pal-composer")!) {
        Image(systemName: "plus")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 38, height: 38)
          .background(Circle().fill(fabColor))
      }
      .padding(12)
    }
    // Tapping anywhere else opens Today.
    .widgetURL(URL(string: "opal://today"))
  }
}

struct OpalRingsWidget: Widget {
  let kind = "OpalRingsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RingsProvider()) { entry in
      RingsWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Opal Today")
    .description("Your money, move, and rituals progress.")
    .supportedFamilies([.systemMedium])
  }
}
