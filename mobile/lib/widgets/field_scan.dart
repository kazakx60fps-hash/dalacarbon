// Заставкадағы карта: жоғарыдан көрінетін егістік алқаптары, спутник маршрут бойымен ұшады.
// Камера спутникке «жабысып» тұрады және бұрылыстарда айналады (спутник әрқашан жоғары қарап тұр).
// Спутник өткен алқаптар NDVI түсімен боялады (сирек → қалың өсімдік).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class _Parcel {
  const _Parcel(this.rect, this.ndvi, this.revealAt);

  final Rect rect;
  final double ndvi; // 0..1
  final double revealAt; // маршрут прогресі, қай сәтте боялады (0..1; >1 — ешқашан)
}

/// Маршрут пен алқаптардың геометриясы (бір рет есептеледі).
class FieldScan {
  FieldScan() {
    _build();
  }

  // Маршрут (әлем координаттары, px): тура → оңға бұрылыс → тура → солға.
  static const route = <Offset>[
    Offset(0, 560),
    Offset(0, 190),
    Offset(190, 10),
    Offset(190, -270),
    Offset(-70, -520),
  ];
  static const _samples = 260;
  static const _scanRadius = 150.0;

  late final List<Offset> samples;
  late final List<_Parcel> _parcels;
  late final Path routePath;

  void _build() {
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final l = (route[i + 1] - route[i]).distance;
      lengths.add(l);
      total += l;
    }
    samples = List.generate(_samples + 1, (k) => _pointAt(total * k / _samples, lengths));

    routePath = Path()..moveTo(route.first.dx, route.first.dy);
    for (final p in route.skip(1)) {
      routePath.lineTo(p.dx, p.dy);
    }

    final rnd = math.Random(7);
    const cw = 96.0, ch = 72.0, gap = 14.0;
    final list = <_Parcel>[];
    for (var x = -560.0; x < 600; x += cw + gap) {
      for (var y = -860.0; y < 900; y += ch + gap) {
        final rect = Rect.fromLTWH(x, y, cw, ch);
        var reveal = 2.0;
        for (var k = 0; k < samples.length; k++) {
          if ((samples[k] - rect.center).distance < _scanRadius) {
            reveal = k / _samples;
            break;
          }
        }
        list.add(_Parcel(rect, 0.2 + rnd.nextDouble() * 0.8, reveal));
      }
    }
    _parcels = list;
  }

  Offset _pointAt(double d, List<double> lengths) {
    var left = d;
    for (var i = 0; i < lengths.length; i++) {
      if (left <= lengths[i] || i == lengths.length - 1) {
        final f = (left / lengths[i]).clamp(0.0, 1.0).toDouble();
        return Offset.lerp(route[i], route[i + 1], f)!;
      }
      left -= lengths[i];
    }
    return route.last;
  }

  /// Маршруттағы нүкте, t = 0..1.
  Offset position(double t) {
    final f = t.clamp(0.0, 1.0).toDouble() * _samples;
    final i = math.min(f.floor(), _samples - 1);
    return Offset.lerp(samples[i], samples[i + 1], f - i)!;
  }

  /// Қозғалыс бағыты (0 = жоғары, сағат тілімен, радиан). Бұрылыстар тегіс болуы үшін ±0.08 терезе.
  double heading(double t) {
    final v = position(t + 0.08) - position(t - 0.08);
    return math.atan2(v.dx, -v.dy);
  }
}

class FieldScanPainter extends CustomPainter {
  FieldScanPainter({required this.scan, required this.t, required this.pulse});

  final FieldScan scan;
  final double t; // маршрут прогресі 0..1
  final double pulse; // 0..1, сканер шеңберінің «тынысы»

  static const _sparse = Color(0xFFDCCB8E);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final pos = scan.position(t);
    final zoom = (size.width / 430).clamp(0.75, 1.3).toDouble();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-scan.heading(t));
    canvas.scale(zoom);
    canvas.translate(-pos.dx, -pos.dy);

    // Алқаптар: жиек әрқашан, бояу — спутник өткеннен кейін
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Dc.line;
    for (final p in scan._parcels) {
      final r = RRect.fromRectAndRadius(p.rect, const Radius.circular(6));
      final a = ((t - p.revealAt) / 0.07).clamp(0.0, 1.0).toDouble();
      if (a > 0) {
        final c = p.ndvi < 0.5
            ? Color.lerp(_sparse, Dc.leaf, p.ndvi * 2)!
            : Color.lerp(Dc.leaf, Dc.green2, (p.ndvi - 0.5) * 2)!;
        canvas.drawRRect(r, Paint()..color = c.withValues(alpha: 0.85 * a));
      }
      canvas.drawRRect(r, edge);
    }

    // Маршрут жолағы (видеодағы көше сияқты) және өтілген із
    canvas.drawPath(
      scan.routePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 54
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFE9E6DE).withValues(alpha: 0.75),
    );
    final idx = (t.clamp(0.0, 1.0) * (scan.samples.length - 1)).floor();
    final trail = Path()..addPolygon([...scan.samples.take(idx + 1), pos], false);
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Dc.gold.withValues(alpha: 0.9),
    );
    canvas.restore();

    // Шеттерін экран фонына сіңіру (видеодағыдай «терезе»)
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.24),
          radius: 0.78,
          colors: [Dc.paper.withValues(alpha: 0), Dc.paper],
          stops: const [0.5, 1],
        ).createShader(rect),
    );

    _drawScanner(canvas, center, zoom);
    _drawSatellite(canvas, center, zoom);
  }

  void _drawScanner(Canvas canvas, Offset c, double zoom) {
    final r = (_baseRing + pulse * 26) * zoom;
    canvas.drawCircle(c, r, Paint()..color = Dc.gold.withValues(alpha: 0.16 * (1 - pulse)));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Dc.gold.withValues(alpha: 0.55 * (1 - pulse)),
    );
  }

  static const _baseRing = 34.0;

  void _drawSatellite(Canvas canvas, Offset c, double zoom) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(zoom);

    // Көлеңке
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-50, -8, 108, 30), const Radius.circular(12)),
      Paint()
        ..color = Dc.ink.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Күн панельдері
    final panel = Paint()..color = Dc.gold;
    final grid = Paint()
      ..color = const Color(0xFFB98222)
      ..strokeWidth = 1.2;
    for (final dx in [-50.0, 18.0]) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(dx, -9, 32, 18), const Radius.circular(3));
      canvas.drawRRect(r, panel);
      canvas.drawLine(Offset(dx + 10.7, -9), Offset(dx + 10.7, 9), grid);
      canvas.drawLine(Offset(dx + 21.3, -9), Offset(dx + 21.3, 9), grid);
      canvas.drawLine(Offset(dx, 0), Offset(dx + 32, 0), grid);
    }
    // Тіректер
    final strut = Paint()
      ..color = Dc.green
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(-18, 0), const Offset(-11, 0), strut);
    canvas.drawLine(const Offset(11, 0), const Offset(18, 0), strut);

    // Корпус
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -17, 22, 34), const Radius.circular(6));
    canvas.drawRRect(body, Paint()..color = Dc.cream);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Dc.green,
    );
    canvas.drawLine(const Offset(-5, -6), const Offset(5, -6), strut..strokeWidth = 2.2);
    canvas.drawLine(const Offset(-5, 0), const Offset(5, 0), strut);
    // Камера (линза) — алдыңғы жақта
    canvas.drawCircle(const Offset(0, -21), 4.5, Paint()..color = Dc.green);
    canvas.drawCircle(const Offset(0, -21), 2, Paint()..color = Dc.goldHi);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FieldScanPainter old) => old.t != t || old.pulse != pulse;
}
