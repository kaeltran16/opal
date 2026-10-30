//
//  OpalWatchViews.swift
//  OpalWatch
//
//  The Pal logging screens of docs/design/watch-app/Main.dc.html. Each result
//  has the same shape: what happened, the thing itself, its detail, then one
//  action in the same spot at the bottom. All text arrives formatted from the
//  phone; these views only lay it out.
//

import SwiftUI

private enum Palette {
  static let ink = Color(hex: 0xF7F1E8)
  static let muted = Color(hex: 0xA8A5A0)
  static let soft = Color(hex: 0xD3D1CE)
  static let chip = Color(hex: 0x242A30)
  static let track = Color(hex: 0x39424A)
  static let onInk = Color(hex: 0x101418)
}

private enum Metrics {
  static let micButton: CGFloat = 88
  static let micIcon: CGFloat = 36
  static let statusIcon: CGFloat = 20
  static let actionHeight: CGFloat = 38
  static let spinner: CGFloat = 14
  static let barWidth: CGFloat = 3
  static let barStep: CGFloat = 3
  static let maxBars = 3
  static let meterHeight: CGFloat = 4
}

extension Color {
  fileprivate init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

struct PalView: View {
  @ObservedObject var link: OpalWatchLink

  var body: some View {
    NavigationStack {
      screen.navigationTitle("Pal")
    }
  }

  @ViewBuilder private var screen: some View {
    switch link.screen {
    case .ready:
      ReadyScreen(onSubmit: link.log)
    case .sending(let text):
      SendingScreen(text: text).closable(link.reset)
    case .result(let text, let reply):
      ResultScreen(
        text: text, reply: reply, undoing: link.undoing, undoError: link.undoError,
        onUndo: link.undo
      )
      .closable(link.reset)
    case .undone(let text, let reply):
      UndoneScreen(text: text, reply: reply, onSubmit: link.log).closable(link.reset)
    case .failed(let text, let reason):
      FailedScreen(text: text, reason: reason, onRetry: link.retry).closable(link.reset)
    }
  }
}

// MARK: - screens

/// 1 · Ready. One tap opens the system input, which offers dictation.
private struct ReadyScreen: View {
  let onSubmit: (String) -> Void

  var body: some View {
    VStack(spacing: 10) {
      TextFieldLink(prompt: Text("Tell Pal anything")) {
        Image(systemName: "mic.fill")
          .font(.system(size: Metrics.micIcon))
          .foregroundStyle(Palette.onInk)
          .frame(width: Metrics.micButton, height: Metrics.micButton)
          .background(Circle().fill(Palette.ink))
      } onSubmit: { text in
        onSubmit(text)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dictate to Pal")
      Text("Tell Pal anything")
        .font(.footnote)
        .foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// 3 · Sending. The progress sits where Undo will land.
private struct SendingScreen: View {
  let text: String

  var body: some View {
    ScreenLayout {
      Text("You said").font(.caption).foregroundStyle(Palette.muted)
      Text(text).font(.body)
    } action: {
      HStack(spacing: 8) {
        ProgressView().frame(width: Metrics.spinner, height: Metrics.spinner)
        Text("Logging on your iPhone").font(.footnote).foregroundStyle(Palette.muted)
      }
      .frame(height: Metrics.actionHeight)
    }
  }
}

/// 4 · Logged, 5 · Meal logged, 7 · Pal answered.
private struct ResultScreen: View {
  let text: String
  let reply: PalReply
  let undoing: Bool
  let undoError: String?
  let onUndo: () -> Void

  var body: some View {
    ScreenLayout {
      if reply.item != nil {
        LoggedBody(reply: reply)
      } else {
        AnswerBody(question: text, answer: reply.reply ?? "")
      }
      if let undoError {
        Text(undoError).font(.caption).foregroundStyle(Palette.muted)
      }
    } action: {
      if reply.undoToken != nil {
        Button(action: onUndo) {
          if undoing { ProgressView() } else { Text("Undo") }
        }
        .buttonStyle(PillStyle(filled: false))
        .disabled(undoing)
      }
    }
  }
}

/// 6 · Undone. What went stays in view, struck through; the action is a retry.
private struct UndoneScreen: View {
  let text: String
  let reply: PalReply
  let onSubmit: (String) -> Void

  var body: some View {
    ScreenLayout {
      StatusRow(symbol: "arrow.uturn.backward", text: "Undone", tint: Palette.muted)
      if let item = reply.item {
        Text(item).font(.headline).strikethrough()
        if let amount = reply.amount {
          AmountRow(amount: amount, unit: reply.unit).strikethrough()
        }
      } else {
        Text(reply.reply ?? text).font(.body).strikethrough()
      }
    } action: {
      TextFieldLink(prompt: Text("Tell Pal anything")) {
        Label("Say it again", systemImage: "mic.fill").pill(filled: true)
      } onSubmit: { text in
        onSubmit(text)
      }
      .buttonStyle(.plain)
    }
  }
}

/// 8 · Not logged. Dropped, not queued; the words stay for Try again.
private struct FailedScreen: View {
  let text: String
  let reason: String
  let onRetry: () -> Void

  var body: some View {
    ScreenLayout {
      StatusRow(symbol: "iphone.slash", text: "Not logged", tint: Palette.muted)
      Text(reason).font(.headline)
      Text("\u{201C}\(text)\u{201D}").font(.footnote).foregroundStyle(Palette.muted)
    } action: {
      Button("Try again", action: onRetry).buttonStyle(PillStyle(filled: true))
    }
  }
}

// MARK: - parts

private struct LoggedBody: View {
  let reply: PalReply

  var body: some View {
    StatusRow(symbol: "checkmark", text: reply.title ?? "Logged", tint: Palette.ink)
    if let item = reply.item {
      Text(item).font(.headline)
    }
    if let amount = reply.amount {
      AmountRow(amount: amount, unit: reply.unit)
    }
    if let detail = reply.detail {
      if let bars = reply.bars {
        HStack(spacing: 6) {
          ConfidenceBars(filled: bars)
          Text(detail)
        }
        .font(.caption)
        .foregroundStyle(Palette.muted)
        .padding(.top, 6)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text(detail).font(.caption).foregroundStyle(Palette.muted)
          if let value = reply.value {
            Text(value).font(.footnote).monospacedDigit().foregroundStyle(Palette.soft)
          }
          if let fraction = reply.fraction {
            Meter(fraction: fraction).padding(.top, 5)
          }
        }
        .padding(.top, 6)
      }
    }
  }
}

private struct AnswerBody: View {
  let question: String
  let answer: String

  var body: some View {
    Text(question).font(.caption).foregroundStyle(Palette.muted)
    Text(answer).font(.body)
  }
}

private struct StatusRow: View {
  let symbol: String
  let text: String
  let tint: Color

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
        .frame(width: Metrics.statusIcon, height: Metrics.statusIcon)
        .background(Circle().fill(Palette.chip))
        .accessibilityHidden(true)
      Text(text).font(.caption).foregroundStyle(Palette.muted)
    }
  }
}

private struct AmountRow: View {
  let amount: String
  let unit: String?

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text(amount).font(.title2.weight(.light)).monospacedDigit()
      if let unit {
        Text(unit).font(.subheadline).foregroundStyle(Palette.soft)
      }
    }
  }
}

/// The phone's confidence bars: [filled] of three, rising.
private struct ConfidenceBars: View {
  let filled: Int

  var body: some View {
    HStack(alignment: .bottom, spacing: 2) {
      ForEach(1...Metrics.maxBars, id: \.self) { bar in
        RoundedRectangle(cornerRadius: 1)
          .fill(bar <= filled ? Palette.soft : Palette.track)
          .frame(width: Metrics.barWidth, height: Metrics.barStep * CGFloat(bar + 1))
      }
    }
    .accessibilityHidden(true)
  }
}

/// Today's spending against the budget.
private struct Meter: View {
  let fraction: Double

  var body: some View {
    Capsule()
      .fill(Palette.track)
      .frame(height: Metrics.meterHeight)
      .overlay(alignment: .leading) {
        GeometryReader { geometry in
          Capsule()
            .fill(Palette.ink)
            .frame(width: geometry.size.width * min(max(fraction, 0), 1))
        }
      }
      .accessibilityHidden(true)
  }
}

/// Content that scrolls with the Crown, and the one action pinned below it.
private struct ScreenLayout<Content: View, Action: View>: View {
  private let content: Content
  private let action: Action

  init(@ViewBuilder content: () -> Content, @ViewBuilder action: () -> Action) {
    self.content = content()
    self.action = action()
  }

  var body: some View {
    VStack(spacing: 8) {
      ScrollView {
        VStack(alignment: .leading, spacing: 4) { content }
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      action
    }
    .foregroundStyle(Palette.ink)
  }
}

private struct PillStyle: ButtonStyle {
  let filled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .pill(filled: filled)
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

extension View {
  fileprivate func pill(filled: Bool) -> some View {
    font(.callout.weight(.semibold))
      .foregroundStyle(filled ? Palette.onInk : Palette.ink)
      .frame(maxWidth: .infinity, minHeight: Metrics.actionHeight)
      .background(Capsule().fill(filled ? Palette.ink : Palette.chip))
  }

  /// Not drawn in the mockup: a way back to Ready from any result.
  fileprivate func closable(_ close: @escaping () -> Void) -> some View {
    toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button(action: close) {
          Image(systemName: "xmark")
        }
        .accessibilityLabel("Close")
      }
    }
  }
}
