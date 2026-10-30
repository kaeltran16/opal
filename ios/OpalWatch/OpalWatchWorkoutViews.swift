//
//  OpalWatchWorkoutViews.swift
//  OpalWatch
//
//  The workout screens of docs/design/watch-app/Workout.dc.html. Two pages as
//  in Apple's Workout app: the controls to the left, the set to the right.
//  Every string comes formatted from the phone; the Watch adds only what it
//  measures (elapsed time, heart rate, a timed set's distance). Wrist down,
//  always-on dims the screen and hides the buttons.
//

import SwiftUI

private enum Layout {
  static let ring: CGFloat = 108
  static let ringLine: CGFloat = 8
  static let gap: CGFloat = 6
  static let metresPerKm = 1000.0
}

struct WorkoutView: View {
  @ObservedObject var workout: OpalWatchWorkout
  @State private var page = Page.set

  private enum Page {
    case controls
    case set
  }

  var body: some View {
    TabView(selection: $page) {
      ControlsPage(workout: workout).tag(Page.controls)
      SetPage(workout: workout).tag(Page.set)
    }
    .tabViewStyle(.page)
    .foregroundStyle(Palette.ink)
  }
}

// MARK: - pages

/// 1, 2, 5 · Set, 3, 4 · Rest, 7 · Done, 8 · No iPhone.
private struct SetPage: View {
  @ObservedObject var workout: OpalWatchWorkout

  var body: some View {
    VStack(alignment: .leading, spacing: Layout.gap) {
      MetricsHeader(workout: workout)
      content.frame(maxHeight: .infinity, alignment: .top)
    }
  }

  @ViewBuilder private var content: some View {
    if let failure = workout.failure {
      FailedBody(failure: failure, onRetry: workout.retry)
    } else if let snapshot = workout.snapshot {
      switch snapshot.phase {
      case OpalWatchMessage.phaseSet, OpalWatchMessage.phaseRest:
        if workout.resting {
          RestBody(
            snapshot: snapshot, busy: workout.sending != nil,
            onAddTime: { workout.send(.addRest) }, onSkip: { workout.send(.skipRest) })
        } else {
          SetBody(
            snapshot: snapshot, metres: workout.setDistance,
            sending: workout.sending == .complete, onComplete: { workout.send(.complete) })
        }
      case OpalWatchMessage.phaseDone:
        DoneBody(
          logged: snapshot.logged, sending: workout.sending == .finish,
          onFinish: { workout.send(.finish) })
      case OpalWatchMessage.phaseNone:
        NoWorkoutBody(onEnd: workout.endWithoutPhone)
      default:
        WaitingBody()
      }
    } else {
      WaitingBody()
    }
  }
}

/// 6 · Controls. The phone's Add set, Skip exercise and Finish.
private struct ControlsPage: View {
  @ObservedObject var workout: OpalWatchWorkout
  @Environment(\.isLuminanceReduced) private var dimmed

  var body: some View {
    let snapshot = workout.snapshot
    VStack(alignment: .leading, spacing: Layout.gap) {
      MetricsHeader(workout: workout)
      if snapshot?.phase == OpalWatchMessage.phaseNone {
        NoWorkoutBody(onEnd: workout.endWithoutPhone)
      } else {
        if let line = snapshot?.progress ?? snapshot?.logged {
          Text(line).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
        }
        Spacer(minLength: 0)
        if !dimmed {
          if snapshot?.setId != nil {
            CommandButton(label: "Add set", command: .addSet, filled: false, workout: workout)
            if snapshot?.canSkip == true {
              CommandButton(
                label: "Skip exercise", command: .skipExercise, filled: false, workout: workout)
            }
          }
          CommandButton(label: "Finish", command: .finish, filled: true, workout: workout)
        }
      }
    }
  }
}

// MARK: - bodies

private struct SetBody: View {
  let snapshot: WorkoutSnapshot
  let metres: Double
  let sending: Bool
  let onComplete: () -> Void
  @Environment(\.isLuminanceReduced) private var dimmed

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(snapshot.setLabel ?? "").font(.caption).foregroundStyle(Palette.muted)
      Text(snapshot.exercise ?? "").font(.headline).lineLimit(1)
      Text(snapshot.planned ?? "").font(.title2.weight(.light)).monospacedDigit()
      if snapshot.timed {
        Text(distanceLine).font(.caption).foregroundStyle(Palette.muted)
      } else if let ahead = snapshot.ahead {
        Text(ahead).font(.caption).foregroundStyle(Palette.ahead)
      } else if let best = snapshot.best {
        Text(best).font(.caption).foregroundStyle(Palette.muted)
      }
      Spacer(minLength: Layout.gap)
      if !dimmed {
        Button(action: onComplete) {
          if sending { ProgressView() } else { Text("Complete set") }
        }
        .buttonStyle(PillStyle(filled: true))
        .disabled(sending)
        .handGestureShortcut(.primaryAction)
      }
    }
  }

  private var distanceLine: String {
    guard metres > 0 else { return "Distance from the watch" }
    let km = (metres / Layout.metresPerKm).formatted(.number.precision(.fractionLength(1)))
    return "\(km) km so far, from the watch"
  }
}

/// The ring drains as the rest runs down; it counts on here even while the
/// phone sleeps.
private struct RestBody: View {
  let snapshot: WorkoutSnapshot
  let busy: Bool
  let onAddTime: () -> Void
  let onSkip: () -> Void
  @Environment(\.isLuminanceReduced) private var dimmed

  var body: some View {
    let endsAt = snapshot.restEndsAt ?? Date()
    VStack(spacing: Layout.gap) {
      TimelineView(.periodic(from: Date(), by: 1)) { context in
        ZStack {
          RestRing(fraction: fraction(at: context.date, endsAt: endsAt), dimmed: dimmed)
          VStack(spacing: 0) {
            Text("Rest").font(.caption).foregroundStyle(Palette.muted)
            Text(timerInterval: min(context.date, endsAt)...endsAt, countsDown: true)
              .font(.title3.weight(.light))
              .monospacedDigit()
              .multilineTextAlignment(.center)
          }
        }
        .frame(width: Layout.ring, height: Layout.ring)
      }
      if let next = snapshot.next {
        Text("Next: \(next)").font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
      }
      if !dimmed {
        HStack(spacing: Layout.gap) {
          Button("+30 s", action: onAddTime).buttonStyle(PillStyle(filled: false))
          Button("Skip rest", action: onSkip).buttonStyle(PillStyle(filled: true))
        }
        .disabled(busy)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func fraction(at date: Date, endsAt: Date) -> Double {
    guard snapshot.restTotal > 0 else { return 0 }
    return min(max(endsAt.timeIntervalSince(date) / snapshot.restTotal, 0), 1)
  }
}

private struct RestRing: View {
  let fraction: Double
  let dimmed: Bool

  var body: some View {
    ZStack {
      Circle().stroke(dimmed ? Palette.chip : Palette.track, lineWidth: Layout.ringLine)
      Circle()
        .trim(from: 0, to: fraction)
        .stroke(
          dimmed ? Palette.muted : Palette.ink,
          style: StrokeStyle(lineWidth: Layout.ringLine, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .padding(Layout.ringLine / 2)
    .accessibilityHidden(true)
  }
}

/// 7 · Done. Finish ends the Watch workout and opens the summary on the phone.
private struct DoneBody: View {
  let logged: String?
  let sending: Bool
  let onFinish: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let logged {
        Text(logged).font(.caption).foregroundStyle(Palette.muted)
      }
      Text("All sets logged").font(.headline)
      Spacer(minLength: Layout.gap)
      Button(action: onFinish) {
        if sending { ProgressView() } else { Text("Finish") }
      }
      .buttonStyle(PillStyle(filled: true))
      .disabled(sending)
    }
  }
}

/// 8 · No iPhone. Only logging waits on the phone; the Watch keeps recording.
private struct FailedBody: View {
  let failure: WorkoutFailure
  let onRetry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Image(systemName: "iphone.slash").font(.caption).foregroundStyle(Palette.muted)
        .accessibilityHidden(true)
      Text(failure.reason).font(.headline)
      Text(detail).font(.footnote).foregroundStyle(Palette.muted)
      Spacer(minLength: Layout.gap)
      Button("Try again", action: onRetry).buttonStyle(PillStyle(filled: true))
    }
  }

  private var detail: String {
    let recording = "Heart rate is still recording."
    switch failure.command {
    case .complete: return "This set isn't logged. \(recording)"
    case .finish: return "The workout isn't finished. \(recording)"
    default: return "Nothing changed. \(recording)"
    }
  }
}

/// Not drawn: the phone app closed and took the session with it.
private struct NoWorkoutBody: View {
  let onEnd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("No workout on your iPhone").font(.headline)
      Text("End this one to save it to Health.").font(.footnote).foregroundStyle(Palette.muted)
      Spacer(minLength: Layout.gap)
      Button("End workout", action: onEnd).buttonStyle(PillStyle(filled: true))
    }
  }
}

private struct WaitingBody: View {
  var body: some View {
    VStack(spacing: Layout.gap) {
      ProgressView()
      Text("Waiting for your iPhone").font(.footnote).foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - parts

/// Elapsed time and heart rate from the Watch's own workout.
private struct MetricsHeader: View {
  @ObservedObject var workout: OpalWatchWorkout

  var body: some View {
    TimelineView(.periodic(from: Date(), by: 1)) { context in
      HStack(spacing: Layout.gap) {
        Text(Self.clock(workout.elapsed(at: context.date))).monospacedDigit()
        if let heartRate = workout.heartRate {
          HStack(spacing: 2) {
            Image(systemName: "heart").accessibilityHidden(true)
            Text("\(Int(heartRate.rounded()))").monospacedDigit()
          }
          .font(.caption.weight(.medium))
          .foregroundStyle(Palette.muted)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Heart rate \(Int(heartRate.rounded()))")
        }
      }
      .font(.footnote.weight(.medium))
    }
  }

  private static func clock(_ elapsed: TimeInterval) -> String {
    let seconds = Int(elapsed)
    let hours = seconds / 3600
    let minutes = seconds / 60 % 60
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
      : String(format: "%d:%02d", minutes, seconds % 60)
  }
}

private struct CommandButton: View {
  let label: String
  let command: OpalWorkoutCommand
  let filled: Bool
  @ObservedObject var workout: OpalWatchWorkout

  var body: some View {
    Button {
      workout.send(command)
    } label: {
      if workout.sending == command { ProgressView() } else { Text(label) }
    }
    .buttonStyle(PillStyle(filled: filled))
    .disabled(workout.sending != nil)
  }
}
