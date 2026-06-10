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
    required this.suggest,
    required this.postWorkout,
    required this.resolveRoutineTitle,
  });
  final Future<Map<String, Object?>> Function() chat;
  final Future<Map<String, Object?>> Function(DateTime month) review;
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
  Future<String> chat(List<PalMessage> history, String message) async {
    final body = {
      'history': history
          .map((m) => {'role': m.role == PalRole.user ? 'user' : 'assistant', 'text': m.text})
          .toList(),
      'message': message,
      'context': await context.chat(),
    };
    final json = await _post('/v1/chat', body);
    return json['reply'] as String;
  }

  @override
  Future<ParsedEntryDraft> parse(String text) async {
    final json = await _post('/v1/parse', {'text': text});
    final type = _entryTypeFromWire(json['type'] as String);
    final rawAmount = (json['amount'] as num?)?.toDouble();
    // ParsedEntryDraft convention: negative = expense. Server returns a magnitude.
    final amount = (type == EntryType.money && rawAmount != null && rawAmount > 0)
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
  Future<String> review(DateTime month) async {
    final json = await _post('/v1/review', {'context': await context.review(month)});
    return json['text'] as String;
  }

  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false}) async {
    final json = await _post('/v1/suggest-workout', {
      'another': another,
      'context': await context.suggest(another),
    });
    final routineId = json['routineId'] as String?;
    final title = (routineId == null ? null : await context.resolveRoutineTitle(routineId)) ?? 'Workout';
    return WorkoutSuggestion(
      title: title,
      rationale: json['reason'] as String,
      routineId: routineId,
    );
  }

  @override
  Future<String> postWorkoutNote(Workout workout) async {
    final json = await _post('/v1/post-workout-note', {
      'context': await context.postWorkout(workout),
    });
    return json['note'] as String;
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
