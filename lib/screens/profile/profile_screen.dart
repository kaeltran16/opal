import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/correlations.dart' show kMinPairedDays;
import '../../analysis/pal_findings.dart';
import '../../controllers/autopilot_controller.dart';
import '../../controllers/email_sync_controller.dart';
import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/pal_findings_controller.dart';
import '../../controllers/pal_memory_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/providers.dart';
import '../../router.dart';
import '../../services/pal/pal_context_builder.dart' show moveStreakDays;
import '../../theme/theme.dart';
import '../../util/dates.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import '../you/autopilot_screen.dart';
import '../you/pal_memory_screen.dart';
import '../you/sub_screen.dart' show kSubScreenShellOverlay;

// kept literal: where the prototype's content starts, just under the status bar.
const double _contentTop = 52;
const double _minTap = 44;
const double _rowMinHeight = 48;
const double _hairline = 1;
const double _bar = 4;
const double _chevron = 16;
const double _closeIcon = 13;
const double _leadMaxWidth = 330;
const double _learningMaxWidth = 320;
// the 21st day is named by weekday while it falls within the coming week.
const int _weekdayHorizon = 6;

/// The You tab: a header line, Pal's findings (a lead, then Also seen), the
/// Pal group opening What Pal remembers and Autopilot, then Settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final name = ref.watch(settingsRepositoryProvider).displayNameOrDefault;
    final stats = ref.watch(profileStatsProvider);
    // the live workout streak from real entries, as the Move week strip and
    // the streak celebration count it; the agenda's streakDays can drift.
    final entries = ref.watch(allEntriesStreamProvider).asData?.value;
    final streakDays = entries == null ? 0 : moveStreakDays(entries);
    final memberSince = stats.asData?.value.memberSince;
    // same connection-state source the email dashboard uses, so the row can't
    // claim "On" while the dashboard says "not connected".
    final emailConnected =
        ref.watch(emailDashboardControllerProvider).isConnected;

    void push(Widget screen) => Navigator.of(context)
        .push(CupertinoPageRoute<void>(builder: (_) => screen));

    final list = ListView(
      padding: EdgeInsets.only(
        top: math.max(_contentTop, safe.top + Spacing.xs),
        bottom: kSubScreenShellOverlay + Spacing.xxl + safe.bottom,
      ),
      children: [
        _Gutter(children: [
          _Header(
              line: youLine(name, streakDays, memberSince, clock.now())),
          const SizedBox(height: Spacing.md),
          _Findings(stats: stats),
          const SizedBox(height: Spacing.xxl + Spacing.md),
          const _Heading('Pal'),
          const SizedBox(height: Spacing.md),
          _LinkRow(
            title: 'What Pal remembers',
            value: _factsValue(ref),
            onTap: () => push(const PalMemoryScreen()),
          ),
          _LinkRow(
            title: 'Autopilot',
            value: _autopilotValue(ref),
            onTap: () => push(const AutopilotScreen()),
          ),
          const SizedBox(height: Spacing.xxl + Spacing.md),
        ]),

        _Gutter(children: [
          const _Heading('Settings'),
          const SizedBox(height: Spacing.md),
          _LinkRow(
            title: 'Goals',
            onTap: () => context.pushNamed(AppRoute.budgetsGoals.name),
          ),
          _LinkRow(
            title: 'Budgets',
            onTap: () => context.pushNamed(AppRoute.youBudgets.name),
          ),
          _LinkRow(
            title: 'Reviews',
            value: 'Day · Week · Month',
            onTap: () => context.pushNamed(AppRoute.recap.name,
                queryParameters: const {'range': 'day'}),
          ),
          _LinkRow(
            title: 'Email sync',
            value: emailConnected ? 'Gmail · On' : 'Not connected',
            onTap: () => context.pushNamed(AppRoute.emailSync.name),
          ),
          _LinkRow(
            title: 'Data and privacy',
            onTap: () => context.pushNamed(AppRoute.privacy.name),
          ),
          _LinkRow(
            title: 'Appearance',
            onTap: () => context.pushNamed(AppRoute.appearance.name),
          ),
          _LinkRow(
            title: 'About and help',
            onTap: () => context.pushNamed(AppRoute.about.name),
          ),
        ]),
      ],
    );
    return ColoredBox(color: c.bg, child: list);
  }

  static String _factsValue(WidgetRef ref) {
    final facts = ref.watch(palMemoryProvider).asData?.value.facts;
    if (facts == null) return '';
    return facts.length == 1 ? '1 fact' : '${facts.length} facts';
  }

  static String _autopilotValue(WidgetRef ref) {
    final items = ref.watch(palAgendaProvider).asData?.value.autopilot;
    // watched so a switch flipped on Autopilot recounts here.
    ref.watch(autopilotSwitchesProvider);
    if (items == null) return '';
    final switches = ref.read(autopilotSwitchesProvider.notifier);
    return '${items.where(switches.isOn).length} on';
  }
}

/// The line beside the You title: the workout streak, else how long the user
/// has been tracking.
@visibleForTesting
String youLine(String name, int streakDays, DateTime? memberSince, DateTime now) {
  if (streakDays > 0) return '$name · $streakDays-day workout streak';
  if (memberSince == null) return '$name · Just getting started';
  return '$name · Tracking since ${kMonths[memberSince.month - 1]} ${memberSince.year}';
}

/// Whole days logged, from [memberSince] to [now] counting both; 0 with no
/// history.
int _loggedDays(DateTime? memberSince, DateTime now) => memberSince == null
    ? 0
    : startOfDay(now).difference(startOfDay(memberSince)).inDays + 1;

/// The Still learning body for [days] logged as of [now].
@visibleForTesting
String learningBody(int days, DateTime now) {
  const intro = 'Patterns need $kMinPairedDays days of logging.';
  if (days <= 0) return '$intro Log a few things and Pal starts looking.';
  final away = kMinPairedDays - days;
  final due = startOfDay(now).add(Duration(days: away));
  final when = away <= _weekdayHorizon
      ? kWeekdays[due.weekday - 1]
      : 'on ${kMonthsShort[due.month - 1]} ${due.day}';
  return '$intro You have $days, so the first ones should show up $when.';
}

/// Horizontal page gutter around a run of You's own sections.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

/// The You title with [line] beside it, wrapping under it when it won't fit.
class _Header extends StatelessWidget {
  const _Header({required this.line});
  final String line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTap),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        // full width, so spaceBetween puts the line at the right of the title.
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.sm,
            children: [
              Semantics(
                header: true,
                child: Text('You', style: AppType.title.copyWith(color: c.ink)),
              ),
              Text(line, style: AppType.label.copyWith(color: c.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text,
            style: AppType.headline
                .copyWith(color: context.colors.ink, height: 22 / 17)),
      );
}

/// Pal's findings: the lead, then Also seen; or why there are none.
class _Findings extends ConsumerWidget {
  const _Findings({required this.stats});
  final AsyncValue<ProfileStats> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final quiet = AppType.subhead.copyWith(color: c.ink3, height: 20 / 15);
    final async = ref.watch(palFindingsControllerProvider);
    if (async.hasError) {
      debugPrint('you: loading Pal findings failed: ${async.error}');
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: Text("Couldn't load Pal's findings.", style: quiet),
      );
    }
    final findings = async.value;
    if (findings == null) return const SizedBox.shrink();
    final ctl = ref.read(palFindingsControllerProvider.notifier);

    if (findings.isEmpty) {
      // the logged-days count decides which empty state, so wait for it.
      if (!stats.hasValue) return const SizedBox.shrink();
      final days = _loggedDays(stats.requireValue.memberSince, clock.now());
      if (days < kMinPairedDays) return _Learning(days: days);
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: Text('No patterns right now. Pal looks again as new days come in.',
            style: quiet),
      );
    }

    final lead = findings.where((f) => f.hasComparison).firstOrNull;
    final others = [
      for (final f in findings)
        if (f != lead) f,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lead != null)
          _Lead(finding: lead, onDismiss: () => ctl.dismiss(lead.id)),
        if (others.isNotEmpty) ...[
          SizedBox(height: lead == null ? Spacing.sm : Spacing.xxl + Spacing.md),
          const _Heading('Also seen'),
          const SizedBox(height: Spacing.md),
          for (final f in others)
            _AlsoSeenRow(finding: f, onDismiss: () => ctl.dismiss(f.id)),
        ],
      ],
    );
  }
}

/// What a finding reads as to a screen reader: its line and comparison, or
/// its line and areas, then what a tap does.
String _findingLabel(PalFinding f) {
  final a = f.a;
  final b = f.b;
  if (a != null && b != null) {
    return '${f.line} ${a.label} ${a.value}, ${b.label} ${b.value}. Ask Pal';
  }
  final areas = f.areasLabel;
  return areas.isEmpty ? '${f.line}. Ask Pal' : '${f.line}. $areas. Ask Pal';
}

void _ask(BuildContext context, PalFinding f) => context.pushNamed(
    AppRoute.palComposer.name,
    queryParameters: {'seed': f.question});

/// The lead finding: the Pal eyebrow, the serif line, its a/b bars, then its
/// evidence. The x dismisses it.
class _Lead extends StatelessWidget {
  const _Lead({required this.finding, required this.onDismiss});
  final PalFinding finding;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = finding;
    final areas = f.areasLabel;
    final a = f.a;
    final b = f.b;
    return Stack(
      children: [
        Semantics(
          container: true,
          child: PressScale(
            onTap: () => _ask(context, f),
            semanticLabel: _findingLabel(f),
            child: Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    // clear of the x in the corner.
                    padding: const EdgeInsets.only(right: _minTap),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PalLabel(
                          text: areas.isEmpty ? 'Pal noticed' : 'Pal noticed · $areas'),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _leadMaxWidth),
                      child: Text(f.lead ?? f.line,
                          style: AppType.lead.copyWith(color: c.ink)),
                    ),
                  ),
                  if (a != null && b != null) ...[
                    const SizedBox(height: Spacing.md + Spacing.xs),
                    _SideBar(side: a, fill: c.ink),
                    const SizedBox(height: Spacing.md),
                    _SideBar(side: b, fill: c.ink3),
                  ],
                  const SizedBox(height: Spacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: _minTap),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(f.evidence,
                              style: AppType.caption.copyWith(
                                  color: c.ink3, height: 16 / 12, letterSpacing: 0.3)),
                        ),
                        const SizedBox(width: Spacing.xs),
                        AppIcon('chevron.right', size: _chevron, color: c.ink3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: _DismissButton(line: f.line, onTap: onDismiss),
        ),
      ],
    );
  }
}

/// One side of a comparison: its label and value over a 4 px bar.
class _SideBar extends StatelessWidget {
  const _SideBar({required this.side, required this.fill});
  final FindingSide side;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) => Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(side.label,
                    style: AppType.subhead.copyWith(color: c.ink2, height: 20 / 15)),
              ),
              const SizedBox(width: Spacing.md),
              _Value(
                side.value,
                maxWidth: box.maxWidth,
                style: AppType.subhead.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                    height: 20 / 15,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        _Bar(fraction: side.fraction, fill: fill),
      ],
    );
  }
}

/// A 4 px track filled to [fraction].
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.fill});
  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.pill);
    return Container(
      height: _bar,
      decoration: BoxDecoration(color: context.colors.track, borderRadius: radius),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          height: _bar,
          decoration: BoxDecoration(color: fill, borderRadius: radius),
        ),
      ),
    );
  }
}

/// A finding under Also seen: its line, then its areas and evidence.
class _AlsoSeenRow extends StatelessWidget {
  const _AlsoSeenRow({required this.finding, required this.onDismiss});
  final PalFinding finding;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = finding;
    final areas = f.areasLabel;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              child: PressScale(
                onTap: () => _ask(context, f),
                semanticLabel: _findingLabel(f),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md + Spacing.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.line,
                                style: AppType.callout.copyWith(color: c.ink, height: 22 / 16)),
                            const SizedBox(height: Spacing.xs),
                            Text(areas.isEmpty ? f.evidence : '$areas · ${f.evidence}',
                                style: AppType.caption.copyWith(
                                    color: c.ink3, height: 16 / 12, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      AppIcon('chevron.right', size: _chevron, color: c.ink3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _DismissButton(line: f.line, onTap: onDismiss),
        ],
      ),
    );
  }
}

/// The 44 by 44 x that dismisses a finding.
class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.line, required this.onTap});
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        // its own node, so nearby text does not merge into its label.
        container: true,
        child: PressScale(
          onTap: onTap,
          semanticLabel: 'Dismiss: $line',
          child: SizedBox.square(
            dimension: _minTap,
            child: Center(
                child: AppIcon('xmark', size: _closeIcon, color: context.colors.ink3)),
          ),
        ),
      );
}

/// No findings yet and too few days logged: how far along the user is.
class _Learning extends StatelessWidget {
  const _Learning({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = days.clamp(0, kMinPairedDays);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: AlignmentDirectional.centerStart, child: PalLabel()),
          const SizedBox(height: Spacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _learningMaxWidth),
              child: Text('Still learning your patterns.',
                  style: AppType.lead.copyWith(color: c.ink)),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(learningBody(days, clock.now()),
              style: AppType.subhead.copyWith(color: c.ink2, height: 20 / 15)),
          const SizedBox(height: Spacing.md + Spacing.sm),
          Semantics(
            container: true,
            label: '$shown of $kMinPairedDays days logged',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Bar(fraction: shown / kMinPairedDays, fill: c.ink),
                const SizedBox(height: Spacing.sm),
                Text('$shown of $kMinPairedDays days',
                    style: AppType.caption
                        .copyWith(color: c.ink3, height: 16 / 12, letterSpacing: 0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A hairline row: [title], an optional [value], then a chevron.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, this.value = '', required this.onTap});
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      child: PressScale(
        onTap: onTap,
        semanticLabel: value.isEmpty ? title : '$title, $value',
        child: Container(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hair, width: _hairline)),
          ),
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppType.callout.copyWith(color: c.ink, height: 22 / 16)),
                ),
                if (value.isNotEmpty) ...[
                  const SizedBox(width: Spacing.md),
                  _Value(value,
                      maxWidth: box.maxWidth, style: AppType.subhead.copyWith(color: c.ink3)),
                ],
                const SizedBox(width: Spacing.md),
                AppIcon('chevron.right', size: _chevron, color: c.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row's trailing value: as wide as it reads, up to half of [maxWidth], then
/// it wraps rather than overflows.
class _Value extends StatelessWidget {
  const _Value(this.text, {required this.maxWidth, required this.style});
  final String text;
  final double maxWidth;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth / 2),
        child: Text(text, textAlign: TextAlign.end, style: style),
      );
}


