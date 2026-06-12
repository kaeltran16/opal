import 'dart:math' as math;

import '../../models/models.dart';
import 'pal_service.dart';

/// On-brand canned [PalService] for Windows preview + tests.
///
/// Returns deterministic-ish strings with a small fake latency so the chat
/// typing indicator and the Start-Workout "regenerate" spinner have something
/// to animate against. No network. The real `HttpPalService` (U23) replaces
/// this via a provider override.
class MockPalService implements PalService {
  MockPalService({this.latency = const Duration(milliseconds: 600), int? seed})
      : _rng = math.Random(seed);

  /// Fake round-trip latency applied to every call.
  final Duration latency;
  final math.Random _rng;

  int _suggestionIndex = 0;

  static const _chatReplies = <String>[
    "Nice — logged it. You're tracking a calm week so far.",
    "Good question. On days you finish morning routines, you spend about 32% less on food. Want me to show those days?",
    "You've worked out 11 days in a row. That streak is doing real work on your energy.",
    "Totally doable. Want me to nudge you 30 minutes before sleep to close your last routine?",
  ];

  static const _reviews = <String>[
    "This month leaned steady. You stayed under budget 19 of 30 days, and your "
        "longest routine streak hit 12. The pattern is clear: mornings set the tone "
        "for the whole day.",
    "A strong month. Workouts were your anchor — 22 active days — and spending "
        "stayed tight on the days you trained. Keep riding that link.",
  ];

  static const _suggestions = <WorkoutSuggestion>[
    WorkoutSuggestion(
      title: 'Push Day A',
      rationale: "It's been 3 days since you trained push, and you're fresh.",
      routineId: 'seed-routine-push-a',
      estimatedMinutes: 50,
      focus: 'Push',
    ),
    WorkoutSuggestion(
      title: 'Leg Day',
      rationale: "Your lower body is rested — a good day to chase that squat PR.",
      estimatedMinutes: 55,
      focus: 'Legs',
    ),
    WorkoutSuggestion(
      title: 'Easy Cardio',
      rationale: "You've lifted hard this week. A light 30-minute zone-2 keeps the streak alive.",
      estimatedMinutes: 30,
      focus: 'Cardio',
    ),
  ];

  @override
  Future<PalChatResult> chat(List<PalMessage> history, String message) async {
    await Future<void>.delayed(latency);
    if (_looksLikeRoutine(message)) {
      return PalChatResult(
        reply: 'Built you a routine — take a look.',
        actions: [CreateRoutineAction(goal: message)],
      );
    }
    final action = _maybeAction(message);
    if (action != null) {
      return PalChatResult(reply: _ack(action), actions: [action]);
    }
    return PalChatResult(
      reply: _chatReplies[_rng.nextInt(_chatReplies.length)],
      actions: const [],
    );
  }

  bool _looksLikeRoutine(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('?')) return false;
    if (lower.contains('routine')) return true;
    final asksToBuild =
        RegExp(r'\b(build|create|make|design|generate)\b').hasMatch(lower);
    final aboutWorkout =
        RegExp(r'\b(workout|plan|push|pull|leg|legs|cardio|upper|lower)\b')
            .hasMatch(lower);
    return asksToBuild && aboutWorkout;
  }

  /// A light command heuristic so the backend-less preview can demo logging.
  /// Questions stay conversational; anything that looks like "spent/ran/log …"
  /// with a number becomes a money or move action.
  LogEntryAction? _maybeAction(String message) {
    final lower = message.toLowerCase();
    final isQuestion = lower.contains('?') ||
        RegExp(r'^(why|how|what|when|who|which|suggest|should|can|does|is|am)\b')
            .hasMatch(lower);
    final amountMatch = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(message);
    if (isQuestion || amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!);
    if (amount == null) return null;

    final isMove = RegExp(r'\b(ran|run|walk|walked|jog|gym|workout|lift|cardio|min)\b')
        .hasMatch(lower);
    if (isMove) {
      return LogEntryAction(
        type: EntryType.move,
        durationMinutes: amount.round(),
        title: lower.contains('walk') ? 'Walk' : 'Run',
      );
    }
    return LogEntryAction(
      type: EntryType.money,
      amount: -amount,
      title: lower.contains('coffee') ? 'Coffee' : 'Expense',
      category: lower.contains('coffee') ? 'Coffee' : null,
    );
  }

  String _ack(LogEntryAction a) {
    switch (a.type) {
      case EntryType.money:
        final mag = (a.amount ?? 0).abs();
        final s = mag % 1 == 0 ? mag.toStringAsFixed(0) : mag.toStringAsFixed(2);
        return 'Logged \$$s for ${a.title}.';
      case EntryType.move:
        return 'Logged ${a.durationMinutes} min of ${a.title}.';
      case EntryType.rituals:
        return 'Logged "${a.title}".';
    }
  }

  @override
  Future<ParsedEntryDraft> parse(String text) async {
    await Future<void>.delayed(latency);
    // Very light heuristic so the "Type it" demo pre-fills something sensible.
    final lower = text.toLowerCase();
    final amountMatch = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(text);
    final amount =
        amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null;

    if (lower.contains('run') ||
        lower.contains('walk') ||
        lower.contains('gym') ||
        lower.contains('workout')) {
      return ParsedEntryDraft(
        type: EntryType.move,
        title: text.trim().isEmpty ? 'Workout' : text.trim(),
        durationMinutes: amount?.round(),
      );
    }
    return ParsedEntryDraft(
      type: EntryType.money,
      title: _titleCase(text.replaceAll(RegExp(r'[\d.\$]'), '').trim()),
      amount: amount == null ? null : -amount,
      category: lower.contains('coffee') ? 'Coffee' : null,
    );
  }

  @override
  Future<String> review(DateTime month) async {
    await Future<void>.delayed(latency);
    return _reviews[_rng.nextInt(_reviews.length)];
  }

  @override
  Future<PalInsights> insights(InsightRange range) async {
    await Future<void>.delayed(latency);
    switch (range) {
      case InsightRange.day:
        return const PalInsights(
          headline: "You've worked out 11 days in a row. On days you finish "
              "morning routines, you spend less on food.",
        );
      case InsightRange.week:
        return const PalInsights(
          headline: 'Your steadiest week this month.',
          lede: 'Workouts stayed consistent, routines held together, and you '
              'came in under budget.',
          suggestion: 'Plan a grocery trip Thursday evening — your Friday '
              'splurges drop the weeks you do.',
          wins: [
            InsightWin(
                colorToken: 'move',
                title: '11-day workout streak',
                sub: 'Longest in 3 months'),
            InsightWin(
                colorToken: 'money',
                title: 'Came in under budget',
                sub: 'Spent below your weekly target'),
            InsightWin(
                colorToken: 'rituals',
                title: 'Morning pages 6/7',
                sub: 'Missed only Saturday'),
          ],
          patterns: [
            InsightPattern(
                colorToken: 'money',
                title: 'Fridays cost the most',
                detail: 'Dining out drives the spike.'),
            InsightPattern(
                colorToken: 'move',
                title: 'Routine days move more',
                detail: 'Longer workouts on days you keep your routines.'),
          ],
        );
      case InsightRange.month:
        return const PalInsights(
          patterns: [
            InsightPattern(
                colorToken: 'rituals',
                title: 'Morning rituals lower food spending',
                detail: 'On days you journal, food costs drop.'),
            InsightPattern(
                colorToken: 'money',
                title: 'Friday is your spendiest day',
                detail: 'Mostly dinner out.'),
            InsightPattern(
                colorToken: 'move',
                title: 'Movement clusters early in the week',
                detail: 'Most active days land Monday–Wednesday.'),
          ],
        );
    }
  }

  @override
  Future<WorkoutSuggestion> suggestWorkout({bool another = false}) async {
    await Future<void>.delayed(latency);
    if (another) _suggestionIndex = (_suggestionIndex + 1) % _suggestions.length;
    return _suggestions[_suggestionIndex];
  }

  @override
  Future<GeneratedRoutineDraft> generateRoutine(
    String goal,
    List<Exercise> available,
  ) async {
    await Future<void>.delayed(latency);
    final lower = goal.toLowerCase();

    // Pick a target group + tag from the goal text; fall back to a full-body mix.
    final (group, tag) = switch (lower) {
      _ when lower.contains('push') => ('Push', RoutineTag.upper),
      _ when lower.contains('pull') || lower.contains('back') =>
        ('Pull', RoutineTag.upper),
      _ when lower.contains('leg') ||
          lower.contains('glute') ||
          lower.contains('ham') =>
        ('Legs', RoutineTag.lower),
      _ when lower.contains('cardio') ||
          lower.contains('hiit') ||
          lower.contains('run') =>
        ('Cardio', RoutineTag.cardio),
      _ => ('', RoutineTag.full),
    };

    final pool = group.isEmpty
        ? available.where((e) => e.group != 'Cardio').toList()
        : available.where((e) => e.group == group).toList();
    final picks = (pool.isEmpty ? available : pool).take(4).toList();

    final isCardio = tag == RoutineTag.cardio;
    final exercises = picks.map((e) {
      if (isCardio) {
        return GeneratedExerciseDraft(
          exerciseId: e.id,
          sets: const [GeneratedSetDraft(durationMinutes: 20)],
        );
      }
      final weight = e.pr?.weightKg == null ? null : (e.pr!.weightKg * 0.8);
      return GeneratedExerciseDraft(
        exerciseId: e.id,
        sets: List.generate(
          3,
          (_) => GeneratedSetDraft(reps: 8, weightKg: weight),
        ),
      );
    }).toList();

    final name = switch (tag) {
      RoutineTag.upper when group == 'Push' => 'Push Builder',
      RoutineTag.upper => 'Pull Builder',
      RoutineTag.lower => 'Leg Builder',
      RoutineTag.cardio => 'Cardio Burst',
      _ => 'Full-Body Flow',
    };

    return GeneratedRoutineDraft(
      name: name,
      tag: tag,
      estimatedMinutes: isCardio ? 25 : 45,
      rationale: 'Built around your goal — compound work first, '
          'then accessories, ordered to keep fresh muscles fresh.',
      exercises: exercises,
    );
  }

  @override
  Future<String> postWorkoutNote(Workout workout) async {
    await Future<void>.delayed(latency);
    final prs = workout.prCount;
    if (prs > 0) {
      return "Big day — $prs new PR${prs == 1 ? '' : 's'}. Your bench is "
          "trending up; the consistency is paying off.";
    }
    return "Solid session. ${workout.completedSetCount} sets in the bank — "
        "right on plan.";
  }

  String _titleCase(String s) {
    if (s.isEmpty) return 'Expense';
    return s
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
