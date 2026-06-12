import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'pal_service.dart';

/// Raised when the proxy is unreachable or returns a non-2xx (after one retry).
class PalException implements Exception {
  const PalException(this.message);
  final String message;
  @override
  String toString() => 'PalException: $message';
}

/// Token seam: yields the current device token and can clear it (after a 401).
class TokenProvider {
  const TokenProvider({required this.token, required this.clear});
  final Future<String> Function() token;
  final Future<void> Function() clear;
}

/// Context seam: yields the wire-context maps and resolves a routine title.
/// The real impl reads repositories; tests pass fixed maps.
class PalContextSource {
  const PalContextSource({
    required this.chat,
    required this.review,
    required this.insights,
    required this.suggest,
    required this.postWorkout,
    required this.resolveRoutineTitle,
  });
  final Future<Map<String, Object?>> Function() chat;
  final Future<Map<String, Object?>> Function(DateTime anchor, ReviewRange range) review;
  final Future<Map<String, Object?>> Function(InsightRange range) insights;
  final Future<Map<String, Object?>> Function(bool another) suggest;
  final Future<Map<String, Object?>> Function(Workout workout) postWorkout;
  final Future<String?> Function(String routineId) resolveRoutineTitle;
}

/// Real [PalService]: posts structured context to the droplet proxy and maps
/// responses into the existing DTOs. Interface-compatible with [MockPalService].
class HttpPalService implements PalService {
  HttpPalService({
    required String baseUrl,
    required http.Client httpClient,
    required this.tokens,
    required this.context,
    this.timeout = const Duration(seconds: 30),
  })  : _base = Uri.parse(baseUrl),
        _http = httpClient;

  final Uri _base;
  final http.Client _http;
  final TokenProvider tokens;
  final PalContextSource context;
  final Duration timeout;

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    Future<http.Response> send() async {
      final token = await tokens.token();
      return _http
          .post(
            _base.replace(path: path),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        await tokens.clear();
        res = await send();
      }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }
    // Decode UTF-8 explicitly: Pal replies use em-dashes and other non-latin1 glyphs.
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    final body = {
      'history': history
          .map((m) => {'role': m.role == PalRole.user ? 'user' : 'assistant', 'text': m.text})
          .toList(),
      'message': message,
      'context': await context.chat(),
    };
    final json = await _post('/v1/chat', body);
    final actions = ((json['actions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_actionFromWire)
        .whereType<PalAction>()
        .toList();
    return PalChatResult(reply: json['reply'] as String? ?? '', actions: actions);
  }

  /// Decodes one wire action by its `kind`. Returns null for unknown kinds or
  /// malformed payloads so a newer server can't break an older client.
  static PalAction? _actionFromWire(Map<String, dynamic> a) {
    final num? amount = a['amount'] as num?;
    final int? minutes = (a['durationMinutes'] as num?)?.round();
    final String? title = a['title'] as String?;
    final String? category = a['category'] as String?;
    final String? note = a['note'] as String?;
    switch (a['kind']) {
      case 'log_expense':
        if (amount == null) return null;
        return LogEntryAction(
          type: EntryType.money, amount: -amount.toDouble().abs(),
          title: title ?? category ?? 'Expense', category: category, note: note,
        );
      case 'log_income':
        if (amount == null) return null;
        return LogEntryAction(
          type: EntryType.money, amount: amount.toDouble().abs(),
          title: title ?? 'Income', note: note,
        );
      case 'log_movement':
        if (minutes == null) return null;
        return LogEntryAction(
          type: EntryType.move, durationMinutes: minutes,
          title: title ?? 'Workout', note: note,
        );
      case 'log_ritual':
        if (title == null) return null;
        return LogEntryAction(type: EntryType.rituals, title: title, note: note);
      case 'set_daily_budget':
        final v = a['dailyBudget'] as num?;
        return v == null ? null : SetGoalAction(target: GoalTarget.dailyBudget, value: v);
      case 'set_move_goal':
        final v = a['dailyMoveMinutes'] as num?;
        return v == null ? null : SetGoalAction(target: GoalTarget.dailyMoveMinutes, value: v);
      case 'set_ritual_goal':
        final v = a['dailyRitualTarget'] as num?;
        return v == null ? null : SetGoalAction(target: GoalTarget.dailyRitualTarget, value: v);
      case 'create_routine':
        final goal = a['goal'] as String?;
        return goal == null ? null : CreateRoutineAction(goal: goal, name: a['name'] as String?);
      default:
        return null;
    }
  }

  @override
  Future<ParsedEntryDraft> parse(String text) async {
    final json = await _post('/v1/parse', {'text': text});
    final type = _entryTypeFromWire(json['type'] as String? ?? 'money');
    final rawAmount = (json['amount'] as num?)?.toDouble();
    // ParsedEntryDraft convention: negative = expense. Server returns a magnitude
    // plus a direction; absent/null direction is treated as expense (older server).
    final isIncome = json['direction'] == 'income';
    final amount = (type == EntryType.money && !isIncome && rawAmount != null && rawAmount > 0)
        ? -rawAmount
        : rawAmount;
    return ParsedEntryDraft(
      type: type,
      title: json['title'] as String?,
      amount: amount,
      category: json['category'] as String?,
      durationMinutes: (json['duration'] as num?)?.round(),
      note: json['note'] as String?,
    );
  }

  @override
  Future<String> review(DateTime anchor, ReviewRange range) async {
    final json = await _post('/v1/review', {'context': await context.review(anchor, range)});
    try {
      return json['text'] as String? ?? '';
    } catch (e) {
      throw PalException('malformed review response: $e');
    }
  }

  @override
  Future<PalInsights> insights(InsightRange range) async {
    final json = await _post('/v1/insights', {'context': await context.insights(range)});
    List<T> mapList<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((json[key] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(f)
            .toList();
    return PalInsights(
      headline: json['headline'] as String?,
      lede: json['lede'] as String?,
      suggestion: json['suggestion'] as String?,
      wins: mapList(
        'wins',
        (w) => InsightWin(
          colorToken: _colorToken(w['colorToken']),
          title: w['title'] as String? ?? '',
          sub: w['sub'] as String? ?? '',
        ),
      ),
      patterns: mapList(
        'patterns',
        (p) => InsightPattern(
          colorToken: _colorToken(p['colorToken']),
          title: p['title'] as String? ?? '',
          detail: p['detail'] as String? ?? '',
        ),
      ),
    );
  }

  /// Clamps a wire colorToken to the three known accents, defaulting unknown
  /// values to 'rituals' so a stray token never crashes the row.
  String _colorToken(Object? raw) => switch (raw) {
        'money' || 'move' || 'rituals' => raw! as String,
        _ => 'rituals',
      };

  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false}) async {
    final json = await _post('/v1/suggest-workout', {
      'another': another,
      'context': await context.suggest(another),
    });
    final String? routineId;
    final String rationale;
    try {
      routineId = json['routineId'] as String?;
      rationale = json['reason'] as String? ?? '';
    } catch (e) {
      throw PalException('malformed suggest-workout response: $e');
    }
    final title = (routineId == null ? null : await context.resolveRoutineTitle(routineId)) ?? 'Workout';
    return WorkoutSuggestion(
      title: title,
      rationale: rationale,
      routineId: routineId,
    );
  }

  @override
  Future<String> postWorkoutNote(Workout workout) async {
    final json = await _post('/v1/post-workout-note', {
      'context': await context.postWorkout(workout),
    });
    try {
      return json['note'] as String? ?? '';
    } catch (e) {
      throw PalException('malformed post-workout-note response: $e');
    }
  }

  @override
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  ) async {
    final json = await _post('/v1/routine', {
      'goal': goal,
      'exercises': available
          .map((e) => {
                'id': e.id,
                'name': e.name,
                'group': e.group,
                'equipment': e.equipment,
              })
          .toList(),
    });
    final exercises = ((json['exercises'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((ex) => GeneratedExerciseDraft(
              exerciseId: ex['exerciseId'] as String,
              sets: ((ex['sets'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>()
                  .map((s) => GeneratedSetDraft(
                        reps: (s['reps'] as num?)?.round(),
                        weightKg: (s['weight'] as num?)?.toDouble(),
                        durationMinutes: (s['duration'] as num?)?.round(),
                      ))
                  .toList(),
            ))
        .toList();
    return GeneratedRoutineDraft(
      name: json['name'] as String? ?? 'Routine',
      tag: RoutineTag.fromWire(
        (json['tag'] as String? ?? 'custom').toLowerCase(),
      ),
      estimatedMinutes: (json['estMin'] as num?)?.round(),
      rationale: json['rationale'] as String?,
      exercises: exercises,
    );
  }

  EntryType _entryTypeFromWire(String token) => switch (token) {
        'money' => EntryType.money,
        'move' => EntryType.move,
        'rituals' => EntryType.rituals,
        _ => EntryType.money,
      };
}
