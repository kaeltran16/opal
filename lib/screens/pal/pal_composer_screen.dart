import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/pal_composer_controller.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
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

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  PalComposerController get _controller =>
      ref.read(palComposerControllerProvider(seed: widget.seed).notifier);

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputCtrl.clear();
    _controller.send(trimmed);
    _scrollToBottomSoon();
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                  ),
                )
              else
                _CompactBody(onSendChip: _send),
              _Composer(
                controller: _inputCtrl,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: c.hair,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Row(
            children: [
              const _PalAvatar(size: 32, glyphSize: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pal',
                      style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w600,
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
                        const SizedBox(width: 5),
                        Text(
                          'Log, ask, or start anything',
                          style: AppFonts.sf(
                            size: 12,
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
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: AppIcon('xmark', size: 13, color: c.ink3),
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
class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.onSendChip});

  final ValueChanged<String> onSendChip;

  static const _starters = <_Starter>[
    _Starter('dollarsign.circle.fill', 'money', 'Verve coffee, \$5'),
    _Starter('sparkles', 'rituals', 'Finished morning pages'),
    _Starter('chart.bar.fill', 'accent', "How's my week so far?"),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.moveTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.move,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon('play.fill', size: 14,
                        color: const Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start a workout',
                          style: AppFonts.sf(
                            size: 15,
                            weight: FontWeight.w600,
                            color: c.ink,
                            letterSpacing: -0.24,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "Jump into a routine — I'll track it",
                          style: AppFonts.sf(
                            size: 12,
                            color: c.ink3,
                            letterSpacing: -0.08,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIcon('chevron.right', size: 13, color: c.ink4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              'TRY SAYING',
              style: AppFonts.sf(
                size: 11,
                weight: FontWeight.w700,
                color: c.ink3,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (var i = 0; i < _starters.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _StarterChip(
              starter: _starters[i],
              onTap: () => onSendChip(_starters[i].label),
            ),
          ],
        ],
      ),
    );
  }
}

class _Starter {
  const _Starter(this.icon, this.colorToken, this.label);

  final String icon;
  final String colorToken;
  final String label;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.hair, width: 0.5),
        ),
        child: Row(
          children: [
            AppIcon(starter.icon, size: 15, color: c.forType(starter.colorToken)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                starter.label,
                style: AppFonts.sf(
                  size: 14,
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
  });

  final ScrollController controller;
  final List<PalMessage> messages;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isLoading ? 1 : 0);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (isLoading && i == itemCount - 1) {
          return const _Bubble.typing();
        }
        return _Bubble(message: messages[i]);
      },
    );
  }
}

/// A chat bubble. User → right, accent fill, white ink (radius 18 / 5 bottom-
/// right). Assistant → left, fill bg, ink (radius 18 / 5 bottom-left) preceded
/// by a 24×24 gradient avatar. The [_Bubble.typing] variant shows pulsing dots.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message}) : isTyping = false;
  const _Bubble.typing()
      : message = null,
        isTyping = true;

  final PalMessage? message;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUser = !isTyping && message!.role == PalRole.user;
    const radius = Radius.circular(18);
    const tail = Radius.circular(5);
    final shape = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isUser ? radius : tail,
      bottomRight: isUser ? tail : radius,
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isUser ? c.accent : c.fill,
        borderRadius: shape,
      ),
      child: isTyping
          ? const _TypingDots()
          : Text(
              message!.text,
              style: AppFonts.sf(
                size: 15,
                color: isUser ? const Color(0xFFFFFFFF) : c.ink,
                letterSpacing: -0.24,
                height: 1.4,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _PalAvatar(size: 24, glyphSize: 11),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
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
            if (i > 0) const SizedBox(width: 5),
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

/// The 135° gradient (accent → rituals) circle with a white sparkles glyph.
class _PalAvatar extends StatelessWidget {
  const _PalAvatar({required this.size, required this.glyphSize});

  final double size;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.rituals],
        ),
      ),
      alignment: Alignment.center,
      child: AppIcon('sparkles', size: glyphSize, color: const Color(0xFFFFFFFF)),
    );
  }
}

/// The always-visible bottom composer: a rounded fill text field plus a circular
/// send button (accent when there's input, fill otherwise).
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.expanded,
    required this.hasText,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 38, maxHeight: 100),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.fill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  cursorColor: c.accent,
                  onSubmitted: enabled ? (_) => onSend() : null,
                  style: AppFonts.sf(size: 15, color: c.ink, letterSpacing: -0.24),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: AppFonts.sf(
                        size: 15, color: c.ink3, letterSpacing: -0.24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                color: hasText ? const Color(0xFFFFFFFF) : c.ink4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
