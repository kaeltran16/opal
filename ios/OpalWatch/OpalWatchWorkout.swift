//
//  OpalWatchWorkout.swift
//  OpalWatch
//
//  The workout side of the Watch app. The session runs on the phone (the Dart
//  WorkoutSession engine): this shows the snapshots it sends and sends the
//  user's taps back as commands. Alongside runs an HKWorkoutSession, which
//  keeps the app frontmost on wrist-down, measures heart rate, energy and
//  distance, and saves the workout to Apple Health when it ends.
//
//  The phone starts it (HKHealthStore.startWatchApp), and it ends when the
//  phone says the session ended: after a Finish on either side.
//

import Foundation
import HealthKit
import WatchKit

/// What the phone said about the session. Every string is display-ready.
struct WorkoutSnapshot {
  let session: Int64
  let rev: Int
  let phase: String
  let setId: String?
  let timed: Bool
  let setLabel: String?
  let exercise: String?
  let planned: String?
  let best: String?
  let ahead: String?
  let restEndsAt: Date?
  let restTotal: TimeInterval
  let next: String?
  let progress: String?
  let canSkip: Bool
  let logged: String?

  init?(_ map: [String: Any]) {
    guard map[OpalWatchMessage.typeKey] as? String == OpalWatchMessage.workout,
      let phase = map[OpalWatchMessage.phaseKey] as? String
    else { return nil }
    self.phase = phase
    session = (map[OpalWatchMessage.sessionKey] as? NSNumber)?.int64Value ?? 0
    rev = (map[OpalWatchMessage.revKey] as? NSNumber)?.intValue ?? 0
    setId = map[OpalWatchMessage.setIdKey] as? String
    timed = map[OpalWatchMessage.timedKey] as? Bool ?? false
    setLabel = map[OpalWatchMessage.setLabelKey] as? String
    exercise = map[OpalWatchMessage.exerciseKey] as? String
    planned = map[OpalWatchMessage.plannedKey] as? String
    best = map[OpalWatchMessage.bestKey] as? String
    ahead = map[OpalWatchMessage.aheadKey] as? String
    restEndsAt = (map[OpalWatchMessage.restEndsAtKey] as? NSNumber).map {
      Date(timeIntervalSince1970: $0.doubleValue / 1000)
    }
    restTotal = (map[OpalWatchMessage.restTotalKey] as? NSNumber)?.doubleValue ?? 0
    next = map[OpalWatchMessage.nextKey] as? String
    progress = map[OpalWatchMessage.progressKey] as? String
    canSkip = map[OpalWatchMessage.canSkipKey] as? Bool ?? false
    logged = map[OpalWatchMessage.loggedKey] as? String
  }

  /// Whether this replaces [current]: a later session, or a later revision of
  /// the same one. "No workout" carries neither and always applies.
  func isNewer(than current: WorkoutSnapshot?) -> Bool {
    guard let current, phase != OpalWatchMessage.phaseNone else { return true }
    return session > current.session || (session == current.session && rev > current.rev)
  }
}

/// A command the phone didn't get; Try again sends it once more.
struct WorkoutFailure {
  let command: OpalWorkoutCommand
  let reason: String
}

final class OpalWatchWorkout: NSObject, ObservableObject {
  /// True from the phone's start until the session ends; the app shows the
  /// workout meanwhile, Pal logging otherwise.
  @Published private(set) var active = false
  @Published private(set) var snapshot: WorkoutSnapshot?
  @Published private(set) var heartRate: Double?
  @Published private(set) var sending: OpalWorkoutCommand?
  @Published private(set) var failure: WorkoutFailure?
  @Published private var distanceTotal: Double = 0

  /// Sends a message to the phone; OpalWatchLink sets it.
  var transmit: (([String: Any], @escaping (PhoneOutcome) -> Void) -> Void)?

  private static let restWarning: TimeInterval = 10
  private static let bpm = HKUnit.count().unitDivided(by: .minute())
  private static let readTypes: Set<HKObjectType> = [
    HKQuantityType(.heartRate),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.distanceWalkingRunning),
  ]

  private let store = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  /// The timed set being measured, and the distance total when it came up.
  private var distanceBaseline: (setId: String, metres: Double)?
  private var restCues: [Timer] = []

  /// Metres walked or run since the current timed set came up.
  var setDistance: Double {
    guard let baseline = distanceBaseline, baseline.setId == snapshot?.setId else { return 0 }
    return max(0, distanceTotal - baseline.metres)
  }

  /// A rest the phone started that hasn't run out here yet.
  var resting: Bool {
    guard let snapshot, snapshot.phase == OpalWatchMessage.phaseRest,
      let endsAt = snapshot.restEndsAt
    else { return false }
    return endsAt > Date()
  }

  func elapsed(at date: Date) -> TimeInterval {
    builder?.elapsedTime(at: date) ?? 0
  }

  // MARK: - start and end

  /// The phone opened the app for a workout (WKApplicationDelegate).
  func start(_ configuration: HKWorkoutConfiguration) {
    active = true
    failure = nil
    guard session == nil else { return send(.state) }
    let share: Set<HKSampleType> = [HKObjectType.workoutType()]
    store.requestAuthorization(toShare: share, read: Self.readTypes) { _, error in
      if let error {
        NSLog("OpalWatchWorkout: authorization failed — \(error.localizedDescription)")
      }
      DispatchQueue.main.async { self.begin(configuration) }
    }
  }

  private func begin(_ configuration: HKWorkoutConfiguration) {
    do {
      let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
      // a strength workout doesn't collect distance on its own; a treadmill set needs it
      source.enableCollection(for: HKQuantityType(.distanceWalkingRunning), predicate: nil)
      builder.dataSource = source
      session.delegate = self
      builder.delegate = self
      self.session = session
      self.builder = builder
      let start = Date()
      session.startActivity(with: start)
      builder.beginCollection(withStart: start) { _, error in
        if let error {
          NSLog("OpalWatchWorkout: collection failed — \(error.localizedDescription)")
        }
      }
    } catch {
      // the remote still works; only measuring and staying frontmost are lost
      NSLog("OpalWatchWorkout: no workout session — \(error.localizedDescription)")
    }
    send(.state)
  }

  /// The phone finished the session: end here and give it the numbers.
  func endFromPhone() -> [String: Any] {
    let numbers = measured()
    end()
    return numbers
  }

  /// "No workout on your iPhone": the phone app went and took the session with
  /// it, so the Watch ends its own.
  func endWithoutPhone() {
    end()
    snapshot = nil
  }

  /// Ends the HKWorkoutSession; Health saves it once the session reports ended.
  private func end() {
    restCues.forEach { $0.invalidate() }
    restCues = []
    active = false
    sending = nil
    failure = nil
    session?.end()
  }

  /// Average heart rate and active energy over the workout so far.
  private func measured() -> [String: Any] {
    var numbers: [String: Any] = [:]
    if let average = builder?.statistics(for: HKQuantityType(.heartRate))?.averageQuantity() {
      numbers[OpalWatchMessage.heartRateKey] = Int(average.doubleValue(for: Self.bpm).rounded())
    }
    if let energy = builder?.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
      numbers[OpalWatchMessage.kcalKey] = Int(energy.doubleValue(for: .kilocalorie()).rounded())
    }
    return numbers
  }

  // MARK: - phone

  func send(_ command: OpalWorkoutCommand) {
    guard let transmit else { return }
    var message: [String: Any] = [
      OpalWatchMessage.typeKey: OpalWatchMessage.workout,
      OpalWatchMessage.commandKey: command.rawValue,
    ]
    if let setId = snapshot?.setId {
      message[OpalWatchMessage.setIdKey] = setId
    }
    if command == .complete, snapshot?.timed == true, setDistance > 0 {
      // km to two places
      message[OpalWatchMessage.distanceKmKey] = (setDistance / 10).rounded() / 100
    }
    if command == .finish {
      message.merge(measured()) { _, measured in measured }
    }
    // asking for the state is silent; the user's taps show progress and failure
    if command != .state {
      sending = command
      failure = nil
    }
    transmit(message) { [weak self] outcome in
      guard let self else { return }
      if self.sending == command { self.sending = nil }
      switch outcome {
      case .reply(let map):
        self.receive(map)
      case .failed(let reason):
        if command != .state {
          self.failure = WorkoutFailure(command: command, reason: reason)
        }
      }
    }
  }

  func retry() {
    if let failure { send(failure.command) }
  }

  /// A snapshot: a reply, a push, or the application context.
  func receive(_ map: [String: Any]) {
    guard let next = WorkoutSnapshot(map), next.isNewer(than: snapshot) else { return }
    snapshot = next
    failure = nil
    if next.phase == OpalWatchMessage.phaseEnded {
      if active { end() }
      return
    }
    markTimedSet()
    scheduleRestCues()
  }

  // MARK: - rest and distance

  /// A tap at 10 s and at 0, like the phone; at 0 the set comes back on screen.
  private func scheduleRestCues() {
    restCues.forEach { $0.invalidate() }
    restCues = []
    guard active, resting, let endsAt = snapshot?.restEndsAt else { return }
    let cues: [(before: TimeInterval, haptic: WKHapticType)] = [
      (Self.restWarning, .directionUp), (0, .notification),
    ]
    for cue in cues {
      let fireAt = endsAt.addingTimeInterval(-cue.before)
      guard fireAt > Date() else { continue }
      let timer = Timer(fire: fireAt, interval: 0, repeats: false) { [weak self] _ in
        WKInterfaceDevice.current().play(cue.haptic)
        if cue.before == 0 { self?.restRanOut() }
      }
      RunLoop.main.add(timer, forMode: .common)
      restCues.append(timer)
    }
  }

  private func restRanOut() {
    objectWillChange.send()
    markTimedSet()
  }

  /// A timed set measures from when it comes up, not from its rest.
  private func markTimedSet() {
    guard let snapshot, snapshot.timed, let setId = snapshot.setId, !resting,
      distanceBaseline?.setId != setId
    else { return }
    distanceBaseline = (setId, distanceTotal)
  }

  private func healthWorkoutEnded(_ ended: HKWorkoutSession, at date: Date) {
    guard ended === session, let builder else { return }
    session = nil
    self.builder = nil
    heartRate = nil
    distanceTotal = 0
    distanceBaseline = nil
    builder.endCollection(withEnd: date) { _, error in
      if let error {
        NSLog("OpalWatchWorkout: ending collection failed — \(error.localizedDescription)")
      }
      builder.finishWorkout { _, error in
        if let error {
          NSLog("OpalWatchWorkout: saving to Health failed — \(error.localizedDescription)")
        }
      }
    }
  }
}

extension OpalWatchWorkout: HKWorkoutSessionDelegate {
  func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {
    guard toState == .ended else { return }
    DispatchQueue.main.async { self.healthWorkoutEnded(workoutSession, at: date) }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    NSLog("OpalWatchWorkout: workout session failed — \(error.localizedDescription)")
  }
}

extension OpalWatchWorkout: HKLiveWorkoutBuilderDelegate {
  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    let heart = workoutBuilder.statistics(for: HKQuantityType(.heartRate))?
      .mostRecentQuantity()?.doubleValue(for: Self.bpm)
    let metres = workoutBuilder.statistics(for: HKQuantityType(.distanceWalkingRunning))?
      .sumQuantity()?.doubleValue(for: .meter())
    DispatchQueue.main.async {
      if let heart { self.heartRate = heart }
      if let metres { self.distanceTotal = metres }
    }
  }
}
