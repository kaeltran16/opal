//
//  OpalHealthBridge.swift
//  Runner
//
//  Read-only Apple Health bridge for the `opal/health` MethodChannel; the Dart
//  side is `HealthKitHealthService`. Day totals come from HKStatisticsQuery,
//  which merges the iPhone's and the Watch's overlapping steps and energy
//  instead of adding them up. Sleep goes back as raw samples: Dart groups them
//  into nights, where that logic can be unit-tested.
//  AppDelegate registers it once the Flutter engine is up.
//

import Flutter
import Foundation
import HealthKit

enum OpalHealthBridge {
  /// Name of the MethodChannel; must match `HealthKitHealthService` in Dart.
  static let channelName = "opal/health"

  // apple recommends one long-lived store per app.
  private static let store = HKHealthStore()

  private static let readTypes: Set<HKObjectType> = [
    HKQuantityType(.stepCount),
    HKQuantityType(.activeEnergyBurned),
    HKCategoryType(.sleepAnalysis),
  ]

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestAuthorization":
        Self.requestAuthorization(result: result)
      case "day":
        Self.day(call.arguments, result: result)
      case "sleepSamples":
        Self.sleepSamples(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - requestAuthorization

  // the sheet shows once; later calls return at once. iOS never reveals whether
  // read access was granted: a denial just reads as no data.
  private static func requestAuthorization(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "unavailable", message: "Health data is not available on this device", details: nil))
      return
    }
    store.requestAuthorization(toShare: [], read: readTypes) { _, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "auth_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  // MARK: - day

  /// `{startMs, endMs}` -> `{steps, activeEnergyKcal}` summed over [start, end).
  private static func day(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let bounds = range(arguments) else {
      result(argError("day"))
      return
    }
    let predicate = HKQuery.predicateForSamples(
      withStart: bounds.start, end: bounds.end, options: .strictStartDate)
    let metrics: [(key: String, type: HKQuantityTypeIdentifier, unit: HKUnit)] = [
      ("steps", .stepCount, .count()),
      ("activeEnergyKcal", .activeEnergyBurned, .kilocalorie()),
    ]

    let group = DispatchGroup()
    var totals: [String: Double] = [:]
    var failure: Error?
    for metric in metrics {
      group.enter()
      let query = HKStatisticsQuery(
        quantityType: HKQuantityType(metric.type),
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, error in
        DispatchQueue.main.async {
          if let error, !Self.isNoData(error) {
            failure = error
          } else {
            totals[metric.key] = statistics?.sumQuantity()?.doubleValue(for: metric.unit) ?? 0
          }
          group.leave()
        }
      }
      store.execute(query)
    }
    group.notify(queue: .main) {
      if let failure {
        result(FlutterError(code: "query_failed", message: failure.localizedDescription, details: nil))
      } else {
        result(totals)
      }
    }
  }

  // MARK: - sleepSamples

  /// `{startMs, endMs}` -> `[{startMs, endMs, stage, source}]` for sleep samples
  /// starting in [start, end), oldest first. `source` is the writing app's bundle
  /// ID, so Dart can keep one source per night.
  private static func sleepSamples(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let bounds = range(arguments) else {
      result(argError("sleepSamples"))
      return
    }
    let query = HKSampleQuery(
      sampleType: HKCategoryType(.sleepAnalysis),
      predicate: HKQuery.predicateForSamples(
        withStart: bounds.start, end: bounds.end, options: .strictStartDate),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    ) { _, samples, error in
      let rows: [[String: Any]] = (samples as? [HKCategorySample] ?? []).compactMap { sample in
        guard let stageName = Self.stage(sample.value) else { return nil }
        return [
          "startMs": Self.epochMs(sample.startDate),
          "endMs": Self.epochMs(sample.endDate),
          "stage": stageName,
          "source": sample.sourceRevision.source.bundleIdentifier,
        ]
      }
      DispatchQueue.main.async {
        if let error, !Self.isNoData(error) {
          result(FlutterError(code: "query_failed", message: error.localizedDescription, details: nil))
        } else {
          result(rows)
        }
      }
    }
    store.execute(query)
  }

  /// The stage names `HealthKitHealthService` understands; unknown values are dropped.
  private static func stage(_ value: Int) -> String? {
    switch HKCategoryValueSleepAnalysis(rawValue: value) {
    case .inBed: return "inBed"
    case .awake: return "awake"
    case .asleepCore: return "core"
    case .asleepDeep: return "deep"
    case .asleepREM: return "rem"
    case .asleepUnspecified: return "asleep"
    default: return nil
    }
  }

  // MARK: - Helpers

  private static func range(_ arguments: Any?) -> (start: Date, end: Date)? {
    guard
      let args = arguments as? [String: Any],
      let startMs = (args["startMs"] as? NSNumber)?.doubleValue,
      let endMs = (args["endMs"] as? NSNumber)?.doubleValue
    else { return nil }
    return (Date(timeIntervalSince1970: startMs / 1000), Date(timeIntervalSince1970: endMs / 1000))
  }

  private static func epochMs(_ date: Date) -> Int {
    Int((date.timeIntervalSince1970 * 1000).rounded())
  }

  // an empty range comes back as an error from statistics queries; it means zero.
  private static func isNoData(_ error: Error) -> Bool {
    (error as? HKError)?.code == .errorNoData
  }

  private static func argError(_ method: String) -> FlutterError {
    FlutterError(code: "bad_args", message: "OpalHealth.\(method): missing/invalid arguments", details: nil)
  }
}
