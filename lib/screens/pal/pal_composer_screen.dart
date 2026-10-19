import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analysis/area.dart';
import '../../analysis/spend_habits.dart' show HabitPick;
import '../../controllers/pal_composer_controller.dart';
import '../../controllers/pal_findings_controller.dart';
import '../../controllers/pal_suggestions_controller.dart';
import '../../controllers/providers.dart';
import '../../controllers/spend_habits_controller.dart';
import '../../controllers/start_workout_controller.dart';
import '../../controllers/weekly_plan_controller.dart';
import '../../models/models.dart';
import '../../services/pal/coffee_starter.dart';
import '../../services/services.dart';
import '../../theme/theme.dart';
import '../../util/format.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pal_ask_bar.dart' show isYouPath, palPlaceholderFor;
import '../../widgets/pal_label.dart';
import '../../widgets/press_scale.dart';
import 'pal_composer_turns.dart';

const double _expandedShare = 0.86;
const double _maxShare = 0.92;
const double _grabberWidth = 36;
const double _grabberHeight = 5;
const double _minTap = 44;
const double _closeGlyph = 22;
const double _chipHeight = 32;
const double _chipIcon = 16;
const double _inputHeight = 52;
const double _inputMaxHeight = 120;
const double _sendSize = 44;
const double _sendGlyph = 20;
const double _pillPadV = 10;
const double _skeletonLine = 15;
const int _maxHabitStarters = 2;
const int _maxFindingStarters = 3;
const Duration _resize = Duration(milliseconds: 260);
const Duration _scroll = Duration(milliseconds: 250);
const Cubic _resizeCurve = Cubic(0.22, 1, 0.36, 1);

/// The sheet's surface, for tests that check how it is drawn.
const palComposerSheetKey = Key('pal-composer-sheet');

/// The fallback chip, for a composer opened from no known screen.
const _palChip = (icon: 'sparkles', label: 'Pal');

/// The screens the context chip can name, by path prefix.
const _screenChips = {
  '/today': (icon: 'sun.max.fill', label: 'Today'),
  '/areas': (icon: 'square.grid.2x2.fill', label: 'Areas'),
  '/move': (icon: 'dumbbell.fill', label: 'Workout'),
  '/you': (icon: 'person.crop.circle.fill', label: 'You'),
};

/// The context chip for the screen at [from]. An area page names its area;
/// anything unknown falls back to Pal.
({String icon, String label}) _chipFor(String? from) {
  final segments = Uri.tryParse(from ?? '')?.pathSegments ?? const <String>[];
  if (segments.isEmpty) return _palChip;
  if (segments.first == 'areas' && segments.length > 1) {
    for (final area in Area.values) {
      if (area.name == segments[1]) return (icon: area.glyph, label: area.title);
    }
  }
  return _screenChips['/${segments.first}'] ?? _palChip;
}

/// The Pal composer: one sheet to log, ask or start anything, opened from the
/// ask bar and from Today's `Why this first`.
///
/// Idle, it offers what you could ask; once anything is sent it grows into
/// the conversation. A non-empty [seed] opens straight into the conversation
/// with that message, and [about] rides along with it as context for Pal only.
/// [from] is the path of the screen underneath, shown as the context chip
/// only: what is sent to Pal does not change. [dictate] opens it listening,
/// as the ask bar's mic does.
class PalComposerSheet extends ConsumerStatefulWidget {
  const PalComposerSheet({super.key, this.seed, this.about, this.from, this.dictate = false});

  final String? seed;
  final String? about;
  final String? from;
  final bool dictate;

  @override
  ConsumerState<PalComposerSheet> createState() => _PalComposerSheetState();
}

class _PalComposerSheetState extends ConsumerState<PalComposerSheet> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  late final SpeechService _speech = ref.read(speechServiceProvider);
  StreamSubscription<String>? _dictation;
  bool _micRefused = false;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() => setState(() {}));
    if (widget.dictate) WidgetsBinding.instance.addPostFrameCallback((_) => _toggleDictation());
  }

  @override
  void dispose() {
    _endDictation();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  PalComposerController get _controller =>
      ref.read(palComposerControllerProvider(seed: widget.seed, about: widget.about).notifier);

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _endDictation();
    _inputCtrl.clear();
    final pending = _controller.send(trimmed);
    _scrollToBottomSoon();
    final result = await pending;
    if (!mounted) return;
    // pal is unreachable and the text looks loggable: hand off to the manual
    // new entry sheet, which explains why.
    if (result == PalSendResult.offlineFallback) {
      context.pushReplacement('/entry/new?kind=expense&notice=pal-offline');
    }
  }

  /// Starts dictating into the input, or stops it. The words heard so far
  /// replace the input as they arrive; sending stays a tap, so they can be
  /// checked first.
  Future<void> _toggleDictation() async {
    if (_dictation != null) return _speech.stop();
    final ready = await _speech.ready();
    if (!mounted || _dictation != null) return;
    if (!ready) {
      setState(() => _micRefused = true);
      return;
    }
    setState(() {
      _micRefused = false;
      _dictation = _speech.listen().listen(
            (words) => _inputCtrl.value = TextEditingValue(
              text: words,
              selection: TextSelection.collapsed(offset: words.length),
            ),
            onDone: () {
              if (mounted) setState(() => _dictation = null);
            },
          );
    });
  }

  /// Drops the words still to come, so nothing refills a sent or closed input.
  void _endDictation() {
    if (_dictation == null) return;
    _dictation!.cancel();
    _dictation = null;
    _speech.stop();
  }

  void _sendStarter(_Starter starter) {
    _controller.sendStarter(starter.label, starter.payload, about: starter.about);
    _scrollToBottomSoon();
  }

  void _startWorkout() {
    context.pop();
    context.go('/move/start');
  }

  /// Reverses a logged turn, drops it, and puts its text back in the input,
  /// focused with the caret at the end, to fix.
  Future<void> _editLog(int index, int action) async {
    final text = await _controller.editLog(index, action);
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
        duration: _scroll,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(palComposerControllerProvider(seed: widget.seed, about: widget.about));

    // keep the newest turn in view as the conversation grows.
    ref.listen(palComposerControllerProvider(seed: widget.seed, about: widget.about),
        (_, _) => _scrollToBottomSoon());

    final expanded = state.expanded;
    final media = MediaQuery.of(context);
    // lift the sheet above the keyboard, and shrink its cap by the same inset
    // so the expanded sheet never runs off the top.
    final keyboard = media.viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: _resize,
        curve: _resizeCurve,
        margin: EdgeInsets.only(bottom: keyboard),
        height: expanded ? media.size.height * _expandedShare : null,
        constraints: BoxConstraints(maxHeight: media.size.height * _maxShare - keyboard),
        child: DecoratedBox(
          key: palComposerSheetKey,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onClose: _close),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _ContextChip(chip: _chipFor(widget.from)),
                  ),
                  const SizedBox(height: Spacing.lg),
                  if (expanded)
                    Expanded(
                      child: _Conversation(
                        controller: _scrollCtrl,
                        messages: state.messages,
                        isLoading: state.isLoading,
                        onUndo: _controller.undo,
                        onEdit: _editLog,
                      ),
                    )
                  else
                    Flexible(
                      child: _IdleBody(
                        onYou: isYouPath(widget.from),
                        onStartWorkout: _startWorkout,
                        onSendStarter: _sendStarter,
                      ),
                    ),
                  const SizedBox(height: Spacing.lg),
                  _Input(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    hint: _micRefused
                        ? 'Allow the mic and speech recognition in Settings'
                        : expanded
                            ? 'Ask a follow-up'
                            : palPlaceholderFor(widget.from),
                    canSend: !state.isLoading && _inputCtrl.text.trim().isNotEmpty,
                    enabled: !state.isLoading,
                    onSend: () => _send(_inputCtrl.text),
                    dictating: _dictation != null,
                    // the mic takes Send's place while there is nothing to send.
                    onDictate: _speech.supported &&
                            (_dictation != null || _inputCtrl.text.trim().isEmpty)
                        ? _toggleDictation
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The grabber, Pal's label and Close.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: _grabberWidth,
            height: _grabberHeight,
            decoration: BoxDecoration(
              color: c.track,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
        ),
        Row(
          children: [
            const Expanded(
              child: Align(alignment: AlignmentDirectional.centerStart, child: PalLabel()),
            ),
            PressScale(
              semanticLabel: 'Close',
              onTap: onClose,
              child: SizedBox(
                width: _minTap,
                height: _minTap,
                child: Center(child: AppIcon('xmark', size: _closeGlyph, color: c.ink)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Names the screen the composer was opened over. Display only.
class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.chip});

  final ({String icon, String label}) chip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _chipHeight),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(chip.icon, size: _chipIcon, color: c.ink2),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text(chip.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: c.ink2)),
          ),
        ],
      ),
    );
  }
}

/// What you could ask: Pal's pick to start, then the expenses you habitually
/// log around now, then Pal's starters, or the static ones when Pal has none.
/// Shown until anything is sent.
class _IdleBody extends ConsumerWidget {
  const _IdleBody({required this.onYou, required this.onStartWorkout, required this.onSendStarter});

  /// Opened from You or a sub-screen of it, where the starters are Pal's
  /// findings' own questions while there are any.
  final bool onYou;
  final VoidCallback onStartWorkout;
  final ValueChanged<_Starter> onSendStarter;

  /// The fallback starters, priced in [currency].
  static List<_Starter> _starters(Currency currency) {
    final coffee = coffeeStarter(currency);
    return [
      _Starter(coffee.label, payload: coffee.entry),
      const _Starter(
        'Finished morning pages',
        payload: StarterEntry(type: EntryType.rituals, title: 'Morning pages'),
      ),
      // an open prompt, with nothing to log offline.
      const _Starter('How’s my week so far?'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final findings = onYou ? ref.watch(palFindingsControllerProvider).asData?.value : null;
    if (findings != null && findings.isNotEmpty) {
      return _StarterList(children: [
        for (final f in findings.take(_maxFindingStarters))
          _Pill(
            label: f.question,
            onTap: () => onSendStarter(_Starter(f.question, about: f.palNote)),
          ),
      ]);
    }
    final currency = ref.watch(appSettingsControllerProvider.select((s) => s.currency));
    // once today's workout is settled, Pal's pick would be a second session.
    final settled =
        ref.watch(weeklyPlanControllerProvider).value?.today?.settled ?? false;
    final pick = settled ? null : ref.watch(palPickControllerProvider).asData?.value;
    final suggestions = ref.watch(palSuggestionsProvider(SuggestionSurface.composer));
    // the static list is the offline or empty answer. loading gets its own
    // skeleton: the two look alike, so a pending fetch used to read as Pal's.
    final palStarters = suggestions.maybeWhen(
      data: (list) => list.isEmpty
          ? null
          : [for (final s in list) _Starter(s.label, payload: s.entry)],
      orElse: () => null,
    );
    final loading = suggestions.isLoading && palStarters == null;
    final habits = ref.watch(composerHabitsProvider).asData?.value;
    final predicted = [
      for (final h in (habits?.picks ?? const <HabitPick>[]).take(_maxHabitStarters))
        _Starter(
          '${h.title}, ${formatCurrency(h.averageAmount, currency)}',
          payload: StarterEntry(
            type: EntryType.money,
            title: h.title,
            amount: -h.averageAmount, // negative = expense
            category: h.category,
          ),
        ),
    ];
    // what is already logged or predicted, so no chip offers it twice.
    final taken = {
      ...?habits?.logged,
      for (final s in predicted) s.payload!.title.toLowerCase(),
    };
    bool untaken(_Starter s) =>
        s.payload == null || !taken.contains(s.payload!.title.trim().toLowerCase());
    return _StarterList(children: [
      _Pill(
        label: pick == null ? 'Start a workout' : 'Start ${pick.title}',
        onTap: onStartWorkout,
      ),
      for (final starter in predicted)
        _Pill(label: starter.label, onTap: () => onSendStarter(starter)),
      if (loading)
        const _StarterSkeletons(key: Key('starter-skeleton'))
      else
        for (final starter in (palStarters ?? _starters(currency)).where(untaken))
          _Pill(label: starter.label, onTap: () => onSendStarter(starter)),
    ]);
  }
}

/// `You could ask`, then the starters.
class _StarterList extends StatelessWidget {
  const _StarterList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.sm,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Text('You could ask', style: AppType.label.copyWith(color: context.colors.ink3)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Starter {
  const _Starter(this.label, {this.payload, this.about});

  final String label;

  /// Context for Pal only, as a seed's [PalComposerSheet.about] is.
  final String? about;

  /// Logged locally when Pal is offline. Null for open prompts, which have
  /// nothing to log.
  final StarterEntry? payload;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minTap),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: _pillPadV),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(label, style: AppType.subhead.copyWith(color: c.ink)),
      ),
    );
  }
}

/// Pill-shaped placeholders while the first suggestions load. Not the static
/// starters: those are the offline answer, and showing them here made a
/// pending fetch look like Pal had replied.
class _StarterSkeletons extends StatelessWidget {
  const _StarterSkeletons({super.key});

  /// ragged widths, so the placeholders read as text, not three equal bars.
  static const _widths = [160.0, 120.0, 140.0];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.sm,
      children: [
        for (final width in _widths)
          Container(
            width: width,
            height: _minTap,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Container(
              height: _skeletonLine,
              decoration: BoxDecoration(
                color: c.track,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
      ],
    );
  }
}

/// The conversation, newest last, with `…` while Pal is thinking.
class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.controller,
    required this.messages,
    required this.isLoading,
    required this.onUndo,
    required this.onEdit,
  });

  final ScrollController controller;
  final List<PalMessage> messages;
  final bool isLoading;
  final void Function(int index, int action) onUndo;
  final void Function(int index, int action) onEdit;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isLoading ? 1 : 0);
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.lg),
      itemBuilder: (context, i) {
        if (i == messages.length) return const ComposerThinking();
        return ComposerTurn(
          message: messages[i],
          onUndo: (a) => onUndo(i, a),
          onEdit: (a) => onEdit(i, a),
        );
      },
    );
  }
}

/// The text field and Send, or the mic in Send's place.
class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.canSend,
    required this.enabled,
    required this.onSend,
    required this.dictating,
    this.onDictate,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool canSend;
  final bool enabled;
  final VoidCallback onSend;
  final bool dictating;

  /// Starts or stops dictation. Null shows Send instead.
  final VoidCallback? onDictate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _inputHeight, maxHeight: _inputMaxHeight),
      padding: const EdgeInsetsDirectional.only(start: Spacing.xl, end: Spacing.xs),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        spacing: Spacing.sm,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              cursorColor: c.ink,
              onSubmitted: enabled ? (_) => onSend() : null,
              style: AppType.callout.copyWith(color: c.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppType.callout.copyWith(color: c.ink3),
              ),
            ),
          ),
          if (onDictate case final onDictate?)
            _RoundButton(
              label: dictating ? 'Stop dictating' : 'Dictate',
              glyph: dictating ? 'stop.fill' : 'mic',
              onTap: dictating || enabled ? onDictate : null,
            )
          else
            _RoundButton(label: 'Send', glyph: 'arrow.up', onTap: canSend ? onSend : null),
        ],
      ),
    );
  }
}

/// The input's trailing button.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.glyph, this.onTap});

  final String label;
  final String glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // labelled even while it cannot act, so it is never a mystery button.
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: _sendSize,
          height: _sendSize,
          decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: AppIcon(glyph, size: _sendGlyph, color: c.bg),
        ),
      ),
    );
  }
}
