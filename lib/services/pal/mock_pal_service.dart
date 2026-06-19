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
  MockPalService({
    this.latency = const Duration(milliseconds: 600),
    int? seed,
  }) : _rng = math.Random(seed);

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

  // Qualitative only: the mock has no access to the real month aggregates
  // (review() receives just an anchor + range), so any hardcoded count here can
  // contradict the structured "By the numbers" block. Keep the prose grounded in
  // patterns, not invented numbers.
  static const _reviews = <String>[
    "This month leaned steady. You stayed under budget most days, and your "
        "routine streak held strong. The pattern is clear: mornings set the tone "
        "for the whole day.",
    "A strong month. Workouts were your anchor, and spending "
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
      return PalChatResult(reply: _logInsight(action), actions: [action]);
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
  /// Questions stay conversational; a number logs money, move keywords log a
  /// workout (minutes default to 30), and a completion phrase with no amount
  /// ("finished morning pages") logs a ritual — so money, movement and rituals
  /// all surface a confirmation card in the preview.
  LogEntryAction? _maybeAction(String message) {
    final lower = message.toLowerCase();
    final isQuestion = lower.contains('?') ||
        RegExp(r'^(why|how|what|when|who|which|suggest|should|can|does|is|am)\b')
            .hasMatch(lower);
    if (isQuestion) return null;

    final amountMatch = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(message);
    final amount =
        amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null;

    final isMove = RegExp(
            r'\b(ran|run|walk|walked|jog|gym|workout|lift|cardio|min|yoga|swim|bike|cycle)\b')
        .hasMatch(lower);
    if (isMove) {
      final minutes = amount?.round() ?? 30;
      return LogEntryAction(
        type: EntryType.move,
        durationMinutes: minutes,
        // rough kcal estimate so the card's live Movement ring visibly advances
        calories: minutes * 9,
        title: lower.contains('walk')
            ? 'Walk'
            : lower.contains('yoga')
                ? 'Yoga'
                : 'Run',
      );
    }

    if (amount != null) {
      final isCoffee = lower.contains('coffee');
      return LogEntryAction(
        type: EntryType.money,
        amount: -amount,
        title: isCoffee ? 'Coffee' : 'Expense',
        category: isCoffee ? 'Coffee' : null,
      );
    }

    // No amount: a completion phrase logs a ritual.
    final isRitual = RegExp(
            r'\b(finish|finished|did|done|complete|completed|journal|journaled|pages|read|meditat|practiced?)\b')
        .hasMatch(lower);
    if (isRitual) {
      return LogEntryAction(type: EntryType.rituals, title: _ritualTitle(lower));
    }
    return null;
  }

  String _ritualTitle(String lower) {
    if (lower.contains('pages') || lower.contains('journal')) {
      return 'Morning pages';
    }
    if (lower.contains('meditat')) return 'Meditation';
    if (lower.contains('read')) return 'Reading';
    return 'Ritual';
  }

  /// A short, non-restating note for a logged entry: the card already shows the
  /// amount and details, so the reply adds a warm observation, never a recap.
  String _logInsight(LogEntryAction a) {
    switch (a.type) {
      case EntryType.money:
        return 'Noted. You tend to log spends in the morning — steady as ever.';
      case EntryType.move:
        return 'In the bank. Your streak likes days that open with movement.';
      case EntryType.rituals:
        return 'Done. The days you keep this one tend to run a little calmer.';
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
      category: _expenseCategory(text),
    );
  }

  /// Known expense category keywords the mock parser recognizes, mapped to a
  /// display label. First match wins.
  static const _categoryKeywords = <String, String>{
    'coffee': 'Coffee',
    'breakfast': 'Dining',
    'lunch': 'Dining',
    'dinner': 'Dining',
    'restaurant': 'Dining',
    'groceries': 'Groceries',
    'grocery': 'Groceries',
    'gas': 'Transport',
    'fuel': 'Transport',
    'uber': 'Transport',
    'taxi': 'Transport',
    'rent': 'Housing',
  };

  /// Best-effort category/merchant for an expense, used to pre-fill the entry
  /// form. Tries a known category keyword first, then falls back to the noun
  /// after "on"/"at" (e.g. "on dinner", "at Tartine"). Returns null when the
  /// text gives no signal, so the form leaves the field for the user.
  String? _expenseCategory(String text) {
    final lower = text.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    // "spent X on Y" / "X at Y": take the word(s) right after on/at.
    final match = RegExp(r'\b(?:on|at)\s+([a-zA-Z][\w\-]*(?:\s+[a-zA-Z][\w\-]*)?)')
        .firstMatch(lower);
    if (match != null) return _titleCase(match.group(1)!.trim());
    return null;
  }

  @override
  Future<String> review(DateTime anchor, ReviewRange range) async {
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
  Future<WorkoutSuggestion> suggestWorkout({
    bool another = false,
    String? excludeRoutineId,
  }) async {
    await Future<void>.delayed(latency);
    if (another) _suggestionIndex = (_suggestionIndex + 1) % _suggestions.length;
    // honor the exclusion when it lands on the rejected routine, advancing
    // until a different pick (or back to the start if all match).
    if (excludeRoutineId != null &&
        _suggestions[_suggestionIndex].routineId == excludeRoutineId) {
      _suggestionIndex = (_suggestionIndex + 1) % _suggestions.length;
    }
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
  Future<PalAgenda> agenda() async {
    await Future<void>.delayed(latency);
    return const PalAgenda(
      streakDays: 11,
      proposals: [
        PalProposal(
          id: 'move-legs-friday',
          tag: 'Workout',
          colorToken: 'move',
          icon: 'figure.run',
          title: 'Move Legs day to Friday',
          body: 'Rain hits at 6pm — you log 40% shorter sessions in the wet. '
              'Friday is clear and open.',
          approveLabel: 'Reschedule',
          approveIcon: 'arrow.triangle.2.circlepath',
          doneLabel: 'Legs moved to Friday · plan updated',
        ),
        PalProposal(
          id: 'hold-rent-40',
          tag: 'Money',
          colorToken: 'money',
          icon: 'dollarsign.circle.fill',
          title: 'Set aside \$40 for rent',
          body: 'Rent (\$2,400) auto-pays Monday. Holding \$40 today clears it '
              'with \$4,192 to spare.',
          approveLabel: 'Hold \$40',
          approveIcon: 'checkmark',
          doneLabel: 'Held \$40 in your Rent envelope',
        ),
        PalProposal(
          id: 'close-out-tonight',
          tag: 'Rituals',
          colorToken: 'rituals',
          icon: 'moon.stars.fill',
          title: 'Close out tonight',
          body: '4 of 5 rituals done. A 5-min wind-down at 21:30 closes your '
              'ring — I can cue it now.',
          approveLabel: 'Start close-out',
          approveIcon: 'play.fill',
          doneLabel: 'Close-out queued for 21:30',
          action: 'close_out',
        ),
        PalProposal(
          id: 'add-wind-down-ritual',
          tag: 'Rituals',
          colorToken: 'rituals',
          icon: 'sparkles',
          title: 'Add a 2-min wind-down ritual',
          body: 'Your evening routine slips 3 of 5 nights. A short wind-down '
              'could anchor it.',
          approveLabel: 'Add ritual',
          approveIcon: 'plus',
          doneLabel: 'Added to your Evening rituals',
        ),
      ],
      autopilot: [
        PalAutopilotItem(
          id: 'rent-watch',
          colorToken: 'money',
          icon: 'house.fill',
          title: 'Rent auto-pay watch',
          subtitle: 'Alerts if balance dips before Mon',
          enabled: true,
        ),
        PalAutopilotItem(
          id: 'weekly-review-draft',
          colorToken: 'accent',
          icon: 'chart.bar.fill',
          title: 'Weekly review draft',
          subtitle: 'Ready for you Sunday morning',
          enabled: true,
        ),
        PalAutopilotItem(
          id: 'coffee-nudge',
          colorToken: 'money',
          icon: 'cup.and.saucer.fill',
          title: 'Coffee nudge at \$15 / wk',
          subtitle: "You're at \$23 — currently paused",
          enabled: false,
        ),
      ],
    );
  }

  // in-memory persistent memory for the preview: facts are user-authored (none
  // until a future chat-driven remember), patterns seed on refresh.
  final List<PalFact> _facts = [];
  List<InsightPattern> _patterns = const [];

  static const _cannedPatterns = <InsightPattern>[
    InsightPattern(colorToken: 'money', title: 'Fridays cost the most', detail: 'Dining out drives the spike.'),
    InsightPattern(colorToken: 'move', title: 'Trains in the morning', detail: 'Most sessions land before noon.'),
    InsightPattern(colorToken: 'rituals', title: 'Evenings slip when working late', detail: 'Wind-down skipped past 8pm.'),
  ];

  @override
  Future<PalMemoryDigest> memory() async {
    await Future<void>.delayed(latency);
    return PalMemoryDigest(facts: List.of(_facts), patterns: List.of(_patterns));
  }

  @override
  Future<PalMemoryDigest> refreshMemory() async {
    await Future<void>.delayed(latency);
    _patterns = _cannedPatterns;
    return PalMemoryDigest(facts: List.of(_facts), patterns: List.of(_patterns));
  }

  @override
  Future<PalMemoryDigest> deleteFact(String id) async {
    await Future<void>.delayed(latency);
    _facts.removeWhere((f) => f.id == id);
    return PalMemoryDigest(facts: List.of(_facts), patterns: List.of(_patterns));
  }

  @override
  Future<PalMemoryDigest> clearMemory() async {
    await Future<void>.delayed(latency);
    _facts.clear();
    _patterns = const [];
    return const PalMemoryDigest();
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
