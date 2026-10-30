import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart' hide Provider;
import '../services/services.dart';
import '../util/format.dart';
import 'pal_action_executor.dart';
import 'providers.dart';
import 'today_controller.dart';

const _unreachable = "Pal couldn't reach the server";
const _failed = "Pal couldn't answer that just now";
const _notSaved = "Pal couldn't save that";
const _nothingSaid = 'Nothing to log';
const _cantUndo = "That can't be undone";
const _logged = 'Logged';

// undo token keys, one map per applied action
const _entryKey = 'entry';
const _mealKey = 'meal';
const _routineKey = 'routine';
const _goalKey = 'goal';
const _goalValueKey = 'value';

/// What the Watch logs through: a message goes through [PalService.chat] and
/// its actions are applied the way the composer applies them, then the reply
/// is formatted for the Watch's screens. Undo reverses the turn from the token
/// the reply carried, which holds everything needed: the engine that logged it
/// may be gone by the time Undo arrives.
///
/// A plain provider rather than codegen: it only hands [applyPalActions] a ref.
final watchLogProvider = Provider<WatchLog>((ref) => WatchLog(ref));

class WatchLog {
  WatchLog(this._ref);

  final Ref _ref;

  /// Longer than the composer's 12 s: nobody watches a spinner on the phone,
  /// but the relay answers the Watch itself after 25 s and iOS gives a woken
  /// app about 30 s, so the chat must end well before either.
  static const chatTimeout = Duration(seconds: 15);

  Future<WatchReply> log(String text) async {
    final message = text.trim();
    if (message.isEmpty) return {WatchKeys.error: _nothingSaid};

    final PalChatResult result;
    try {
      result = await _ref.read(palServiceProvider).chat(const [], message).timeout(chatTimeout);
    } on PalException catch (e) {
      return {WatchKeys.error: e.statusCode == null ? _unreachable : _failed};
    } on TimeoutException {
      return {WatchKeys.error: _failed};
    }

    final List<AppliedAction> applied;
    try {
      applied = await applyPalActions(_ref, result.actions);
    } catch (e) {
      // applyPalActions has already rolled back what it applied
      debugPrint('WatchLog: applying Pal actions failed: $e');
      return {WatchKeys.error: _notSaved};
    }

    return {
      WatchKeys.type: WatchKeys.result,
      ...switch (result.actions) {
        [final LogEntryAction a] => await _entry(a),
        [final LogMealAction a] => _meal(a),
        _ => {WatchKeys.reply: result.reply},
      },
      if (applied.isNotEmpty) WatchKeys.undo: [for (final a in applied) _encode(a)],
    };
  }

  Future<WatchReply> undo(Object? token) async {
    final applied = _decode(token);
    if (applied == null) return {WatchKeys.error: _cantUndo};
    // newest first, as applyPalActions rolls back, so goal values unwind in order
    for (final a in applied.reversed) {
      await reversePalAction(_ref, a);
    }
    return {WatchKeys.type: WatchKeys.undone};
  }

  Future<WatchReply> _entry(LogEntryAction a) async => {
        WatchKeys.title: _logged,
        WatchKeys.item: a.title,
        ...switch (a) {
          LogEntryAction(type: EntryType.money, :final amount?) => await _money(amount),
          LogEntryAction(type: EntryType.move, :final durationMinutes?) => {
              WatchKeys.amount: '$durationMinutes',
              WatchKeys.unit: 'min',
            },
          LogEntryAction(type: EntryType.move, :final calories?) => {
              WatchKeys.amount: '$calories',
              WatchKeys.unit: 'kcal',
            },
          _ => const <String, Object?>{},
        },
      };

  /// The amount, then today's spending against the daily budget.
  Future<WatchReply> _money(double amount) async {
    final currency = _ref.read(settingsRepositoryProvider).currency;
    final today = TodayState(
      entries: await _ref.read(entryRepositoryProvider).getToday(),
      goals: await _ref.read(goalsRepositoryProvider).get(),
    );
    final spent = formatCurrency(today.moneySpent, currency);
    final budget = today.goals.dailyBudget;
    return {
      WatchKeys.amount: formatCurrency(amount, currency, withSign: true),
      if (budget > 0) ...{
        WatchKeys.detail: 'Spending today',
        WatchKeys.value: '$spent of ${formatCurrency(budget, currency)}',
        WatchKeys.fraction: today.moneyRing.clamp(0.0, 1.0),
      } else ...{
        WatchKeys.detail: 'Spent today',
        WatchKeys.value: spent,
      },
    };
  }

  WatchReply _meal(LogMealAction a) => {
        WatchKeys.title: '$_logged · ${mealSlotFor(a)}',
        WatchKeys.item: mealName(a.name),
        WatchKeys.amount: '${a.cal.lo}–${a.cal.hi}',
        WatchKeys.unit: 'kcal',
        WatchKeys.detail: a.confidence.label,
        WatchKeys.bars: a.confidence.bars,
      };
}

Map<String, Object> _encode(AppliedAction a) => {
      if (a.entryId != null) _entryKey: a.entryId!,
      if (a.mealId != null) _mealKey: a.mealId!,
      if (a.routineId != null) _routineKey: a.routineId!,
      if (a.priorGoal != null) ...{
        _goalKey: a.priorGoal!.target.name,
        _goalValueKey: a.priorGoal!.value,
      },
    };

/// The applied actions in [token], or null when it isn't one [_encode] made.
List<AppliedAction>? _decode(Object? token) {
  if (token is! List || token.isEmpty) return null;
  final applied = <AppliedAction>[];
  for (final item in token) {
    if (item is! Map) return null;
    String? id(String key) => item[key] is String ? item[key] as String : null;
    final target = GoalTarget.values.asNameMap()[item[_goalKey]];
    final value = item[_goalValueKey];
    final a = AppliedAction(
      entryId: id(_entryKey),
      mealId: id(_mealKey),
      routineId: id(_routineKey),
      priorGoal: target != null && value is num ? SetGoalAction(target: target, value: value) : null,
    );
    if (a.entryId == null && a.mealId == null && a.routineId == null && a.priorGoal == null) {
      return null;
    }
    applied.add(a);
  }
  return applied;
}
