//
//  OpalWorkoutLiveActivity.swift
//  Opal — U25 Live Activities / Dynamic Island
//
//  SwiftUI presentation for the workout Live Activity: the lock-screen / banner
//  view and the Dynamic Island (compact, minimal, expanded). Belongs to the
//  WIDGET EXTENSION target (OpalWidgets) only.
//
//  Requires the shared `OpalWorkoutAttributes.swift` to ALSO be a member of this
//  target (Target Membership → OpalWidgets).
//
//  The timer ticks live, with no push updates, via `Text(timerInterval:)` driven
//  off `attributes.startedAt` (elapsed) or a derived rest-end date (countdown).
//  Tapping anywhere deep-links to `opal://session/<routineId>` via `widgetURL`.
//

import ActivityKit
import SwiftUI
import WidgetKit

// Opal "blue" accent (matches AppAccent.blue 0xFF007AFF on the Flutter side).
private let opalAccent = Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0)

// MARK: - Widget entry point

@available(iOS 16.1, *)
struct OpalWorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: OpalWorkoutActivityAttributes.self) { context in
      // Lock screen / banner presentation.
      OpalWorkoutLockScreenView(context: context)
        .widgetURL(context.attributes.deepLinkURL)
        .activityBackgroundTint(Color.black.opacity(0.55))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        // ----- Expanded regions -----
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(context.attributes.routineName)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          } icon: {
            Image(systemName: "figure.strengthtraining.traditional")
              .foregroundStyle(opalAccent)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          OpalTimerText(context: context)
            .font(.system(.title3, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .frame(maxWidth: 88)
        }
        DynamicIslandExpandedRegion(.center) {
          if let exercise = context.state.currentExercise {
            Text(exercise)
              .font(.caption)
              .foregroundStyle(.white)
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            if let sets = context.state.completedSets {
              Label("\(sets) sets", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            OpalPalListening()
          }
        }
      } compactLeading: {
        Image(systemName: "figure.strengthtraining.traditional")
          .foregroundStyle(opalAccent)
      } compactTrailing: {
        OpalTimerText(context: context)
          .font(.system(.caption, design: .rounded).monospacedDigit())
          .foregroundStyle(.white)
          .frame(maxWidth: 56)
      } minimal: {
        // When this is the only Live Activity, the minimal pill shows the timer.
        OpalTimerText(context: context)
          .font(.system(.caption2, design: .rounded).monospacedDigit())
          .foregroundStyle(opalAccent)
          .frame(maxWidth: 44)
      }
      .widgetURL(context.attributes.deepLinkURL)
      .keylineTint(opalAccent)
    }
  }
}

// MARK: - Lock-screen / banner view

@available(iOS 16.1, *)
private struct OpalWorkoutLockScreenView: View {
  let context: ActivityViewContext<OpalWorkoutActivityAttributes>

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "figure.strengthtraining.traditional")
        .font(.title2)
        .foregroundStyle(opalAccent)

      VStack(alignment: .leading, spacing: 2) {
        Text(context.attributes.routineName)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
        if let exercise = context.state.currentExercise {
          Text(exercise)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
        }
        HStack(spacing: 10) {
          if let sets = context.state.completedSets {
            Label("\(sets) sets", systemImage: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.white.opacity(0.7))
          }
          OpalPalListening()
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        OpalTimerText(context: context)
          .font(.system(.title, design: .rounded).monospacedDigit())
          .foregroundStyle(.white)
        Text(context.isResting ? "rest" : "elapsed")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.5))
      }
    }
    .padding(16)
  }
}

// MARK: - Live timer

/// Live-ticking timer text. Shows a rest countdown when resting, otherwise the
/// elapsed workout time. Both tick on-device with no push updates.
@available(iOS 16.1, *)
private struct OpalTimerText: View {
  let context: ActivityViewContext<OpalWorkoutActivityAttributes>

  var body: some View {
    if let restEnd = context.restEndDate {
      // Counts DOWN to the rest-end instant.
      Text(timerInterval: Date()...restEnd, countsDown: true)
        .multilineTextAlignment(.trailing)
    } else {
      // Counts UP from the workout start.
      Text(
        timerInterval: context.attributes.startedAt...Date.distantFuture,
        countsDown: false
      )
      .multilineTextAlignment(.trailing)
    }
  }
}

// MARK: - "Pal listening" affordance

@available(iOS 16.1, *)
private struct OpalPalListening: View {
  var body: some View {
    Label {
      Text("Pal listening")
        .font(.caption2)
    } icon: {
      Image(systemName: "waveform")
        .symbolEffect(.variableColor.iterative, options: .repeating)
    }
    .foregroundStyle(opalAccent)
  }
}

// MARK: - Convenience derivations

@available(iOS 16.1, *)
extension OpalWorkoutActivityAttributes {
  /// Deep-link target for a tap on the island / banner → GoRouter
  /// `/session/<routineId>`.
  var deepLinkURL: URL? {
    URL(string: "opal://session/\(routineId)")
  }
}

@available(iOS 16.1, *)
extension ActivityViewContext where Attributes == OpalWorkoutActivityAttributes {
  /// Whether a rest countdown is currently active.
  var isResting: Bool {
    (state.restRemainingSeconds ?? 0) > 0
  }

  /// The instant rest finishes, derived from the remaining seconds at update
  /// time, or `nil` when not resting. `Text(timerInterval:)` ticks toward it.
  var restEndDate: Date? {
    guard let remaining = state.restRemainingSeconds, remaining > 0 else {
      return nil
    }
    return Date().addingTimeInterval(TimeInterval(remaining))
  }
}
