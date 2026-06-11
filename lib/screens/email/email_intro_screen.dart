import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/inset_section.dart';
import 'email_nav.dart';

/// Screen 16 — Email Sync intro (mock).
///
/// Value prop (tray glyph + headline + read-only app-password pitch), a
/// "How it works" 3-step section, a reassurance note, and the primary CTA that
/// pushes the Setup screen. Provider list is implied by the secondary
/// "iCloud, Outlook, any IMAP coming" line, matching the handoff.
class EmailIntroScreen extends StatelessWidget {
  const EmailIntroScreen({super.key});

  static const _steps = <(String icon, String token, String title, String sub)>[
    (
      'bell.fill',
      'money',
      'Your bank sends alerts',
      '"You spent \$12.40 at Blue Bottle" — most cards do this',
    ),
    (
      'magnifyingglass',
      '',
      'Pal reads only those',
      'Filtered by sender list before anything is parsed',
    ),
    (
      'sparkles',
      'rituals',
      'It lands on Today',
      'Categorized, deduped, tagged as synced',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          EmailNavBar(
            title: 'Email sync',
            leadingLabel: 'You',
            onLeading: () => context.pop(),
          ),

          // --- Value prop ----------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              children: [
                _IntroGlyph(),
                const SizedBox(height: 20),
                Text(
                  'Stop logging card\ncharges by hand.',
                  textAlign: TextAlign.center,
                  style: AppFonts.sf(
                    size: 26,
                    weight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Connect your inbox with a read-only app password. Pal scans '
                  'for bank alert emails in the background and drops them on '
                  'your timeline — categorized, deduped, silent.',
                  textAlign: TextAlign.center,
                  style: AppFonts.sf(
                    size: 15,
                    color: c.ink2,
                    letterSpacing: -0.2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          // --- How it works --------------------------------------------------
          InsetSection(
            header: 'How it works',
            children: [
              for (var i = 0; i < _steps.length; i++)
                _StepRow(step: _steps[i], last: i == _steps.length - 1),
            ],
          ),

          // --- Reassurance note ----------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: c.accent.withValues(alpha: 0.20), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon('heart.fill', size: 14, color: c.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'App password, not your real one. You generate a '
                      'disposable password in your email settings — Pal stores '
                      'it encrypted in the iOS keychain. Revoke it anytime from '
                      'Gmail without touching anything else.',
                      style: AppFonts.sf(
                        size: 12,
                        color: c.ink2,
                        letterSpacing: -0.08,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- CTA -----------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pushNamed('emailSetup'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GmailGlyph(size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Set up Gmail sync',
                      style: AppFonts.sf(
                        size: 16,
                        weight: FontWeight.w600,
                        color: c.bg,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'iCloud, Outlook, any IMAP coming',
              textAlign: TextAlign.center,
              style: AppFonts.sf(size: 14, color: c.ink3, letterSpacing: -0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 120×120 tinted tray glyph with the small sparkles badge.
class _IntroGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accentTint, c.moneyTint],
              ),
              border: Border.all(color: c.hair, width: 0.5),
            ),
            alignment: Alignment.center,
            child: AppIcon('tray.fill', size: 56, color: c.accent),
          ),
          Positioned(
            bottom: -6,
            right: -6,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.money,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.money.withValues(alpha: 0.33),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const AppIcon('sparkles',
                  size: 18, color: Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One "How it works" row: tinted icon tile + title/sub, hairline below.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});
  final (String, String, String, String) step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.forType(step.$2);
    return Container(
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.hair, width: 0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: AppIcon(step.$1, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.$3,
                    style: AppFonts.sf(
                        size: 15,
                        weight: FontWeight.w500,
                        color: c.ink,
                        letterSpacing: -0.24)),
                const SizedBox(height: 2),
                Text(step.$4,
                    style: AppFonts.sf(
                        size: 13,
                        color: c.ink3,
                        letterSpacing: -0.08,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 5-color Gmail brand mark (`GmailGlyph`, email-sync.jsx:546). SF Symbols
/// can't represent it, so it's painted from the design's SVG paths.
//
// duplicated in email_setup_screen.dart / email_dashboard_screen.dart because
// the task scopes edits to those screen files; a shared widget would be cleaner.
class _GmailGlyph extends StatelessWidget {
  const _GmailGlyph({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _GmailGlyphPainter()));
}

class _GmailGlyphPainter extends CustomPainter {
  static const _white = Color(0xFFE8EAED);
  static const _red = Color(0xFFEA4335);
  static const _green = Color(0xFF34A853);
  static const _blue = Color(0xFF4285F4);
  static const _yellow = Color(0xFFFBBC04);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48; // viewBox is 0 0 48 48
    canvas.scale(s);
    final paint = Paint()..style = PaintingStyle.fill;
    void fill(Color color, void Function(Path) build) {
      final path = Path();
      build(path);
      canvas.drawPath(path, paint..color = color);
    }

    // back tray (M6 14v22a2 2 0 002 2h6V22l10 7 10-7v16h6a2 2 0 002-2V14l-18 13L6 14z)
    fill(_white, (p) {
      p.moveTo(6, 14);
      p.relativeLineTo(0, 22);
      p.relativeArcToPoint(const Offset(2, 2), radius: const Radius.circular(2));
      p.relativeLineTo(6, 0);
      p.lineTo(14, 22);
      p.lineTo(24, 29);
      p.lineTo(34, 22);
      p.relativeLineTo(0, 16);
      p.relativeLineTo(6, 0);
      p.relativeArcToPoint(const Offset(2, -2), radius: const Radius.circular(2));
      p.lineTo(42, 14);
      p.lineTo(24, 27);
      p.lineTo(6, 14);
      p.close();
    });
    // top fold (M6 14l18 13 18-13v-2a2 2 0 00-2-2h-2L24 22 10 10H8a2 2 0 00-2 2v2z)
    fill(_red, (p) {
      p.moveTo(6, 14);
      p.lineTo(24, 27);
      p.lineTo(42, 14);
      p.relativeLineTo(0, -2);
      p.relativeArcToPoint(const Offset(-2, -2), radius: const Radius.circular(2));
      p.relativeLineTo(-2, 0);
      p.lineTo(24, 22);
      p.lineTo(10, 10);
      p.lineTo(8, 10);
      p.relativeArcToPoint(const Offset(-2, 2), radius: const Radius.circular(2));
      p.relativeLineTo(0, 2);
      p.close();
    });
    // left edge (M8 38h6V22L6 16v20a2 2 0 002 2z)
    fill(_green, (p) {
      p.moveTo(8, 38);
      p.relativeLineTo(6, 0);
      p.lineTo(14, 22);
      p.lineTo(6, 16);
      p.relativeLineTo(0, 20);
      p.relativeArcToPoint(const Offset(2, 2), radius: const Radius.circular(2));
      p.close();
    });
    // right edge (M34 38h6a2 2 0 002-2V16l-8 6v16z)
    fill(_blue, (p) {
      p.moveTo(34, 38);
      p.relativeLineTo(6, 0);
      p.relativeArcToPoint(const Offset(2, -2), radius: const Radius.circular(2));
      p.lineTo(42, 16);
      p.lineTo(34, 22);
      p.close();
    });
    // center V (M14 22l10 7 10-7v-9L24 22 14 13v9z)
    fill(_yellow, (p) {
      p.moveTo(14, 22);
      p.lineTo(24, 29);
      p.lineTo(34, 22);
      p.relativeLineTo(0, -9);
      p.lineTo(24, 22);
      p.lineTo(14, 13);
      p.close();
    });
  }

  @override
  bool shouldRepaint(_GmailGlyphPainter oldDelegate) => false;
}
