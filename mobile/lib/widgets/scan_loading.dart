// Кіргеннен кейінгі жүктелу: экран бұлдырайды, ортада Жер маңындағы орбитамен
// спутник айналып, алқапты сканерлейді (видеодағы жүк көлігінің орнына).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

class ScanLoading extends StatefulWidget {
  const ScanLoading({super.key, this.message = 'Спутник деректері жүктелуде…'});

  final String message;

  @override
  State<ScanLoading> createState() => _ScanLoadingState();
}

class _ScanLoadingState extends State<ScanLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        color: Dc.paper.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 150,
            height: 150,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _OrbitPainter(_c.value)),
            ),
          ),
          const SizedBox(height: 18),
          Text(widget.message,
              style: const TextStyle(color: Dc.ink, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Sentinel-2 · NDVI', style: TextStyle(color: Dc.muted, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.24;
    final orbit = Rect.fromCenter(center: c, width: size.width * 0.92, height: size.width * 0.4);
    final a = v * math.pi * 2;
    final sat = Offset(c.dx + math.cos(a) * orbit.width / 2, c.dy + math.sin(a) * orbit.height / 2);
    final front = math.sin(a) > 0; // спутник Жердің алдында ма
    final scale = 0.75 + 0.25 * (math.sin(a) + 1) / 2; // алдында үлкенірек

    // Орбитаның артқы жартысы және артта жүрген спутник — Жерден бұрын салынады
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Dc.green.withValues(alpha: 0.3);
    canvas.drawArc(orbit, math.pi, math.pi, false, orbitPaint);
    if (!front) _satellite(canvas, sat, scale);

    // Жер: жасыл шар + егістік жолақтары
    final planet = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Dc.leaf, Dc.green],
        ).createShader(planet),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(planet));
    final stripe = Paint()..color = Dc.gold.withValues(alpha: 0.35);
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(Rect.fromLTWH(c.dx - r, c.dy + r * (0.15 + i * 0.18), r * 2, r * 0.07), stripe);
    }
    canvas.restore();

    // Орбитаның алдыңғы жартысы, сәуле және алдыңғы спутник
    canvas.drawArc(orbit, 0, math.pi, false, orbitPaint);
    if (front) {
      canvas.drawLine(
        sat,
        c,
        Paint()
          ..color = Dc.gold.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      _satellite(canvas, sat, scale);
    }
  }

  void _satellite(Canvas canvas, Offset at, double scale) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(scale);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-20, -5, 40, 10), const Radius.circular(2.5)),
        Paint()..color = Dc.gold);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -8, 12, 16), const Radius.circular(3.5));
    canvas.drawRRect(body, Paint()..color = Dc.cream);
    canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Dc.green);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.v != v;
}
