//
//  OpalWatchApp.swift
//  OpalWatch
//
//  Placeholder home screen until Pal logging lands: a button that pings the
//  iPhone, so a TestFlight build can show the WatchConnectivity link works.
//

import SwiftUI

@main
struct OpalWatchApp: App {
  @StateObject private var link = OpalWatchLink()

  var body: some Scene {
    WindowGroup {
      HomeView(link: link)
    }
  }
}

struct HomeView: View {
  @ObservedObject var link: OpalWatchLink

  var body: some View {
    VStack(spacing: 8) {
      Text("Opal")
        .font(.title3.bold())
      Button("Ping iPhone") { link.ping() }
      Text(link.status)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }
}
