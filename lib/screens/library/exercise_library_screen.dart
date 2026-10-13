import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/controls.dart';
import '../../widgets/exercise_row.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

const double _chipRow = 44;
const String _cardio = 'Cardio';

/// Screen 11 — Exercise Library.
///
/// A search pill, group filter chips (All/Push/Pull/Legs/Core/Cardio) and
/// group-headed [InsetSection]s of [ExerciseRow]s: name, `muscle · equipment`
/// and the PR when present. Reads the catalog via [exercisesProvider] (a
/// stream over [RoutineRepository.watchExercises]).
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

/// The filter groups, in display order. `null` (= All) is rendered first.
const List<String> _groups = ['Push', 'Pull', 'Legs', 'Core', _cardio];

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

  /// Groups the filtered exercises by group (Push/Pull/Legs/Core/Cardio),
  /// preserving the catalog's order within each group and ordering groups by
  /// first appearance so sections are stable.
  List<MapEntry<String, List<Exercise>>> _byGroup(List<Exercise> list) {
    final map = <String, List<Exercise>>{};
    for (final e in list) {
      (map[e.group] ??= <Exercise>[]).add(e);
    }
    return map.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(exercisesProvider);
    final count = async.asData?.value.length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTitleNavBar(
              title: 'Exercises',
              subtitle: count != null ? '$count in library' : null,
              leading: NavAction(
                icon: 'chevron.left',
                onTap: () => context.pop(),
                semanticLabel: 'Back',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, 0),
              child: SearchPill(
                controller: _searchController,
                placeholder: 'Search exercises',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            _FilterChips(
              active: _group,
              onSelect: (g) => setState(() => _group = g),
            ),
            const SizedBox(height: Spacing.lg),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: Text('…', style: AppType.body.copyWith(color: c.ink3)),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Text("Couldn't load exercises.\n$e",
                        textAlign: TextAlign.center,
                        style: AppType.subhead.copyWith(color: c.ink3)),
                  ),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return _EmptyState(query: _query);
                  }
                  final sections = _byGroup(filtered);
                  return ListView(
                    padding: const EdgeInsets.only(bottom: Spacing.xxxl),
                    children: [
                      for (final section in sections)
                        InsetSection(
                          header: section.key,
                          children: [
                            for (final (i, exercise) in section.value.indexed)
                              _LibraryRow(exercise: exercise, first: i == 0),
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

/// Horizontal group filter chips.
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
      height: _chipRow,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, i) {
          final (label, value) = options[i];
          return AppChip(
            label: label,
            selected: value == active,
            onTap: () => onSelect(value),
          );
        },
      ),
    );
  }
}

/// One catalog exercise: a line icon, name, `muscle · equipment` and the PR.
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.exercise, required this.first});

  final Exercise exercise;
  final bool first;

  String get _detail {
    final eq = exercise.equipment;
    return eq == null || eq.isEmpty ? exercise.muscle : '${exercise.muscle} · $eq';
  }

  String? get _pr {
    final pr = exercise.pr;
    if (pr == null) return null;
    // bodyweight and hold lifts (0 kg) show reps only.
    if (pr.weightKg == 0) return '${pr.reps}';
    return '${formatWeight(pr.weightKg)} kg';
  }

  @override
  Widget build(BuildContext context) {
    return ExerciseRow(
      name: exercise.name,
      detail: _detail,
      icon: exercise.group == _cardio ? 'figure.run' : 'dumbbell',
      value: _pr,
      first: first,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Text(
        query.trim().isEmpty
            ? 'No exercises in this group.'
            : 'No exercises match "$query".',
        style: AppType.subhead.copyWith(color: c.ink3),
      ),
    );
  }
}
