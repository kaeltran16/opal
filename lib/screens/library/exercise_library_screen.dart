import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';

/// Screen 11 — Exercise Library.
///
/// Search field (fill-bg pill) + horizontal group filter chips
/// (All/Push/Pull/Legs/Core/Cardio) + muscle-grouped [InsetSection]s. Each row
/// shows the exercise icon, name, a "group · equipment" meta subtitle, and the
/// PR value (when present). Reads the catalog via [exercisesProvider] (a stream
/// over [RoutineRepository.watchExercises]).
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

/// The filter groups, in display order. `null` (= All) is rendered first.
const List<String> _groups = ['Push', 'Pull', 'Legs', 'Core', 'Cardio'];

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Active group filter; null = All.
  String? _group;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Applies the active group filter + case-insensitive name search.
  List<Exercise> _filter(List<Exercise> all) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      if (_group != null && e.group != _group) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.muscle.toLowerCase().contains(q);
    }).toList();
  }

  /// Groups the filtered exercises by muscle, preserving the catalog's
  /// (name-ascending) order within each muscle and ordering muscles by first
  /// appearance so sections are stable.
  List<MapEntry<String, List<Exercise>>> _byMuscle(List<Exercise> list) {
    final map = <String, List<Exercise>>{};
    for (final e in list) {
      (map[e.muscle] ??= <Exercise>[]).add(e);
    }
    return map.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(exercisesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            _SearchPill(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            _FilterChips(
              active: _group,
              onSelect: (g) => setState(() => _group = g),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: Text('…',
                      style: AppFonts.sf(
                          size: 17, color: c.ink3, letterSpacing: -0.43)),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text("Couldn't load exercises.\n$e",
                        textAlign: TextAlign.center,
                        style: AppFonts.sf(
                            size: 15, color: c.ink3, letterSpacing: -0.24)),
                  ),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return _EmptyState(query: _query);
                  }
                  final sections = _byMuscle(filtered);
                  return ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 32),
                    children: [
                      for (final section in sections)
                        InsetSection(
                          header: section.key,
                          children: [
                            for (var i = 0; i < section.value.length; i++)
                              _ExerciseRow(
                                exercise: section.value[i],
                                last: i == section.value.length - 1,
                              ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title row with a back affordance (this is a root-level focus route).
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppIcon('chevron.left', size: 20, color: c.accent),
            ),
          ),
          const SizedBox(width: 4),
          Text('Exercise Library',
              style: AppFonts.sf(
                  size: 22,
                  weight: FontWeight.w700,
                  color: c.ink,
                  letterSpacing: 0.35)),
        ],
      ),
    );
  }
}

/// iOS search field rendered as a fill-bg pill with a leading glass icon.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AppIcon('magnifyingglass', size: 16, color: c.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: c.accent,
                style: AppFonts.sf(
                    size: 17, color: c.ink, letterSpacing: -0.43),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search exercises',
                  hintStyle: AppFonts.sf(
                      size: 17, color: c.ink3, letterSpacing: -0.43),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal group filter chips. The active chip is inverted (accent fill,
/// surface-coloured label); inactive chips use the fill token.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.active, required this.onSelect});

  /// Active group; null = All.
  final String? active;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = <(String label, String? value)>[
      ('All', null),
      for (final g in _groups) (g, g),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, value) = options[i];
          return _Chip(
            label: label,
            selected: value == active,
            onTap: () => onSelect(value),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppFonts.sf(
            size: 14,
            weight: FontWeight.w600,
            color: selected ? c.bg : c.ink2,
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }
}

/// A single catalog row: tinted icon + name + "group · equipment" meta + PR.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.last});

  final Exercise exercise;
  final bool last;

  String get _meta {
    final eq = exercise.equipment;
    return eq == null || eq.isEmpty
        ? exercise.group
        : '${exercise.group} · $eq';
  }

  String? get _prText {
    final pr = exercise.pr;
    if (pr == null) return null;
    // Bodyweight / hold lifts (0 kg) show reps only; others show kg × reps.
    if (pr.weightKg == 0) return '${pr.reps}';
    final w = pr.weightKg == pr.weightKg.roundToDouble()
        ? pr.weightKg.toStringAsFixed(0)
        : pr.weightKg.toString();
    return '$w kg';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pr = _prText;
    return ListRow(
      icon: exercise.icon,
      iconBg: c.move,
      title: exercise.name,
      subtitle: _meta,
      value: pr,
      valueColor: c.ink2,
      chevron: true,
      last: last,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          query.trim().isEmpty
              ? 'No exercises in this group.'
              : 'No exercises match "$query".',
          textAlign: TextAlign.center,
          style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24),
        ),
      ),
    );
  }
}
