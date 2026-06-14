import 'package:flutter/material.dart';
// `Provider` (the email-account enum) collides with riverpod's legacy
// `Provider`; we only need riverpod's Consumer types here, so hide the latter.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/gmail_glyph.dart';
import '../../widgets/inset_section.dart';
import 'email_nav.dart';

/// Screen 17 — App-password setup (mock).
///
/// An account form (email + 16-char app password that auto-formats into groups
/// of 4), a "Generate a Gmail app password" how-to card, a Test-connection
/// button cycling idle/testing/success/error, and an Advanced collapsible
/// (IMAP host/port/encryption). Save is gated on a successful test; on Save we
/// connect and replace this route with the Dashboard.
///
/// Test lifecycle + Save-gating live in [EmailSetupController]; the form text
/// is owned locally.
class EmailSetupScreen extends ConsumerStatefulWidget {
  const EmailSetupScreen({super.key});

  @override
  ConsumerState<EmailSetupScreen> createState() => _EmailSetupScreenState();
}

class _EmailSetupScreenState extends ConsumerState<EmailSetupScreen> {
  final _email = TextEditingController(text: 'mira@gmail.com');
  final _password = TextEditingController();
  final _host = TextEditingController(text: 'imap.gmail.com');
  final _port = TextEditingController(text: '993');
  bool _advancedOpen = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  EmailAccount _buildAccount() => EmailAccount(
        address: _email.text.trim(),
        provider: Provider.gmail,
        // the service owns the keychain reference (set on connect)
        appPasswordRef: '',
        imapHost: _host.text.trim().isEmpty ? 'imap.gmail.com' : _host.text.trim(),
        imapPort: int.tryParse(_port.text.trim()) ?? 993,
      );

  void _runTest() {
    ref
        .read(emailSetupControllerProvider.notifier)
        .testConnection(_buildAccount(), _password.text);
  }

  Future<void> _save() async {
    try {
      await ref
          .read(emailSetupControllerProvider.notifier)
          .save(_buildAccount(), _password.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed — check the password')),
      );
      return;
    }
    if (!mounted) return;
    // Replace Setup with the Dashboard so back from the dashboard returns to
    // the profile/intro entry rather than the setup form.
    context.pushReplacementNamed('emailDashboard');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final setup = ref.watch(emailSetupControllerProvider);

    // Material (not a bare ColoredBox) so the form's TextFields have the
    // Material ancestor they require; it paints the same background.
    return Material(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          EmailNavBar(
            title: 'Gmail setup',
            leadingLabel: 'Cancel',
            showLeadingChevron: false,
            onLeading: () => context.pop(),
            trailingLabel: 'Save',
            trailingEnabled: setup.canSave,
            onTrailing: _save,
          ),

          // --- Account form --------------------------------------------------
          InsetSection(
            header: 'Account',
            footer:
                'Use the Gmail address whose inbox contains your bank alert emails.',
            children: [
              _FormRow(
                label: 'Email',
                child: TextField(
                  controller: _email,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _fieldDecoration(),
                  style: AppType.subhead.copyWith(color: c.ink, letterSpacing: -0.24),
                ),
              ),
              _FormRow(
                label: 'App password',
                last: true,
                child: TextField(
                  controller: _password,
                  textAlign: TextAlign.right,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: const [AppPasswordFormatter()],
                  onChanged: (_) => ref
                      .read(emailSetupControllerProvider.notifier)
                      .markDirty(),
                  decoration: _fieldDecoration(hint: 'xxxx xxxx xxxx xxxx'),
                  style: AppFonts.mono(size: 15, color: c.ink),
                ),
              ),
            ],
          ),

          // --- How-to card ---------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, Spacing.lg),
            child: _HowToCard(),
          ),

          // --- Test connection -----------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, Spacing.lg),
            child: _TestButton(state: setup.test, onTap: _runTest),
          ),

          // --- Advanced IMAP -------------------------------------------------
          InsetSection(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: c.fill,
                            borderRadius: BorderRadius.circular(Radii.sm)),
                        alignment: Alignment.center,
                        child:
                            AppIcon('gearshape.fill', size: 15, color: c.ink2),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IMAP server',
                                style: AppType.subhead.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: c.ink,
                                    letterSpacing: -0.24)),
                            const SizedBox(height: 1), // tight 1px gap — keep
                            Text('imap.gmail.com · port 993 · SSL',
                                style: AppType.caption.copyWith(
                                    color: c.ink3,
                                    letterSpacing: -0.08)),
                          ],
                        ),
                      ),
                      AppIcon(_advancedOpen ? 'chevron.down' : 'chevron.right',
                          size: 13, color: c.ink4),
                    ],
                  ),
                ),
              ),
              if (_advancedOpen) ...[
                Container(height: 0.5, color: c.hair),
                _FormRow(
                  label: 'Host',
                  child: TextField(
                    controller: _host,
                    textAlign: TextAlign.right,
                    autocorrect: false,
                    decoration: _fieldDecoration(),
                    style:
                        AppType.subhead.copyWith(color: c.ink, letterSpacing: -0.24),
                  ),
                ),
                _FormRow(
                  label: 'Port',
                  child: TextField(
                    controller: _port,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(),
                    style:
                        AppType.subhead.copyWith(color: c.ink, letterSpacing: -0.24),
                  ),
                ),
                _FormRow(
                  label: 'Encryption',
                  last: true,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('SSL / TLS',
                        style: AppType.subhead.copyWith(
                            color: c.ink, letterSpacing: -0.24)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    final c = context.colors;
    return InputDecoration(
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintText: hint,
      hintStyle: AppType.subhead.copyWith(color: c.ink4, letterSpacing: -0.24),
    );
  }
}

/// A label + right-aligned field row inside an [InsetSection].
class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.child, this.last = false});
  final String label;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          SizedBox(
            width: 100, // fixed label-column width — keep literal
            child: Text(label,
                style:
                    AppType.subhead.copyWith(color: c.ink2, letterSpacing: -0.24)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The "Generate a Gmail app password" instruction card (3 steps + open link).
class _HowToCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stepStyle = AppType.footnote
        .copyWith(color: c.ink2, letterSpacing: -0.1, height: 1.5);
    // step 2 splits out the URL so it can read as an accent underlined link
    final steps = <InlineSpan>[
      TextSpan(text: 'Turn on 2-Step Verification in your Google Account.'),
      TextSpan(children: [
        const TextSpan(text: 'Open '),
        TextSpan(
          text: 'myaccount.google.com/apppasswords',
          style: stepStyle.copyWith(
              color: c.accent, decoration: TextDecoration.underline),
        ),
        const TextSpan(text: '.'),
      ]),
      TextSpan(
          text: 'Create an app password labeled "ExpensePal" — paste the '
              '16 characters above.'),
    ];
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.hair, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GmailGlyph(size: 18),
              const SizedBox(width: Spacing.sm),
              Text('Generate a Gmail app password',
                  style: AppType.footnote.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.1)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}.',
                      style: AppType.footnote
                          .copyWith(color: c.ink3, letterSpacing: -0.1)),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: stepStyle, children: [steps[i]]),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
                color: c.fill, borderRadius: BorderRadius.circular(Radii.pill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('square.and.arrow.up', size: 12, color: c.accent),
                const SizedBox(width: Spacing.sm),
                Text('Open Google app passwords',
                    style: AppType.footnote.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                        letterSpacing: -0.08)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Test-connection button, styled per [TestState].
class _TestButton extends StatelessWidget {
  const _TestButton({required this.state, required this.onTap});
  final TestState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final testing = state == TestState.testing;
    final ok = state == TestState.success;
    final error = state == TestState.error;

    final (Widget icon, String label, Color fg, Color bg) = switch (state) {
      TestState.testing => (
          _Spinner(color: c.ink2),
          'Testing IMAP…',
          c.ink,
          c.surface,
        ),
      TestState.success => (
          AppIcon('checkmark', size: 14, color: c.move),
          'Connected to imap.gmail.com',
          c.move,
          c.move.withValues(alpha: 0.13),
        ),
      TestState.error => (
          AppIcon('xmark', size: 14, color: c.red),
          'Connection failed — check the password',
          c.red,
          c.red.withValues(alpha: 0.13),
        ),
      TestState.idle => (
          AppIcon('bolt.fill', size: 14, color: c.accent),
          'Test connection',
          c.ink,
          c.surface,
        ),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: testing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md), // 13→12
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: ok
                ? c.move.withValues(alpha: 0.27)
                : error
                    ? c.red.withValues(alpha: 0.27)
                    : c.hair,
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: Spacing.sm),
            Text(label,
                style: AppType.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fg,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

/// A small indeterminate spinner (matches the JSX testing glyph).
class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

