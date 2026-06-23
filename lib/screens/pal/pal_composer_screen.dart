import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_composer_controller.dart';
import '../../controllers/pal_suggestions_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/today_controller.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/theme.dart';
import '../../util/entry_glyph.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pal_avatar.dart';
import '../../widgets/press_scale.dart';

/// Screens 03/04 — the Pal composer: the unified FAB input surface that replaces
/// the old Quick-Actions menu AND the standalone Ask Pal screen.
///
/// Presented as a bottom sheet. Compact by default (greeting header, a
/// "Start a workout" affordance, and three starter chips); grows into a
/// scrolling chat as the user types or taps a chip. Natural-language input
/// routes to logging or answering through [PalService.chat]; the workout
/// affordance hands off to the Start-Workout flow.
///
/// State lives in [PalComposerController], seeded via the optional [seed] (e.g.
/// a Today-screen chip that pre-fills the first user message).
class PalComposerSheet extends ConsumerStatefulWidget {
  const PalComposerSheet({super.key, this.seed});

  /// Optional initial user message: when non-empty the sheet opens expanded with
  /// this as the first message and fires its reply on build.
  final String? seed;

  @override
  ConsumerState<PalComposerSheet> createState() => _PalComposerSheetState();
}

class _PalComposerSheetState extends ConsumerState<PalComposerSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  PalComposerController get _controller =>
      ref.read(palComposerControllerProvider(seed: widget.seed).notifier);

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputCtrl.clear();
    final pending = _controller.send(trimmed);
    _scrollToBottomSoon();
    final result = await pending;
    if (!mounted) return;
    // Pal's unreachable and the text looks loggable — close the composer and
    // hand off to the manual New Entry sheet (which surfaces an offline notice).
    if (result == PalSendResult.offlineFallback) {
      context.pushReplacement('/entry/new?kind=expense&notice=pal-offline');
    }
  }

  void _sendStarter(_Starter starter) {
    _controller.sendStarter(starter.label, starter.payload);
    _scrollToBottomSoon();
  }

  /// Edit a logged turn: reverse it, drop it from the transcript, and drop the
  /// original text back into the composer (focused, caret at the end) to fix.
  Future<void> _editLog(int index) async {
    final text = await _controller.editLog(index);
    _inputCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _inputFocus.requestFocus();
  }

  void _close() => context.pop();

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(palComposerControllerProvider(seed: widget.seed));

    // Keep pinned to the newest content whenever the transcript grows.
    ref.listen(palComposerControllerProvider(seed: widget.seed),
        (_, _) => _scrollToBottomSoon());

    final expanded = state.expanded;
    final media = MediaQuery.of(context);
    // Lift the sheet above the keyboard so the composer stays visible; shrink
    // the cap by the same inset so the expanded sheet never overflows the top.
    final keyboard = media.viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.22, 1, 0.36, 1),
        margin: EdgeInsets.only(bottom: keyboard),
        height: expanded ? media.size.height * 0.86 : null,
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92 - keyboard),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: _close),
              if (expanded)
                Expanded(
                  child: _MessageList(
                    controller: _scrollCtrl,
                    messages: state.messages,
                    isLoading: state.isLoading,
                    onUndo: (i) => _controller.undo(i),
                    onEdit: _editLog,
                  ),
                )
              else
                _CompactBody(onSendStarter: _sendStarter),
              _Composer(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                expanded: expanded,
                hasText: _inputCtrl.text.trim().isNotEmpty,
                enabled: !state.isLoading,
                onSend: () => _send(_inputCtrl.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grabber bar + header: gradient avatar, "Pal", status line, close button.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(bottom: Spacing.md),
            decoration: BoxDecoration(
              color: c.hair,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
          ),
          Row(
            children: [
              const PalAvatar(size: 32, glyphSize: 16),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pal',
                      style: AppType.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.24,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.move,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Log, ask, or start anything',
                          style: AppType.caption.copyWith(
                            color: c.ink3,
                            letterSpacing: -0.08,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration:
                          BoxDecoration(color: c.fill, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: AppIcon('xmark', size: 13, color: c.ink3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The compact-state body: a "Start a workout" card, a "Try saying" label, and
/// three starter chips. Shown only before the conversation expands.
class _CompactBody extends ConsumerWidget {
  const _CompactBody({required this.onSendStarter});

  final ValueChanged<_Starter> onSendStarter;

  static const _starters = <_Starter>[
    _Starter(
      'dollarsign.circle.fill',
      'money',
      'Verve coffee, \$5',
      payload: StarterEntry(
        type: EntryType.money,
        title: 'Verve coffee',
        amount: -5, // negative = expense
        category: 'Coffee',
      ),
    ),
    _Starter(
      'sparkles',
      'rituals',
      'Finished morning pages',
      payload: StarterEntry(
        type: EntryType.rituals,
        title: 'Morning pages',
      ),
    ),
    // Open prompt, not a concrete log — no local fallback.
    _Starter('chart.bar.fill', 'accent', 'How’s my week so far?'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // Pal-generated starters when available; the static list is the fallback for
    // loading / offline / empty, preserving the original offline quick-logs.
    final palStarters = ref
        .watch(palSuggestionsProvider(SuggestionSurface.composer))
        .maybeWhen(
          data: (list) => list.isEmpty
              ? null
              : list
                  .map((s) => _Starter(s.icon, s.colorToken, s.label, payload: s.entry))
                  .toList(),
          orElse: () => null,
        );
    final starters = palStarters ?? _starters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.xs, Spacing.md, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PressScale(
            semanticLabel: 'Start a workout',
            onTap: () {
              context.pop();
              context.go('/move/start');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
              decoration: BoxDecoration(
                color: c.moveTint,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.move,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon('play.fill', size: 14,
                        color: c.onAccent),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start a workout',
                          style: AppType.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.24,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "Jump into a routine — I'll track it",
                          style: AppType.caption.copyWith(
                            color: c.ink3,
                            letterSpacing: -0.08,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  AppIcon('chevron.right', size: 13, color: c.ink4),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.xs, Spacing.xs, Spacing.sm),
            child: Text(
              'TRY SAYING',
              style: AppType.caption2.copyWith(
                fontWeight: FontWeight.w700,
                color: c.ink3,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (var i = 0; i < starters.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.sm),
            _StarterChip(
              starter: starters[i],
              onTap: () => onSendStarter(starters[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Starter {
  const _Starter(this.icon, this.colorToken, this.label, {this.payload});

  final String icon;
  final String colorToken;
  final String label;

  /// Structured quick-log written locally when Pal is offline. Null for
  /// open-prompt starters (which have nothing deterministic to log).
  final StarterEntry? payload;
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.starter, required this.onTap});

  final _Starter starter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      semanticLabel: starter.label,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          children: [
            AppIcon(starter.icon, size: 15, color: c.forType(starter.colorToken)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                starter.label,
                style: AppType.subhead.copyWith(
                  color: c.ink,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            AppIcon('arrow.up.right', size: 11, color: c.ink4),
          ],
        ),
      ),
    );
  }
}

/// The scrolling chat transcript, plus a typing bubble while a reply is pending.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.isLoading,
    required this.onUndo,
    required this.onEdit,
  });

  final ScrollController controller;
  final List<PalMessage> messages;
  final bool isLoading;
  final void Function(int index) onUndo;
  final void Function(int index) onEdit;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isLoading ? 1 : 0);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xs),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (isLoading && i == itemCount - 1) {
          return const _Bubble.typing();
        }
        return _Bubble(
          message: messages[i],
          onUndo: () => onUndo(i),
          onEdit: () => onEdit(i),
        );
      },
    );
  }
}

/// A chat turn. User → right accent bubble. Assistant → left fill bubble behind
/// a 24×24 gradient avatar. A turn that logged an entry renders one [_LogCard]
/// per [LogEntryAction] (each with its own Undo/Edit) followed by the optional
/// insight bubble; the text-link Undo stays for non-log action turns (goal /
/// routine changes). The [_Bubble.typing] variant shows pulsing dots.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onUndo, this.onEdit})
      : isTyping = false;
  const _Bubble.typing()
      : message = null,
        onUndo = null,
        onEdit = null,
        isTyping = true;

  final PalMessage? message;

  /// Reverses this turn's auto-applied actions (keeps the message, flags it
  /// undone). Bound to the message index by [_MessageList].
  final VoidCallback? onUndo;

  /// Reverses + removes a logged turn and refills the composer to fix it.
  final VoidCallback? onEdit;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    if (isTyping) {
      return _assistantRow(
          context, _styledBubble(context, const _TypingDots(), isUser: false));
    }

    final m = message!;
    if (m.role == PalRole.user) return _userRow(context, m.text);

    final logActions =
        m.actions.where((a) => a is LogEntryAction || a is LogMealAction).toList();
    if (logActions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final action in logActions)
            if (action is LogEntryAction)
              _LogCard(action: action, undone: m.undone, onUndo: onUndo, onEdit: onEdit)
            else if (action is LogMealAction)
              _MealCard(action: action, undone: m.undone, onUndo: onUndo, onEdit: onEdit),
          if (m.text.trim().isNotEmpty)
            _assistantRow(context, _textBubble(context, m.text, isUser: false)),
        ],
      );
    }

    return _assistantRowWithUndo(context, m);
  }

  /// The rounded message container (no avatar). [isUser] flips fill + tail side.
  Widget _styledBubble(BuildContext context, Widget child,
      {required bool isUser}) {
    final c = context.colors;
    const radius = Radius.circular(Radii.lg);
    const tail = Radius.circular(Radii.xs);
    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: isUser ? c.accent : c.fill,
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: isUser ? radius : tail,
          bottomRight: isUser ? tail : radius,
        ),
      ),
      child: child,
    );
  }

  Widget _textBubble(BuildContext context, String text, {required bool isUser}) {
    final c = context.colors;
    return _styledBubble(
      context,
      Text(
        text,
        style: AppType.subhead.copyWith(
          color: isUser ? c.onAccent : c.ink,
          letterSpacing: -0.24,
          height: 1.4,
        ),
      ),
      isUser: isUser,
    );
  }

  Widget _userRow(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [Flexible(child: _textBubble(context, text, isUser: true))],
        ),
      );

  Widget _assistantRow(BuildContext context, Widget bubble) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const PalAvatar(size: 24, glyphSize: 11),
            const SizedBox(width: Spacing.sm),
            Flexible(child: bubble),
          ],
        ),
      );

  /// A plain assistant reply that may carry a text-link Undo (goal/routine
  /// turns) or an "Undone" marker.
  Widget _assistantRowWithUndo(BuildContext context, PalMessage m) {
    final c = context.colors;
    final showUndo = m.actions.isNotEmpty && !m.undone;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const PalAvatar(size: 24, glyphSize: 11),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textBubble(context, m.text, isUser: false),
                if (showUndo)
                  GestureDetector(
                    onTap: onUndo,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: Spacing.xs, left: Spacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon('arrow.uturn.backward', size: 12, color: c.accent),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            'Undo',
                            style: AppType.footnote.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.accent,
                              letterSpacing: -0.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (m.undone)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: Spacing.xs, left: Spacing.sm),
                    child: Text(
                      'Undone',
                      style: AppType.footnote.copyWith(
                        color: c.ink3,
                        letterSpacing: -0.08,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The confirmation card shown when a Pal turn logged an entry: a green LOGGED
/// header, the parsed entry on a category-tinted icon tile, a live progress bar
/// for the affected tracker (red + "over by" when a spend pushes past budget),
/// and Undo / Edit. The ring reads live post-log totals from [todayStateProvider]
/// — the entry is already persisted by the time this builds — so it stays
/// truthful to the app's own metrics (money $/budget, move kcal, rituals done).
class _LogCard extends ConsumerWidget {
  const _LogCard({
    required this.action,
    required this.undone,
    this.onUndo,
    this.onEdit,
  });

  final LogEntryAction action;
  final bool undone;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final currency = ref.watch(appSettingsControllerProvider).currency;
    final today = ref.watch(todayStateProvider).asData?.value;

    final color = c.forType(action.type.wire);
    final tint = switch (action.type) {
      EntryType.money => c.moneyTint,
      EntryType.move => c.moveTint,
      EntryType.rituals => c.ritualsTint,
    };

    final subtitle = switch (action.type) {
      EntryType.money => '${action.category ?? 'Expense'} · Just now',
      EntryType.move => 'Workout · Just now',
      EntryType.rituals => 'Ritual · Just now',
    };
    final trailing = switch (action.type) {
      EntryType.money =>
        formatCurrency(action.amount ?? 0, currency, withSign: true),
      EntryType.move =>
        action.durationMinutes != null ? '${action.durationMinutes} min' : null,
      EntryType.rituals => 'Done',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const PalAvatar(size: 24, glyphSize: 11),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.84),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  topRight: Radius.circular(Radii.lg),
                  bottomRight: Radius.circular(Radii.lg),
                  bottomLeft: Radius.circular(Radii.xs),
                ),
                border: Border.all(color: c.hair, width: 0.5),
                boxShadow: [
                  BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LOGGED header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.md, Spacing.md, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: AppIcon('checkmark', size: 9, color: c.onAccent),
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'LOGGED',
                          style: AppType.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Entry row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: tint, borderRadius: BorderRadius.circular(Radii.md)),
                          alignment: Alignment.center,
                          child: AppIcon(
                              entryGlyph(action.type, category: action.category),
                              size: 18,
                              color: color),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.subhead.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                  letterSpacing: -0.24,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                subtitle,
                                style: AppType.caption.copyWith(
                                    color: c.ink3, letterSpacing: -0.08),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: Spacing.sm),
                          Text(
                            trailing,
                            style: AppType.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  action.type == EntryType.money ? c.money : color,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Live ring for the affected tracker
                  if (today != null) _ring(context, today, currency),
                  // Undo / Edit (or the undone marker)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.hair, width: 0.5)),
                    ),
                    child: undone
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: Spacing.md),
                            child: Center(
                              child: Text(
                                'Undone',
                                style: AppType.footnote.copyWith(
                                    color: c.ink3, letterSpacing: -0.08),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _CardAction(
                                    label: 'Undo', color: c.red, onTap: onUndo),
                              ),
                              Container(width: 0.5, height: 38, color: c.hair),
                              Expanded(
                                child: _CardAction(
                                    label: 'Edit', color: c.accent, onTap: onEdit),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The updated progress bar for [action]'s tracker, read from live [today]
  /// totals (which already include the just-logged entry).
  Widget _ring(BuildContext context, TodayState today, Currency currency) {
    final c = context.colors;
    final String label;
    final String right;
    final double pct;
    final Color bar;
    var over = false;
    switch (action.type) {
      case EntryType.money:
        final now = today.moneySpent;
        final goal = today.goals.dailyBudget;
        over = goal > 0 && now > goal;
        label = 'Spending today';
        right = over
            ? '${formatCurrency(now, currency)} · over by ${formatCurrency(now - goal, currency)}'
            : '${formatCurrency(now, currency)} / ${formatCurrency(goal, currency)}';
        pct = goal > 0 ? (now / goal).clamp(0.0, 1.0) : 0.0;
        bar = over ? c.red : c.money;
      case EntryType.move:
        final now = today.moveKcal;
        final goal = today.goals.dailyMoveKcal;
        label = 'Movement today';
        right = '$now / $goal kcal';
        pct = goal > 0 ? (now / goal).clamp(0.0, 1.0) : 0.0;
        bar = c.move;
      case EntryType.rituals:
        final now = today.ritualsDone;
        final goal = today.ritualsTarget;
        label = 'Rituals today';
        right = '$now / $goal';
        pct = goal > 0 ? (now / goal).clamp(0.0, 1.0) : 0.0;
        bar = c.rituals;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppType.caption2.copyWith(
                    fontWeight: FontWeight.w600, color: c.ink3, letterSpacing: -0.06),
              ),
              Text(
                right,
                style: AppType.caption2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: over ? c.red : c.ink2,
                  letterSpacing: -0.06,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xs),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: c.fill,
              valueColor: AlwaysStoppedAnimation<Color>(bar),
            ),
          ),
        ],
      ),
    );
  }
}

/// The confirmation card shown when a Pal turn logged a meal: a nutrition-tinted
/// LOGGED header, the meal on a leaf tile with its calorie range + confidence,
/// and Undo / Edit. No progress ring — nutrition has no daily calorie target.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.action,
    required this.undone,
    this.onUndo,
    this.onEdit,
  });

  final LogMealAction action;
  final bool undone;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.nutrition;
    final slot = action.slot ?? 'Meal';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const PalAvatar(size: 24, glyphSize: 11),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.84),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  topRight: Radius.circular(Radii.lg),
                  bottomRight: Radius.circular(Radii.lg),
                  bottomLeft: Radius.circular(Radii.xs),
                ),
                border: Border.all(color: c.hair, width: 0.5),
                boxShadow: [
                  BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LOGGED header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.md, Spacing.md, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: AppIcon('checkmark', size: 9, color: c.onAccent),
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'LOGGED',
                          style: AppType.caption2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Meal row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: c.nutritionTint,
                              borderRadius: BorderRadius.circular(Radii.md)),
                          alignment: Alignment.center,
                          child: AppIcon('leaf.fill', size: 18, color: color),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.subhead.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                  letterSpacing: -0.24,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '$slot · ${action.confidence.label}',
                                style: AppType.caption.copyWith(
                                    color: c.ink3, letterSpacing: -0.08),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          '${action.cal.lo}–${action.cal.hi} cal',
                          style: AppType.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Undo / Edit (or the undone marker)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.hair, width: 0.5)),
                    ),
                    child: undone
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: Spacing.md),
                            child: Center(
                              child: Text(
                                'Undone',
                                style: AppType.footnote.copyWith(
                                    color: c.ink3, letterSpacing: -0.08),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _CardAction(
                                    label: 'Undo', color: c.red, onTap: onUndo),
                              ),
                              Container(width: 0.5, height: 38, color: c.hair),
                              Expanded(
                                child: _CardAction(
                                    label: 'Edit', color: c.accent, onTap: onEdit),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the LogCard footer — a flat, full-height text button.
class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          child: Center(
            child: Text(
              label,
              style: AppType.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three pulsing dots (the LLM-loading indicator), waved out of phase.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.xs),
            _Dot(t: _ctrl.value, phase: i / 3, color: c.ink3),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.t, required this.phase, required this.color});

  final double t;
  final double phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = ((t + phase) % 1.0) * 2 * math.pi;
    final lift = 0.5 - 0.5 * math.cos(v);
    return Opacity(
      opacity: 0.35 + 0.65 * lift,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The always-visible bottom composer: a rounded fill text field plus a circular
/// send button (accent when there's input, fill otherwise).
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.hasText,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expanded;
  final bool hasText;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canSend = enabled && hasText;
    final hint =
        expanded ? 'Reply or log something…' : 'Log a coffee, ask about your week…';

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: expanded
            ? Border(top: BorderSide(color: c.hair, width: 0.5))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, Spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 38, maxHeight: 100),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              decoration: BoxDecoration(
                color: c.fill,
                borderRadius: BorderRadius.circular(Radii.xl),
              ),
              // The field sizes to its content (clamped to the 38px minHeight
              // above); no Align wrapper — an Align with no heightFactor would
              // expand to the 100px maxHeight and inflate the pill.
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                cursorColor: c.accent,
                onSubmitted: enabled ? (_) => onSend() : null,
                style: AppType.subhead.copyWith(color: c.ink, letterSpacing: -0.24),
                decoration: InputDecoration(
                  isDense: true,
                  // Match the handoff textarea's ~10px vertical padding;
                  // without this, InputBorder.none's large default padding
                  // inflates the pill past the 38px send button. Horizontal
                  // padding comes from the wrapping container.
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: AppType.subhead.copyWith(
                      color: c.ink3, letterSpacing: -0.24),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          PressScale(
            semanticLabel: 'Send',
            onTap: canSend ? onSend : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hasText ? c.accent : c.fill,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIcon(
                'arrow.up',
                size: 17,
                color: hasText ? c.onAccent : c.ink4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
