import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/providers.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';

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
            _SearchPill(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: Spacing.md),
            _FilterChips(
              active: _group,
              onSelect: (g) => setState(() => _group = g),
            ),
            const SizedBox(height: Spacing.lg),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: Text('…',
                      style: AppType.body.copyWith(color: c.ink3)),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Text("Couldn't load exercises.\n$e",
                        textAlign: TextAlign.center,
                        style: AppType.subhead
                            .copyWith(color: c.ink3, letterSpacing: -0.24)),
                  ),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return _EmptyState(query: _query);
                  }
                  final sections = _byGroup(filtered);
                  return ListView(
                    padding: const EdgeInsets.only(
                        top: Spacing.xs, bottom: Spacing.xxxl),
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

/// iOS search field rendered as a fill-bg pill with a leading glass icon.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, 0),
      child: Container(
        height: 36, // fixed search-field height
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            AppIcon('magnifyingglass', size: 16, color: c.ink3),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: c.accent,
                style: AppType.body.copyWith(color: c.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search exercises',
                  hintStyle: AppType.body.copyWith(color: c.ink3),
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
      height: 32, // fixed chip-row height
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: Spacing.sm),
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
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.ink : c.fill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: AppType.subhead.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? c.bg : c.ink2,
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }
}

/// A single catalog row: group-tinted icon tile + name + "group · equipment"
/// meta + PR. Built inline (not via [ListRow]) so the icon tile can carry a
/// group-tinted background with a matching coloured glyph — design
/// workout-screens2.jsx L218-225: Cardio = solid move + white glyph; Push =
/// move-tint; Pull = rituals-tint; Legs = money-tint; else accent-tint.
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

  /// Group-coded tile background + glyph color. Cardio fills solid (white glyph);
  /// every other group uses the low-alpha tint with a full-color glyph.
  ({Color bg, Color icon}) _tile(AppColors c) => switch (exercise.group) {
        'Cardio' => (bg: c.move, icon: c.onAccent),
        'Push' => (bg: c.moveTint, icon: c.move),
        'Pull' => (bg: c.ritualsTint, icon: c.rituals),
        'Legs' => (bg: c.moneyTint, icon: c.money),
        _ => (bg: c.accentTint, icon: c.accent),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pr = _prText;
    final tile = _tile(c);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40), // row min height
            child: Row(
              children: [
                Container(
                  width: 36, // fixed icon tile
                  height: 36,
                  decoration: BoxDecoration(
                    color: tile.bg,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(exercise.icon, size: 17, color: tile.icon),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.subhead.copyWith(
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                            letterSpacing: -0.24),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 1), // hairline gap
                        child: Text(
                          _meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption
                              .copyWith(color: c.ink3, letterSpacing: -0.08),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pr != null)
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.sm),
                    child: Text(
                      pr,
                      style: AppType.subhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.ink2,
                          letterSpacing: -0.1,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!last)
          Positioned(
            left: 61,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: c.hair),
          ),
      ],
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
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Text(
          query.trim().isEmpty
              ? 'No exercises in this group.'
              : 'No exercises match "$query".',
          textAlign: TextAlign.center,
          style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24),
        ),
      ),
    );
  }
}
