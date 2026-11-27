// Кіру экранының жоғарғы иллюстрациясы: кешкі дала, төбелер, егістік жолақтары
// және ауада тербеліп тұрған спутник алқапты сәулемен сканерлейді.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class SteppeHeader extends StatefulWidget {
  const SteppeHeader({super.key});

  @override
  State<SteppeHeader> createState() => _SteppeHeaderState();
}

class _SteppeHeaderState extends State<SteppeHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(painter: _SteppePainter(_c.value), size: Size.infinite),
    );
  }
}

class _SteppePainter extends CustomPainter {
  _SteppePainter(this.v);

  final double v; // 0..1, циклдік

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Аспан
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF3E2), Color(0xFFF6E1B8)],
        ).createShader(rect),
    );
    // Күн
    canvas.drawCircle(Offset(w * 0.2, h * 0.5), h * 0.16, Paint()..color = Dc.goldHi.withValues(alpha: 0.55));

    // Төбелер (алыс → жақын)
    _hill(canvas, size, 0.58, 0.07, const Color(0xFFC7D9B0), 1.3, 0.2);
    _hill(canvas, size, 0.66, 0.06, const Color(0xFF8DBE8F), 1.9, 1.4);

    // Жақын алқап: перспективалық жолақтар
    final field = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.5, h * 0.66, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(field, Paint()..color = Dc.green2);
    canvas.save();
    canvas.clipPath(field);
    final rows = Paint()
      ..color = Dc.green.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    final vanish = Offset(w * 0.62, h * 0.6);
    for (var i = -6; i <= 14; i++) {
      canvas.drawLine(vanish, Offset(w * 0.08 * i, h * 1.05), rows);
    }

    // Сканерленген алқап (жарқыл)
    final scanCenter = Offset(w * 0.66, h * 0.86);
    final glow = 0.45 + 0.35 * math.sin(v * math.pi * 2);
    canvas.drawOval(
      Rect.fromCenter(center: scanCenter, width: w * 0.36, height: h * 0.12),
      Paint()..color = Dc.goldHi.withValues(alpha: 0.35 * glow),
    );
    canvas.restore();

    // Спутник + сәуле
    final bob = math.sin(v * math.pi * 2) * 5;
    final sat = Offset(w * 0.7, h * 0.27 + bob);
    final beam = Path()
      ..moveTo(sat.dx - 6, sat.dy + 12)
      ..lineTo(scanCenter.dx - w * 0.17, scanCenter.dy)
      ..lineTo(scanCenter.dx + w * 0.17, scanCenter.dy)
      ..lineTo(sat.dx + 6, sat.dy + 12)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Dc.gold.withValues(alpha: 0.45 * glow), Dc.gold.withValues(alpha: 0)],
        ).createShader(Rect.fromPoints(sat, scanCenter)),
    );

    // Орбита (пунктир доға)
    // Орбитаның жоғарғы шеті жоғарыдағы логотип жолынан төмен өтсін (≈0.24h)
    final orbit = Rect.fromCenter(center: Offset(w * 0.62, h * 0.47), width: w * 0.9, height: h * 0.46);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Dc.green.withValues(alpha: 0.25);
    for (var a = math.pi * 1.05; a < math.pi * 1.95; a += 0.07) {
      canvas.drawArc(orbit, a, 0.035, false, dash);
    }

    _satellite(canvas, sat, math.sin(v * math.pi * 2) * 0.06);
  }

  void _hill(Canvas canvas, Size s, double y, double amp, Color c, double freq, double phase) {
    final p = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width; x += 8) {
      final t = x / s.width;
      p.lineTo(x, s.height * (y - amp * math.sin(t * math.pi * freq + phase)));
    }
    p
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = c);
  }

  void _satellite(Canvas canvas, Offset c, double tilt) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.35 + tilt);
    final panel = Paint()..color = Dc.gold;
    final grid = Paint()
      ..color = const Color(0xFFB98222)
      ..strokeWidth = 1;
    for (final dx in [-44.0, 16.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(dx, -8, 28, 16), const Radius.circular(3)), panel);
      canvas.drawLine(Offset(dx + 9.3, -8), Offset(dx + 9.3, 8), grid);
      canvas.drawLine(Offset(dx + 18.6, -8), Offset(dx + 18.6, 8), grid);
    }
    final strut = Paint()
      ..color = Dc.green
      ..strokeWidth = 2.6;
    canvas.drawLine(const Offset(-16, 0), const Offset(-10, 0), strut);
    canvas.drawLine(const Offset(10, 0), const Offset(16, 0), strut);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -14, 20, 28), const Radius.circular(5));
    canvas.drawRRect(body, Paint()..color = Dc.cream);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Dc.green,
    );
    canvas.drawCircle(const Offset(0, 17), 4, Paint()..color = Dc.green);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SteppePainter old) => old.v != v;
}
