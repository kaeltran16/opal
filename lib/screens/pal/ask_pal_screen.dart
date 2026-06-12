import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/ask_pal_controller.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/nav_bar.dart';

/// Screen 05 — Ask Pal chat (mock).
///
/// Large-title nav ("Ask Pal" + subtitle), a scrollable message list (user
/// bubbles right/accent, assistant bubbles left/surface, radius 18), a 3-dot
/// typing indicator while awaiting, an input bar (rounded field + circular
/// send), and empty-state suggestion chips. Wired to [AskPalController], which
/// calls [PalService.chat] (the mock returns on-brand canned replies with fake
/// latency). State resets per session (the controller auto-disposes).
class AskPalScreen extends ConsumerStatefulWidget {
  const AskPalScreen({super.key});

  @override
  ConsumerState<AskPalScreen> createState() => _AskPalScreenState();
}

class _AskPalScreenState extends ConsumerState<AskPalScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  static const _suggestions = <String>[
    'Why was Friday expensive?',
    'How am I doing this week?',
    'Suggest an evening routine',
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputCtrl.clear();
    ref.read(askPalControllerProvider.notifier).send(trimmed);
    _scrollToBottomSoon();
  }

  /// Scrolls to the newest message after the frame the new content lays out in.
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
    final state = ref.watch(askPalControllerProvider);

    // Keep pinned to the latest message whenever the transcript grows.
    ref.listen(askPalControllerProvider, (_, _) => _scrollToBottomSoon());

    final itemCount = state.messages.length + (state.isLoading ? 1 : 0);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: state.isEmpty
                  ? _EmptyState(
                      suggestions: _suggestions,
                      onTap: _send,
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: itemCount,
                      itemBuilder: (context, i) {
                        if (state.isLoading && i == itemCount - 1) {
                          return const _TypingIndicator();
                        }
                        return _Bubble(
                          message: state.messages[i],
                          onUndo: () =>
                              ref.read(askPalControllerProvider.notifier).undo(i),
                        );
                      },
                    ),
            ),
            _InputBar(
              controller: _inputCtrl,
              enabled: !state.isLoading,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Large-title nav: back affordance, "Ask Pal", and a quiet subtitle.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NavAction(
                icon: 'chevron.left',
                onTap: () => context.pop(),
                semanticLabel: 'Back',
              ),
              const NavIconButton(
                name: 'ellipsis',
                semanticLabel: 'More options',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask Pal',
                  style: AppFonts.sf(
                    size: 34,
                    weight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: 0.37,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your tracking companion',
                  style: AppFonts.sf(
                    size: 15,
                    color: c.ink3,
                    letterSpacing: -0.24,
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

/// A single chat bubble. User → right, accent fill, white ink. Assistant →
/// left, surface fill, primary ink. Radius 18 with a tucked tail corner.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onUndo});

  final PalMessage message;

  /// Reverses this turn's auto-applied actions. Shown only on assistant
  /// messages that applied something and haven't been undone.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUser = message.role == PalRole.user;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser ? c.accent : c.surface;
    final fg = isUser ? const Color(0xFFFFFFFF) : c.ink;
    const radius = Radius.circular(18);
    final shape = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isUser ? radius : const Radius.circular(4),
      bottomRight: isUser ? const Radius.circular(4) : radius,
    );
    final showUndo = message.actions.isNotEmpty && !message.undone;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: bg, borderRadius: shape),
                child: Text(
                  message.text,
                  style: AppFonts.sf(
                    size: 15,
                    color: fg,
                    letterSpacing: -0.24,
                    height: 1.4,
                  ),
                ),
              ),
              if (showUndo)
                GestureDetector(
                  onTap: onUndo,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon('arrow.uturn.backward', size: 12, color: c.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Undo',
                          style: AppFonts.sf(
                            size: 13,
                            weight: FontWeight.w600,
                            color: c.accent,
                            letterSpacing: -0.08,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (message.undone)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6),
                  child: Text(
                    'Undone',
                    style: AppFonts.sf(
                      size: 13,
                      color: c.ink3,
                      letterSpacing: -0.08,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An assistant-side bubble showing three pulsing dots while a reply is pending.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: c.hair, width: 0.5),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    _Dot(t: _ctrl.value, phase: i / 3, color: c.ink3),
                  ],
                ],
              );
            },
          ),
        ),
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
    // A wave: each dot peaks at a different point in the cycle.
    final v = ((t + phase) % 1.0) * 2 * math.pi;
    final lift = 0.5 - 0.5 * math.cos(v);
    return Opacity(
      opacity: 0.35 + 0.65 * lift,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The empty conversation state: a friendly prompt plus tappable suggestion
/// chips that seed the first message.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: AppIcon('sparkles', size: 28, color: c.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'Hi there',
              style: AppFonts.sf(
                size: 20,
                weight: FontWeight.w600,
                color: c.ink,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 6),
            // verbatim handoff empty-state copy ({name} → "there", no name field yet)
            Text(
              "I'm Pal — ask me anything about your money, workouts, or routines. "
              "Or just tell me what you did and I'll log it.",
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 15, color: c.ink3, letterSpacing: -0.24),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'TRY ASKING',
                  style: AppFonts.sf(
                    size: 12,
                    weight: FontWeight.w600,
                    color: c.ink3,
                    letterSpacing: -0.08,
                  ),
                ),
              ),
            ),
            for (final s in suggestions) ...[
              _SuggestionChip(label: s, onTap: () => onTap(s)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.sf(
                  size: 15,
                  weight: FontWeight.w500,
                  color: c.ink,
                  letterSpacing: -0.24,
                ),
              ),
            ),
            AppIcon('arrow.up.right', size: 14, color: c.ink3),
          ],
        ),
      ),
    );
  }
}

/// The bottom input bar: a rounded fill field plus a circular accent send
/// button. Send is disabled while a reply is pending.
class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canSend = widget.enabled && _hasText;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.hair, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      cursorColor: c.accent,
                      onSubmitted: widget.enabled ? widget.onSend : null,
                      style: AppFonts.sf(
                          size: 15, color: c.ink, letterSpacing: -0.24),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Ask about your day or log something…',
                        hintStyle: AppFonts.sf(
                            size: 15, color: c.ink3, letterSpacing: -0.24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canSend
                    ? () => widget.onSend(widget.controller.text)
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: canSend ? c.accent : c.fill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    'arrow.up.right',
                    size: 18,
                    color: canSend ? const Color(0xFFFFFFFF) : c.ink4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
