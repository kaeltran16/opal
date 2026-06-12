import 'package:flutter/widgets.dart';

/// The 5-color Gmail brand mark (`GmailGlyph`, email-sync.jsx:546). SF Symbols
/// can't represent it, so it's painted from the design's SVG paths. Shared by
/// the Email Sync intro/setup/dashboard screens.
class GmailGlyph extends StatelessWidget {
  const GmailGlyph({super.key, this.size = 24});
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
