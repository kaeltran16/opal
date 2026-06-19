import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_agenda_controller.dart';
import '../../controllers/pal_memory_controller.dart';
import '../../controllers/providers.dart';
import '../../router.dart';
import '../../services/pal/pal_service.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import '../../widgets/nav_bar.dart';
import '../../widgets/pal_avatar.dart';
import '../../widgets/press_scale.dart';

/// Pal Home — Pal promoted from a reactive sheet to a first-class agentic hub.
///
/// A daily "command center": an AI daily brief, cross-pillar actions the user
/// approves ("Needs you"), an "on autopilot" delegation list, and a "what Pal
/// remembers" persistent-memory section. Presented full-screen above the shell
/// (see the `/pal-home` route).
///
/// The agenda (proposals, autopilot, memory, streak) comes from the `/agenda`
/// Pal seam via [palAgendaProvider]; the brief is regenerated from the daily
/// `insights` seam on Refresh. Per-card approve/dismiss and toggle state is held
/// locally (keyed by id) over the server data — optimistic, with Undo — until a
/// real mutation seam lands.
class PalHomeScreen extends ConsumerStatefulWidget {
  const PalHomeScreen({super.key});

  @override
  ConsumerState<PalHomeScreen> createState() => _PalHomeScreenState();
}

class _PalHomeScreenState extends ConsumerState<PalHomeScreen> {
  // Showcase brief shown until the user refreshes — it intentionally does NOT
  // auto-fetch on open (the canvas renders many frames; auto-fetch would fire N
  // model calls). Refresh pulls a fresh line from the daily-insights seam.
  static const _defaultBrief =
      "You're having a steady Thursday — \$60 spent against your \$85 budget, "
      "66 minutes moved, and 4 of 5 rituals done. One ritual stands between you "
      "and a closed day, and rent clears Monday with room to spare. That's an "
      "11-day streak now — let's protect it.";

  String _brief = _defaultBrief;
  bool _loading = false;

  // Optimistic per-card overrides on top of the server agenda, keyed by id.
  final Map<String, _CardStatus> _statusById = {};
  final Map<String, bool> _autopilotById = {};

  _CardStatus _statusOf(String id) => _statusById[id] ?? _CardStatus.open;
  bool _autopilotOn(PalAutopilotItem a) => _autopilotById[a.id] ?? a.enabled;

  Future<void> _refreshBrief() async {
    setState(() => _loading = true);
    try {
      final insights =
          await ref.read(palServiceProvider).insights(InsightRange.day);
      final headline = insights.headline?.trim();
      if (mounted && headline != null && headline.isNotEmpty) {
        setState(() => _brief = headline);
      }
    } catch (_) {
      // keep the current brief — an unreachable model never blanks the card.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onApprove(PalProposal p) {
    if (p.navigatesToCloseOut) {
      context.pushNamed(AppRoute.eveningCloseOut.name);
      return;
    }
    setState(() => _statusById[p.id] = _CardStatus.done);
  }

  Future<void> _deleteFact(String id) async {
    await ref.read(palServiceProvider).deleteFact(id);
    ref.invalidate(palMemoryProvider);
  }

  Future<void> _wipeMemory() async {
    await ref.read(palServiceProvider).clearMemory();
    ref.invalidate(palMemoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = ref.watch(settingsRepositoryProvider).displayNameOrDefault;
    final agendaAsync = ref.watch(palAgendaProvider);
    final agenda = agendaAsync.asData?.value ?? const PalAgenda();
    final memory = ref.watch(palMemoryProvider).asData?.value ?? const PalMemoryDigest();

    final visibleProposals = agenda.proposals
        .where((p) => _statusOf(p.id) != _CardStatus.dismissed)
        .toList();
    final needsYou = agenda.proposals
        .where((p) => _statusOf(p.id) == _CardStatus.open)
        .length;
    final onAutopilot = agenda.autopilot.where(_autopilotOn).length;

    return Container(
      color: c.bg,
      child: ListView(
        // clears the floating tab bar.
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // --- Top bar: back to Today + Tune ---
          Padding(
            // top 56 = status-bar/safe-area offset, kept literal.
            padding:
                const EdgeInsets.fromLTRB(Spacing.lg, 56, Spacing.lg, Spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NavAction(
                  icon: 'chevron.left',
                  label: 'Today',
                  onTap: () => context.pop(),
                  semanticLabel: 'Back to Today',
                ),
                // Inert in this build — a "tune what Pal does" surface is future
                // work; rendered for fidelity with no dead-button tap target.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon('slider.horizontal.3', size: 15, color: c.accent),
                      const SizedBox(width: Spacing.xxs),
                      Text('Tune',
                          style: AppType.subhead.copyWith(
                              color: c.accent, letterSpacing: -0.15)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Pal hero ---
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 18),
            child: _Hero(
              name: name,
              needsYou: needsYou,
              onAutopilot: onAutopilot,
              streakDays: agenda.streakDays,
            ),
          ),

          // --- Today's brief ---
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 22),
            child: _BriefCard(
              brief: _brief,
              loading: _loading,
              onRefresh: _refreshBrief,
            ),
          ),

          // --- Needs you ---
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Needs you',
                    style:
                        AppType.title2.copyWith(color: c.ink, letterSpacing: 0.35)),
                Flexible(
                  child: Text("Approve and I'll handle it",
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.footnote
                          .copyWith(color: c.ink3, letterSpacing: -0.08)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 22),
            child: _NeedsYou(
              loading: agendaAsync.isLoading && agenda.proposals.isEmpty,
              proposals: visibleProposals,
              done: (p) => _statusOf(p.id) == _CardStatus.done,
              onApprove: _onApprove,
              onDismiss: (p) =>
                  setState(() => _statusById[p.id] = _CardStatus.dismissed),
              onUndo: (p) =>
                  setState(() => _statusById[p.id] = _CardStatus.open),
            ),
          ),

          // --- On autopilot ---
          if (agenda.autopilot.isNotEmpty)
            InsetSection(
              header: 'On autopilot',
              footer: 'Pal handles these quietly and only pings you if something '
                  'needs a decision.',
              children: [
                for (var i = 0; i < agenda.autopilot.length; i++)
                  _AutopilotRow(
                    item: agenda.autopilot[i],
                    on: _autopilotOn(agenda.autopilot[i]),
                    last: i == agenda.autopilot.length - 1,
                    onToggle: () {
                      final a = agenda.autopilot[i];
                      setState(() => _autopilotById[a.id] = !_autopilotOn(a));
                    },
                  ),
              ],
            ),

          // --- What Pal remembers ---
          if (!memory.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, 10),
              child: Text('What Pal remembers',
                  style:
                      AppType.title2.copyWith(color: c.ink, letterSpacing: 0.35)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 22),
              child: _MemoryCard(
                memory: memory,
                onDeleteFact: _deleteFact,
                onWipe: _wipeMemory,
              ),
            ),
          ],

          // --- Ask Pal CTA ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: _AskPalCta(),
          ),
        ],
      ),
    );
  }
}

enum _CardStatus { open, done, dismissed }

/// Maps an agenda color token to a theme color (the single clamp point — the
/// service passes the wire value through raw). Unknown → accent.
Color _tokenColor(AppColors c, String token) => switch (token) {
      'money' => c.money,
      'move' => c.move,
      'rituals' => c.rituals,
      _ => c.accent,
    };

class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.needsYou,
    required this.onAutopilot,
    required this.streakDays,
  });

  final String name;
  final int needsYou;
  final int onAutopilot;
  final int streakDays;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const white = Color(0xFFFFFFFF);
    final white85 = white.withValues(alpha: 0.85);
    final white80 = white.withValues(alpha: 0.80);

    final stats = <(String, String, bool)>[
      ('$needsYou', 'Need you', true),
      ('$onAutopilot', 'On autopilot', false),
      ('${streakDays}d', 'Streak held', false),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.accent, c.rituals],
          ),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.27),
              blurRadius: 34,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // decorative circle, clipped by the rounded container.
            Positioned(
              top: -50,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: white.withValues(alpha: 0.22),
                        ),
                        alignment: Alignment.center,
                        child: const AppIcon('sparkles', size: 20, color: white),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting, $name',
                                style: AppFonts.sf(
                                    size: 18,
                                    weight: FontWeight.w700,
                                    color: white,
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle, color: white),
                                ),
                                const SizedBox(width: 5),
                                Text('Caught up on your day',
                                    style: AppFonts.sf(
                                        size: 12,
                                        color: white85,
                                        letterSpacing: -0.08)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // stat strip
                  Container(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: white.withValues(alpha: 0.25), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final (value, label, leftAlign) in stats)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: leftAlign
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.center,
                              children: [
                                Text(value,
                                    style: AppFonts.sfr(
                                        size: 22,
                                        weight: FontWeight.w700,
                                        color: white,
                                        letterSpacing: -0.3,
                                        height: 1)),
                                const SizedBox(height: 3),
                                Text(label.toUpperCase(),
                                    style: AppFonts.sf(
                                        size: 10,
                                        weight: FontWeight.w600,
                                        color: white80,
                                        letterSpacing: 0.4)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({
    required this.brief,
    required this.loading,
    required this.onRefresh,
  });

  final String brief;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon('sparkles', size: 14, color: c.accent),
              const SizedBox(width: Spacing.sm),
              Text("TODAY'S BRIEF",
                  style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: loading ? 0.5 : 1,
            duration: const Duration(milliseconds: 200),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Text(brief,
                  style: AppType.callout.copyWith(
                      color: c.ink, letterSpacing: -0.3, height: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          PressScale(
            onTap: loading ? null : onRefresh,
            semanticLabel: 'Refresh brief',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                  color: c.fill, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon('arrow.triangle.2.circlepath',
                      size: 12, color: c.ink2),
                  const SizedBox(width: 6),
                  Text(loading ? 'Thinking…' : 'Refresh',
                      style: AppType.footnote.copyWith(
                          fontWeight: FontWeight.w500,
                          color: c.ink2,
                          letterSpacing: -0.08)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Needs you" stack: a loading hint, the visible proposal cards, or an
/// all-caught-up line when everything has been handled.
class _NeedsYou extends StatelessWidget {
  const _NeedsYou({
    required this.loading,
    required this.proposals,
    required this.done,
    required this.onApprove,
    required this.onDismiss,
    required this.onUndo,
  });

  final bool loading;
  final List<PalProposal> proposals;
  final bool Function(PalProposal) done;
  final void Function(PalProposal) onApprove;
  final void Function(PalProposal) onDismiss;
  final void Function(PalProposal) onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Text('Pal is lining up your day…',
            style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24)),
      );
    }
    if (proposals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Text("You're all caught up — nothing needs you right now.",
            style: AppType.subhead.copyWith(color: c.ink3, letterSpacing: -0.24)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < proposals.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AgentCard(
            proposal: proposals[i],
            done: done(proposals[i]),
            onApprove: () => onApprove(proposals[i]),
            onDismiss: () => onDismiss(proposals[i]),
            onUndo: () => onUndo(proposals[i]),
          ),
        ],
      ],
    );
  }
}

/// A proposed cross-pillar action with Approve / Not now. In the [done] state it
/// collapses to a confirmation row that bounces in with the brand's success
/// easing (`Cubic(0.34, 1.56, 0.64, 1)`).
class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.proposal,
    required this.done,
    required this.onApprove,
    required this.onDismiss,
    required this.onUndo,
  });

  final PalProposal proposal;
  final bool done;
  final VoidCallback onApprove;
  final VoidCallback onDismiss;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return done ? _buildDone(context, c) : _buildOpen(context, c);
  }

  Widget _buildDone(BuildContext context, AppColors c) {
    return TweenAnimationBuilder<double>(
      // bouncy "success" easing; the >1 control point gives the overshoot.
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: const Cubic(0.34, 1.56, 0.64, 1),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: c.move, borderRadius: BorderRadius.circular(Radii.sm)),
              alignment: Alignment.center,
              child: AppIcon('checkmark', size: 17, color: c.onAccent),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(proposal.doneLabel,
                      style: AppType.footnote.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 1),
                  Text('Done by Pal · just now',
                      style: AppType.caption
                          .copyWith(color: c.ink3, letterSpacing: -0.08)),
                ],
              ),
            ),
            PressScale(
              onTap: onUndo,
              semanticLabel: 'Undo',
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text('Undo',
                    style: AppType.footnote.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.accent,
                        letterSpacing: -0.1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpen(BuildContext context, AppColors c) {
    final color = _tokenColor(c, proposal.colorToken);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: AppIcon(proposal.icon, size: 17, color: c.onAccent),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(proposal.tag.toUpperCase(),
                        style: AppType.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 3),
                    Text(proposal.title,
                        style: AppType.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.24,
                            height: 1.3)),
                    const SizedBox(height: 4),
                    Text(proposal.body,
                        style: AppType.footnote.copyWith(
                            color: c.ink2,
                            letterSpacing: -0.08,
                            height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  onTap: onApprove,
                  semanticLabel: proposal.approveLabel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(11)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(proposal.approveIcon, size: 13, color: c.onAccent),
                        const SizedBox(width: 7),
                        Text(proposal.approveLabel,
                            style: AppType.footnote.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.onAccent,
                                letterSpacing: -0.15)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              PressScale(
                onTap: onDismiss,
                semanticLabel: 'Not now',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: c.hair, width: 0.5),
                  ),
                  child: Text('Not now',
                      style: AppType.footnote.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.ink2,
                          letterSpacing: -0.15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutopilotRow extends StatelessWidget {
  const _AutopilotRow({
    required this.item,
    required this.on,
    required this.last,
    required this.onToggle,
  });

  final PalAutopilotItem item;
  final bool on;
  final bool last;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: _tokenColor(c, item.colorToken),
                borderRadius: BorderRadius.circular(Radii.sm)),
            alignment: Alignment.center,
            child: AppIcon(item.icon, size: 16, color: c.onAccent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.24)),
                const SizedBox(height: 1),
                Text(item.subtitle,
                    style: AppType.caption
                        .copyWith(color: c.ink3, letterSpacing: -0.08)),
              ],
            ),
          ),
          _Toggle(on: on, onTap: onToggle, semanticLabel: item.title),
        ],
      ),
    );
  }
}

/// iOS-style toggle: 42×26 track, 22px knob, [c.move] when on.
class _Toggle extends StatelessWidget {
  const _Toggle(
      {required this.on, required this.onTap, required this.semanticLabel});

  final bool on;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: on,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 26,
          decoration: BoxDecoration(
              color: on ? c.move : c.fill,
              borderRadius: BorderRadius.circular(Radii.pill)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFFFFF),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "What Pal remembers": user-authored [PalMemoryDigest.facts] (each deletable)
/// and Pal-derived [PalMemoryDigest.patterns] (read-only). The footer row wipes
/// all stored memory.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.onDeleteFact,
    required this.onWipe,
  });

  final PalMemoryDigest memory;
  final Future<void> Function(String id) onDeleteFact;
  final Future<void> Function() onWipe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final f in memory.facts)
            _row(c, text: f.text, onDelete: () => onDeleteFact(f.id)),
          for (final p in memory.patterns)
            _row(c, text: p.title, meta: p.detail),
          // Wipe-all footer.
          PressScale(
            onTap: onWipe,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AppIcon('trash.fill', size: 13, color: c.accent),
                  const SizedBox(width: Spacing.sm),
                  Text('Clear what Pal remembers',
                      style: AppType.footnote
                          .copyWith(color: c.accent, letterSpacing: -0.08)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors c, {required String text, String? meta, VoidCallback? onDelete}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: BorderRadius.circular(Radii.sm)),
            alignment: Alignment.center,
            child: AppIcon('sparkles', size: 13, color: c.accent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: AppType.footnote.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.15,
                        height: 1.35)),
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Text(meta,
                      style: AppType.caption2
                          .copyWith(color: c.ink4, letterSpacing: -0.08)),
                ],
              ],
            ),
          ),
          // facts are user-authored and deletable; patterns are read-only.
          if (onDelete != null)
            PressScale(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.sm, top: 2),
                child: AppIcon('xmark', size: 13, color: c.ink4),
              ),
            ),
        ],
      ),
    );
  }
}

class _AskPalCta extends StatelessWidget {
  const _AskPalCta();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      onTap: () => context.pushNamed(AppRoute.palComposer.name),
      semanticLabel: 'Ask Pal anything',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [BoxShadow(color: c.hair, blurRadius: 0, spreadRadius: 0.5)],
        ),
        child: Row(
          children: [
            const PalAvatar(size: 38, glyphSize: 17),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Pal anything',
                      style: AppType.subhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                          letterSpacing: -0.24)),
                  const SizedBox(height: 1),
                  Text('Log, ask about a pattern, or plan ahead',
                      style: AppType.caption
                          .copyWith(color: c.ink3, letterSpacing: -0.08)),
                ],
              ),
            ),
            AppIcon('arrow.up.right', size: 15, color: c.ink4),
          ],
        ),
      ),
    );
  }
}
