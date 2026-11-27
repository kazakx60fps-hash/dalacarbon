// Графиктер: секвестрация сызығы (өлшенген + RothC болжамы), учаскелер сақинасы, маусым сақинасы.
// Барлығы CustomPainter-мен, сайттағы графиктердің түстерімен.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';
import '../util/format.dart';

/// 3 / 6 / 12 ай ауыстырғышы бар секвестрация графигі.
class SeriesChart extends StatefulWidget {
  const SeriesChart({super.key, required this.series, this.initialRange = 6, this.height = 200});

  final List<Json> series; // {label, measured, forecast}
  final int initialRange;
  final double height;

  @override
  State<SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<SeriesChart> with SingleTickerProviderStateMixin {
  late int _range = widget.initialRange;
  int? _hover;
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  List<Json> get _pts => widget.series.length <= _range
      ? widget.series
      : widget.series.sublist(widget.series.length - _range);

  void _setRange(int r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _hover = null;
    });
    _draw.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pts = _pts;
    final total = pts.fold<num>(0, (a, p) => a + (p['measured'] as num));
    final fc = pts.fold<num>(0, (a, p) => a + (p['forecast'] as num));
    final delta = fc == 0 ? 0.0 : (total - fc) / fc * 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('Соңғы ${pts.length} айда ${fmtInt(total)} т CO₂e · болжамнан ${delta >= 0 ? '+' : ''}${fmtNum(delta)}%',
              style: const TextStyle(color: Dc.muted, fontSize: 12.5)),
        ),
      ]),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 3, label: Text('3 ай')),
          ButtonSegment(value: 6, label: Text('6 ай')),
          ButtonSegment(value: 12, label: Text('12 ай')),
        ],
        selected: {_range},
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: Dc.ink,
          selectedForegroundColor: Dc.cream,
          visualDensity: VisualDensity.compact,
        ),
        onSelectionChanged: (s) => _setRange(s.first),
      ),
      const SizedBox(height: 12),
      const Row(children: [
        _Legend(color: Dc.gold, text: 'Өлшенген'),
        SizedBox(width: 14),
        _Legend(color: Dc.ink, text: 'RothC болжамы', dashed: true),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: widget.height,
        child: LayoutBuilder(builder: (context, c) {
          void pick(Offset local) {
            if (pts.isEmpty) return;
            final step = pts.length == 1 ? 0.0 : (c.maxWidth - 44) / (pts.length - 1);
            final i = step == 0 ? 0 : ((local.dx - 36) / step).round().clamp(0, pts.length - 1);
            setState(() => _hover = i);
          }

          return GestureDetector(
            onTapDown: (d) => pick(d.localPosition),
            onHorizontalDragUpdate: (d) => pick(d.localPosition),
            child: AnimatedBuilder(
              animation: _draw,
              builder: (context, _) => CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _SeriesPainter(pts, Curves.easeOutCubic.transform(_draw.value), _hover),
              ),
            ),
          );
        }),
      ),
      if (_hover != null && _hover! < pts.length)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${pts[_hover!]['label']}: өлшенген ${fmtInt(pts[_hover!]['measured'] as num)} т · болжам ${fmtInt(pts[_hover!]['forecast'] as num)} т',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Dc.ink),
          ),
        ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, this.dashed = false});

  final Color color;
  final String text;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14,
        height: dashed ? 2 : 3,
        decoration: BoxDecoration(color: color.withValues(alpha: dashed ? 0.6 : 1), borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12, color: Dc.muted)),
    ]);
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter(this.pts, this.t, this.hover);

  final List<Json> pts;
  final double t; // сызылу прогресі 0..1
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    const l = 36.0, r = 8.0, top = 8.0, b = 22.0;
    final w = size.width - l - r, h = size.height - top - b;
    final maxV = pts.fold<num>(0, (m, p) => math.max(m, math.max(p['measured'] as num, p['forecast'] as num)));
    final raw = (maxV * 1.08) / 4;
    final mag = math.pow(10, (math.log(raw <= 0 ? 1 : raw) / math.ln10).floor()).toDouble();
    final tick = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((v) => v >= raw, orElse: () => 10 * mag);
    final yMax = tick * 4;
    double x(int i) => l + (pts.length == 1 ? 0 : w * i / (pts.length - 1));
    double y(num v) => top + h * (1 - v / yMax);

    final grid = Paint()
      ..color = Dc.line
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(fontSize: 10.5, color: Dc.muted);
    for (var k = 0; k <= 4; k++) {
      final v = yMax * k / 4;
      canvas.drawLine(Offset(l, y(v)), Offset(size.width - r, y(v)), grid);
      _text(canvas, fmtInt(v), Offset(l - 6, y(v)), labelStyle, alignRight: true);
    }
    for (var i = 0; i < pts.length; i++) {
      if (pts.length > 6 && i.isOdd) continue;
      _text(canvas, pts[i]['label'] as String, Offset(x(i), size.height - 9), labelStyle, center: true);
    }

    Path line(String key) {
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        final pt = Offset(x(i), y(pts[i][key] as num));
        if (i == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          final prev = Offset(x(i - 1), y(pts[i - 1][key] as num));
          final mx = (prev.dx + pt.dx) / 2;
          p.cubicTo(mx, prev.dy, mx, pt.dy, pt.dx, pt.dy);
        }
      }
      return p;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, l + w * t + 2, size.height));
    final measured = line('measured');
    final area = Path.from(measured)
      ..lineTo(x(pts.length - 1), y(0))
      ..lineTo(x(0), y(0))
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Dc.gold.withValues(alpha: 0.32), Dc.gold.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    _dashed(canvas, line('forecast'), Paint()
      ..color = Dc.ink.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke);
    canvas.drawPath(
      measured,
      Paint()
        ..color = Dc.gold
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < pts.length; i++) {
      final c = Offset(x(i), y(pts[i]['measured'] as num));
      canvas.drawCircle(c, i == hover ? 6 : 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        c,
        i == hover ? 6 : 3.5,
        Paint()
          ..color = Dc.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    canvas.restore();
    if (hover != null && hover! < pts.length) {
      canvas.drawLine(Offset(x(hover!), top), Offset(x(hover!), top + h),
          Paint()
            ..color = Dc.ink.withValues(alpha: 0.25)
            ..strokeWidth = 1);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, TextStyle style, {bool alignRight = false, bool center = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    if (center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SeriesPainter old) => old.t != t || old.hover != hover || old.pts != pts;
}

/// Учаскелер бойынша секвестрация: сақина диаграмма, бөлікті басса — мәні ортада.
class SplitDonut extends StatefulWidget {
  const SplitDonut({super.key, required this.split});

  final List<Json> split; // {name, tonnes}

  @override
  State<SplitDonut> createState() => _SplitDonutState();
}

class _SplitDonutState extends State<SplitDonut> {
  int? _sel;
  static const colors = [Dc.gold, Color(0xFF8FC9A3), Dc.green, Color(0xFFC2553F)];

  @override
  Widget build(BuildContext context) {
    final total = widget.split.fold<num>(0, (a, s) => a + (s['tonnes'] as num));
    final sel = _sel;
    return Column(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox(
          width: 190,
          height: 190,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size.square(190), painter: _DonutPainter(widget.split, total, t, sel, colors)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                sel == null ? '${fmtInt(total)} т' : '${((widget.split[sel]['tonnes'] as num) / total * 100).round()}%',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Dc.ink),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  sel == null ? 'барлығы' : widget.split[sel]['name'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Dc.muted),
                ),
              ),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < widget.split.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _sel = _sel == i ? null : i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _sel == i ? Dc.input : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(radius: 5, backgroundColor: colors[i % colors.length]),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.split[i]['name'] as String, style: const TextStyle(fontSize: 13.5))),
              Text('${fmtInt(widget.split[i]['tonnes'] as num)} т',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ]),
          ),
        ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.split, this.total, this.t, this.sel, this.colors);

  final List<Json> split;
  final num total;
  final double t;
  final int? sel;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 16);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = Dc.input);
    var start = -math.pi / 2;
    for (var i = 0; i < split.length; i++) {
      final sweep = (split[i]['tonnes'] as num) / total * math.pi * 2 * t;
      canvas.drawArc(
        rect,
        start + 0.04,
        math.max(sweep - 0.08, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sel == i ? 24 : 18
          ..strokeCap = StrokeCap.round
          ..color = colors[i % colors.length].withValues(alpha: sel == null || sel == i ? 1 : 0.35),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.t != t || old.sel != sel;
}

/// Маусымдық жоспардың сақинасы (68%).
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 120, this.label = 'орындалды'});

  final double value; // 0..1
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size.square(size), painter: _RingPainter(v)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(v * 100).round()}%',
                style: TextStyle(color: Colors.white, fontSize: size * 0.22, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: size * 0.095)),
          ]),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 8);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = Colors.white.withValues(alpha: 0.22));
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}
