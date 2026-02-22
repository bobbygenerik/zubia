import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

/// The official Zubia Z logo with neon rings, painted via CustomPainter.
class ZubiaLogo extends StatelessWidget {
  const ZubiaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ZubiaLogoPainter(),
      size: const Size(200, 200),
    );
  }
}

class _ZubiaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 200;

    // Neon ring paint
    Paint ringPaint(double opacity, double strokeW) {
      return Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * scale
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    }

    // Draw organic rings
    _drawRing(canvas, cx, cy, 80 * scale, ringPaint(0.6, 2));
    _drawRing(canvas, cx, cy, 65 * scale, ringPaint(0.8, 2.5));
    _drawRing(canvas, cx, cy, 50 * scale, ringPaint(1.0, 3));

    // Z letter path
    final zPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [ZubiaColors.magenta, ZubiaColors.darkMagenta],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 70 * scale, height: 80 * scale));

    final zPath = Path();
    // Scale the Z path from the SVG (original viewBox 200x200)
    final points = [
      [70, 72], [70, 66], [74, 62], [80, 62], // Top left
      [120, 62], [126, 62], [130, 66], [130, 72], // Top right
      [130, 76], [130, 79], [128, 82], [125, 85], // Top right curve
      [95, 122], // Diagonal end
      [125, 122], [131, 122], [135, 126], [135, 132], // Bottom right
      [135, 138], [131, 142], [125, 142], // Bottom right curve
      [75, 142], [69, 142], [65, 138], [65, 132], // Bottom left
      [65, 128], [65, 125], [67, 122], [70, 119], // Bottom left curve
      [100, 82], // Diagonal start
      [80, 82], [74, 82], [70, 78], [70, 72], // Back to start
    ];

    zPath.moveTo(points[0][0] * scale, points[0][1] * scale);
    // Top-left curve
    zPath.cubicTo(
      points[1][0] * scale, points[1][1] * scale,
      points[2][0] * scale, points[2][1] * scale,
      points[3][0] * scale, points[3][1] * scale,
    );
    zPath.lineTo(points[4][0] * scale, points[4][1] * scale);
    zPath.cubicTo(
      points[5][0] * scale, points[5][1] * scale,
      points[6][0] * scale, points[6][1] * scale,
      points[7][0] * scale, points[7][1] * scale,
    );
    zPath.lineTo(points[8][0] * scale, points[8][1] * scale);
    zPath.cubicTo(
      points[9][0] * scale, points[9][1] * scale,
      points[10][0] * scale, points[10][1] * scale,
      points[11][0] * scale, points[11][1] * scale,
    );
    zPath.lineTo(points[12][0] * scale, points[12][1] * scale);
    zPath.lineTo(points[13][0] * scale, points[13][1] * scale);
    zPath.cubicTo(
      points[14][0] * scale, points[14][1] * scale,
      points[15][0] * scale, points[15][1] * scale,
      points[16][0] * scale, points[16][1] * scale,
    );
    zPath.cubicTo(
      points[17][0] * scale, points[17][1] * scale,
      points[18][0] * scale, points[18][1] * scale,
      points[19][0] * scale, points[19][1] * scale,
    );
    zPath.lineTo(points[20][0] * scale, points[20][1] * scale);
    zPath.cubicTo(
      points[21][0] * scale, points[21][1] * scale,
      points[22][0] * scale, points[22][1] * scale,
      points[23][0] * scale, points[23][1] * scale,
    );
    zPath.lineTo(points[24][0] * scale, points[24][1] * scale);
    zPath.cubicTo(
      points[25][0] * scale, points[25][1] * scale,
      points[26][0] * scale, points[26][1] * scale,
      points[27][0] * scale, points[27][1] * scale,
    );
    zPath.lineTo(points[28][0] * scale, points[28][1] * scale);
    zPath.lineTo(points[29][0] * scale, points[29][1] * scale);
    zPath.cubicTo(
      points[30][0] * scale, points[30][1] * scale,
      points[31][0] * scale, points[31][1] * scale,
      points[32][0] * scale, points[32][1] * scale,
    );
    zPath.close();

    // Glow behind Z
    canvas.drawPath(
      zPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(zPath, zPaint);

    // White stroke on Z
    canvas.drawPath(
      zPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale,
    );
  }

  void _drawRing(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    final path = Path();
    const steps = 64;
    for (int i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final wobble = math.sin(angle * 3) * radius * 0.08;
      final r = radius + wobble;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
