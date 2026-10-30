//
//  OpalWatchApp.swift
//  OpalWatch
//
//  Pal logging on the Watch: say something, the iPhone logs it through Pal,
//  and the result comes back with Undo. Screens are in OpalWatchViews.
//

import SwiftUI

@main
struct OpalWatchApp: App {
  @StateObject private var link = OpalWatchLink()

  var body: some Scene {
    WindowGroup {
      PalView(link: link)
    }
  }
}
