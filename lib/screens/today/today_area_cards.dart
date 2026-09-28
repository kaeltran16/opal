import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/mood_controller.dart';
import '../../controllers/nutrition_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/rituals_controller.dart';
import '../../controllers/sleep_controller.dart';
import '../../controllers/today_controller.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../util/mood_scale.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../mood/mood_logger_sheet.dart';
import '../sleep/widgets/sleep_widgets.dart';
import 'today_logic.dart';

const double _minTap = 44;
const double _areaTile = 30;
const double _progressSegment = 18;
const double _progressHeight = 6;
const double _faceHeight = 52;
final _figure = AppFonts.sfr(size: 32, weight: FontWeight.w800, letterSpacing: -0.5, height: 36 / 32);

/// A top-level Today card: solid surface, never glass.
BoxDecoration todayCard(AppColors c) => BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
    );

/// The card for [area], each watching the same provider as its detail screen.
class TodayAreaCard extends StatelessWidget {
  const TodayAreaCard({super.key, required this.area, required this.today});

  final TodayArea area;
  final TodayState today;

  @override
  Widget build(BuildContext context) => switch (area) {
        TodayArea.routines => _RoutinesCard(today: today),
        TodayArea.sleep => const _SleepCard(),
        TodayArea.mood => const _MoodCard(),
        TodayArea.money => _MoneyCard(today: today),
        TodayArea.move => _MoveCard(today: today),
        TodayArea.nutrition => const _NutritionCard(),
      };
}

/// The shared card shell: an area header that opens the area, then [body].
/// When [tapBody] is set the whole body opens the area too; cards with their
/// own buttons (Routines, Mood) leave it off.
class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.label,
    required this.icon,
    required this.tint,
    required this.ink,
    required this.onOpen,
    required this.body,
    this.trailing,
    this.tapBody = true,
  });

  final String label, icon;
  final Color tint, ink;
  final VoidCallback onOpen;
  final List<Widget> body;
  final Widget? trailing;
  final bool tapBody;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in body) ...[const SizedBox(height: Spacing.md), w],
      ],
    );
    return Semantics(
      container: true,
      label: '$label card',
      child: Container(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, Spacing.lg),
        decoration: todayCard(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PressScale(
              onTap: onOpen,
              semanticLabel: 'Open $label',
              pressedScale: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minTap),
                child: Row(
                  children: [
                    Container(
                      width: _areaTile,
                      height: _areaTile,
                      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: AppIcon(icon, size: 15, color: ink),
                    ),
                    const SizedBox(width: Spacing.sm + Spacing.xxs),
                    Text(label,
                        style: AppType.subhead.copyWith(
                            fontWeight: FontWeight.w600, color: ink, letterSpacing: 0)),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
              ),
            ),
            // the header button already carries the a11y action, so the body
            // tap is pointer-only.
            if (tapBody)
              GestureDetector(behavior: HitTestBehavior.opaque, onTap: onOpen, child: content)
            else
              content,
          ],
        ),
      ),
    );
  }
}

/// A big rounded figure with its unit line beside it.
class _Figure extends StatelessWidget {
  const _Figure(this.value, this.unit);

  final String value, unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: Spacing.sm,
      children: [
        Text(value, style: _figure.copyWith(color: c.ink)),
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.xs),
          child: Text(unit, style: AppType.subhead.copyWith(color: c.ink3)),
        ),
      ],
    );
  }
}

Widget _quiet(AppColors c, String text) =>
    Text(text, style: AppType.subhead.copyWith(color: c.ink3));

class _RoutinesCard extends ConsumerWidget {
  const _RoutinesCard({required this.today});

  final TodayState today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final next = ref.watch(ritualsControllerProvider).value?.upNext;
    final done = today.ritualsDone, total = today.ritualsTarget;
    return _AreaCard(
      label: 'Routines',
      icon: 'sparkles',
      tint: c.ritualsTint,
      ink: c.ritualsInk,
      onOpen: () => context.pushNamed(AppRoute.ritualsDetail.name),
      tapBody: false,
      trailing: total == 0
          ? null
          : Semantics(
              label: '$done of $total done',
              child: Row(
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.xs),
                    Container(
                      width: _progressSegment,
                      height: _progressHeight,
                      decoration: BoxDecoration(
                        color: i < done ? c.rituals : c.ritualsTint,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      body: [
        if (next != null)
          _StartRow(
            title: next.name,
            detail: '${next.blurb} · ${next.time}',
            onStart: () => context.pushNamed(AppRoute.routinePlayer.name,
                pathParameters: {'routineId': next.id}),
          )
        else if (total == 0)
          _quiet(c, 'No routines set up yet.')
        // gated on the area's completion rule, not a null upNext, so a still
        // loading rituals stream doesn't offer the close-out early. with every
        // routine done it is the day's last step, and Today is its only manual
        // entry point.
        else if (today.ritualsRemaining == 0)
          _StartRow(
            title: 'Evening close-out',
            detail: 'Reflect · about 5 min, before bed',
            onStart: () => context.pushNamed(AppRoute.eveningCloseOut.name),
          ),
      ],
    );
  }
}

/// A title and detail line with a 44 pt `Start` pill beside them.
class _StartRow extends StatelessWidget {
  const _StartRow({required this.title, required this.detail, required this.onStart});

  final String title, detail;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.headline.copyWith(color: c.ink, letterSpacing: -0.2)),
              const SizedBox(height: Spacing.xxs),
              Text(detail, style: AppType.subhead.copyWith(color: c.ink2)),
            ],
          ),
        ),
        const SizedBox(width: Spacing.md),
        PressScale(
          onTap: onStart,
          semanticLabel: 'Start $title',
          child: Container(
            height: _minTap,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            decoration: BoxDecoration(
              color: c.accentTint,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            alignment: Alignment.center,
            child: Text('Start',
                style: AppType.subhead.copyWith(fontWeight: FontWeight.w600, color: c.accentInk)),
          ),
        ),
      ],
    );
  }
}

class _SleepCard extends ConsumerWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final night = ref.watch(sleepControllerProvider).value?.lastNight;
    return _AreaCard(
      label: 'Sleep',
      icon: 'moon.stars.fill',
      tint: c.sleepTint,
      ink: c.sleepInk,
      onOpen: () => context.pushNamed(AppRoute.todaySleep.name),
      trailing: night == null
          ? null
          : Text('${night.bedtime} – ${night.wake}',
              style: AppType.footnote.copyWith(
                  color: c.ink3, fontFeatures: const [FontFeature.tabularFigures()])),
      body: night == null
          ? [_quiet(c, 'No sleep synced yet.')]
          : [
              _Figure(hm(night.asleepMinutes),
                  'asleep · ${night.wakes} ${night.wakes == 1 ? 'wake-up' : 'wake-ups'}'),
              StageSplitBar(
                deepMinutes: night.deepMinutes,
                remMinutes: night.remMinutes,
                coreMinutes: night.coreMinutes,
                awakeMinutes: night.awakeMinutes,
                light: false,
              ),
            ],
    );
  }
}

class _MoodCard extends ConsumerWidget {
  const _MoodCard();

  static const _faces = ['Very low', 'Low', 'Okay', 'Good', 'Great'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final last = ref.watch(moodControllerProvider).value?.lastCheckin;
    String lastLine() {
      final t = last!.timestamp;
      return '${last.tag ?? moodWord(last.pleasantness)} at ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    }

    return _AreaCard(
      label: 'Mood',
      icon: 'heart.fill',
      tint: c.moodTint,
      ink: c.moodInk,
      onOpen: () => context.pushNamed(AppRoute.todayMood.name),
      tapBody: false,
      trailing: last == null
          ? null
          : Text(lastLine(), style: AppType.footnote.copyWith(color: c.ink3)),
      body: [
        Text('How are you now?',
            style: AppType.headline.copyWith(color: c.ink, letterSpacing: -0.2)),
        Row(
          children: [
            for (var i = 0; i < _faces.length; i++) ...[
              if (i > 0) const SizedBox(width: Spacing.sm),
              Expanded(
                child: PressScale(
                  onTap: () => showMoodLogger(context),
                  semanticLabel: _faces[i],
                  child: Container(
                    height: _faceHeight,
                    decoration: BoxDecoration(
                      color: c.moodTint,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: const Size.square(22),
                      painter: _FacePainter(mood: i / (_faces.length - 1), color: c.moodInk),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A line-drawn face whose mouth bends from a frown ([mood] 0) to a smile (1).
class _FacePainter extends CustomPainter {
  const _FacePainter({required this.mood, required this.color});

  final double mood;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s / 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2 - stroke.strokeWidth / 2, stroke);
    final eye = Paint()..color = color;
    canvas.drawCircle(Offset(s * 0.36, s * 0.4), s / 16, eye);
    canvas.drawCircle(Offset(s * 0.64, s * 0.4), s / 16, eye);
    final bend = (mood - 0.5) * s * 0.3;
    final y = s * 0.66 - bend / 2;
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.34, y)
        ..quadraticBezierTo(s / 2, y + bend, s * 0.66, y),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.mood != mood || old.color != color;
}

class _MoneyCard extends ConsumerWidget {
  const _MoneyCard({required this.today});

  final TodayState today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final budget = today.goals.dailyBudget;
    return _AreaCard(
      label: 'Money',
      icon: 'dollarsign.circle.fill',
      tint: c.moneyTint,
      ink: c.moneyInk,
      onOpen: () => context.pushNamed(AppRoute.spendingDetail.name),
      body: [
        _Figure(
          formatCurrency(today.moneySpent, currency),
          budget > 0 ? 'of ${formatCurrency(budget, currency)} today' : 'spent today',
        ),
      ],
    );
  }
}

class _MoveCard extends StatelessWidget {
  const _MoveCard({required this.today});

  final TodayState today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final goal = today.goals.dailyMoveKcal;
    return _AreaCard(
      label: 'Move',
      icon: 'figure.run',
      tint: c.moveTint,
      ink: c.moveInk,
      onOpen: () => context.pushNamed(AppRoute.moveDetail.name),
      body: [_Figure('${today.moveKcal}', goal > 0 ? 'of $goal kcal' : 'kcal moved')],
    );
  }
}

class _NutritionCard extends ConsumerWidget {
  const _NutritionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(nutritionControllerProvider).value;
    final meals = state?.meals.length ?? 0;
    return _AreaCard(
      label: 'Nutrition',
      icon: 'fork.knife',
      tint: c.nutritionTint,
      ink: c.nutritionInk,
      onOpen: () => context.goNamed(AppRoute.nutrition.name),
      body: [
        if (state == null || meals == 0)
          _quiet(c, 'No meals logged yet.')
        else
          _Figure('≈${state.day.cal.mid}', 'kcal · $meals ${meals == 1 ? 'meal' : 'meals'}'),
      ],
    );
  }
}
