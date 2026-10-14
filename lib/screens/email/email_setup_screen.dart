import 'package:flutter/material.dart';
// `Provider` (the email-account enum) collides with riverpod's legacy
// `Provider`; we only need riverpod's Consumer types here, so hide the latter.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:go_router/go_router.dart';

import '../../controllers/email_sync_controller.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/press_scale.dart';
import '../you/sub_screen.dart';
import 'email_nav.dart';
import 'sender_filter_section.dart';

const double _pillHeight = 48;
const double _minTap = 44;
const double _hairline = 1;
const double _labelColumn = 112;
const double _pillIcon = 16;
const double _spinnerStroke = 2;
const String _defaultHost = 'imap.gmail.com';
const int _defaultPort = 993;
const String _testFailed = 'Connection failed. Check the password.';

/// Gmail setup: the account form (email and a 16-char app password that
/// auto-formats into groups of 4), the sender allowlist, how to make an app
/// password, Test connection, and an Advanced IMAP section. Save is gated on a
/// successful test; on Save we connect and replace this route with the
/// Dashboard.
///
/// Test lifecycle and Save-gating live in [EmailSetupController]; the form text
/// is owned locally.
class EmailSetupScreen extends ConsumerStatefulWidget {
  const EmailSetupScreen({super.key});

  @override
  ConsumerState<EmailSetupScreen> createState() => _EmailSetupScreenState();
}

class _EmailSetupScreenState extends ConsumerState<EmailSetupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController(text: _defaultHost);
  final _port = TextEditingController(text: '$_defaultPort');
  bool _advancedOpen = false;

  // Starting allowlist — the senders whose emails carry the user's receipts.
  // Editable in the UI below; an empty list scans the whole inbox.
  static const _defaultSenders = [
    'no-reply@grab.com',
    'info@card.vib.com.vn',
    'info@mail.shopee.vn',
  ];
  final List<String> _senders = [..._defaultSenders];

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
        imapHost: _host.text.trim().isEmpty ? _defaultHost : _host.text.trim(),
        imapPort: int.tryParse(_port.text.trim()) ?? _defaultPort,
        senderFilters: List.of(_senders),
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
        const SnackBar(content: Text(_testFailed)),
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
    final quiet = AppType.subhead.copyWith(color: c.ink3);

    return SubScreen(
      backLabel: 'Email sync',
      eyebrow: 'Gmail',
      title: 'Gmail setup',
      children: [
        const SizedBox(height: Spacing.xxl),
        const _Heading('Account'),
        const SizedBox(height: Spacing.sm),
        _FormRow(
          label: 'Email',
          child: TextField(
            controller: _email,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _fieldDecoration(hint: 'you@gmail.com'),
            style: AppType.callout.copyWith(color: c.ink),
          ),
        ),
        _FormRow(
          label: 'App password',
          child: TextField(
            controller: _password,
            textAlign: TextAlign.right,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: const [AppPasswordFormatter()],
            onChanged: (_) =>
                ref.read(emailSetupControllerProvider.notifier).markDirty(),
            decoration: _fieldDecoration(hint: 'xxxx xxxx xxxx xxxx'),
            style: AppType.callout.copyWith(
                color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text('Use the Gmail address whose inbox contains your bank alert emails.',
            style: quiet),
        const SizedBox(height: Spacing.xxxl),
        SenderFilterSection(
          senders: _senders,
          onChanged: (list) => setState(() => _senders..clear()..addAll(list)),
        ),
        const SizedBox(height: Spacing.xxxl),
        const _HowTo(),
        const SizedBox(height: Spacing.xxl),
        _TestPill(state: setup.test, onTap: _runTest),
        const SizedBox(height: Spacing.xxxl),
        _AdvancedRow(
          open: _advancedOpen,
          onTap: () => setState(() => _advancedOpen = !_advancedOpen),
        ),
        if (_advancedOpen) ...[
          _FormRow(
            label: 'Host',
            child: TextField(
              controller: _host,
              textAlign: TextAlign.right,
              autocorrect: false,
              decoration: _fieldDecoration(),
              style: AppType.callout.copyWith(color: c.ink),
            ),
          ),
          _FormRow(
            label: 'Port',
            child: TextField(
              controller: _port,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(),
              style: AppType.callout.copyWith(color: c.ink),
            ),
          ),
          _FormRow(
            label: 'Encryption',
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('SSL / TLS', style: AppType.callout.copyWith(color: c.ink)),
            ),
          ),
        ],
        const SizedBox(height: Spacing.xxl),
        _SavePill(onTap: setup.canSave ? _save : null),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: AppType.callout.copyWith(color: context.colors.ink3),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text, style: AppType.headline.copyWith(color: context.colors.ink)),
      );
}

/// A label and a right-aligned field under a hairline.
class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _minTap),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hair, width: _hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _labelColumn,
            child: Text(label, style: AppType.callout.copyWith(color: c.ink2)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// How to make a Gmail app password, as a plain section.
class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stepStyle = AppType.subhead.copyWith(color: c.ink2);
    final steps = <InlineSpan>[
      const TextSpan(text: 'Turn on 2-Step Verification in your Google Account.'),
      TextSpan(children: [
        const TextSpan(text: 'Open '),
        TextSpan(
          text: 'myaccount.google.com/apppasswords',
          style: stepStyle.copyWith(color: c.ink, decoration: TextDecoration.underline),
        ),
        const TextSpan(text: '.'),
      ]),
      const TextSpan(
          text: 'Create an app password labeled "Opal" — paste the 16 characters above.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Generate a Gmail app password'),
        const SizedBox(height: Spacing.sm),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}.', style: AppType.subhead.copyWith(color: c.ink3)),
                const SizedBox(width: Spacing.sm),
                Expanded(child: Text.rich(TextSpan(style: stepStyle, children: [steps[i]]))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Test connection as a secondary pill, worded per [TestState]. A failure
/// reads in care ink beside its words.
class _TestPill extends StatelessWidget {
  const _TestPill({required this.state, required this.onTap});
  final TestState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Widget? icon, String label, Color fg) = switch (state) {
      TestState.testing => (_Spinner(color: c.ink2), 'Testing IMAP…', c.ink2),
      TestState.success => (
          AppIcon('checkmark', size: _pillIcon, color: c.ink),
          'Connected to $_defaultHost',
          c.ink,
        ),
      TestState.error => (
          AppIcon('xmark', size: _pillIcon, color: c.careInk),
          _testFailed,
          c.careInk,
        ),
      TestState.idle => (null, 'Test connection', c.ink),
    };

    return PressScale(
      onTap: state == TestState.testing ? null : onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: _pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon, const SizedBox(width: Spacing.sm)],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: AppType.headline.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hairline row that opens and closes the IMAP fields.
class _AdvancedRow extends StatelessWidget {
  const _AdvancedRow({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      expanded: open,
      label: 'IMAP server',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _minTap),
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hair, width: _hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IMAP server', style: AppType.callout.copyWith(color: c.ink)),
                    Text('$_defaultHost · port $_defaultPort · SSL',
                        style: AppType.subhead.copyWith(color: c.ink3)),
                  ],
                ),
              ),
              AppIcon(open ? 'chevron.down' : 'chevron.right', size: _pillIcon, color: c.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen's one primary pill; quiet and inert until a test succeeds.
class _SavePill extends StatelessWidget {
  const _SavePill({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Save',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _pillHeight),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          decoration: BoxDecoration(
            color: enabled ? c.ink : c.surface2,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          alignment: Alignment.center,
          child: Text('Save',
              style: AppType.headline.copyWith(color: enabled ? c.bg : c.ink3)),
        ),
      ),
    );
  }
}

/// A small indeterminate spinner for the testing state.
class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: _pillIcon,
        child: CircularProgressIndicator(strokeWidth: _spinnerStroke, color: color),
      );
}
