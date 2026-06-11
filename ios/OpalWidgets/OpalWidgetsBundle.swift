//
//  OpalWidgetsBundle.swift
//  OpalWidgets — U25 widget extension entry point
//
//  The `@main` WidgetBundle for the OpalWidgets app-extension target. Lists the
//  widgets the extension vends: the workout Live Activity (Dynamic Island +
//  lock-screen banner) and the medium home-screen rings widget.
//  `OpalWorkoutLiveActivity` is gated to iOS 16.1+, which the extension's 26.0
//  deployment target always satisfies, so no `#available` guard is needed here.
//

import SwiftUI
import WidgetKit

@main
struct OpalWidgetsBundle: WidgetBundle {
  var body: some Widget {
    OpalWorkoutLiveActivity()
    OpalRingsWidget()
  }
}
