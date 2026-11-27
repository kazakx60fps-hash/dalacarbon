// DalaCarbon AI логотипі — сайттағы mark-color.svg-нің дәл көшірмесі (CustomPainter, кітапханасыз).
// Пішін: «D» (тік жиек + жарты шеңбер), үстінде жапырақ тесігі, төменде жер қабаттары, ең астында алтын жолақ.
import 'package:flutter/material.dart';

import '../theme.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40, this.color = Dc.green, this.accent = Dc.gold});

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DalaCarbon AI логотипі',
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter(color, accent)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color, this.accent);

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120); // SVG viewBox: 0 0 120 120

    // «D»: M16 12 H60 A48 48 0 0 1 60 108 H16 Z
    final d = Path()
      ..moveTo(16, 12)
      ..lineTo(60, 12)
      ..arcToPoint(const Offset(60, 108), radius: const Radius.circular(48))
      ..lineTo(16, 108)
      ..close();
    canvas.clipPath(d);

    // Жапырақ: M38 62 C40 41 56 27 84 23 C82 44 50 50 38 62 Z
    final leaf = Path()
      ..moveTo(38, 62)
      ..cubicTo(40, 41, 56, 27, 84, 23)
      ..cubicTo(82, 44, 50, 50, 38, 62)
      ..close();
    final top = Path.combine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTWH(0, 0, 120, 60)),
      leaf,
    );

    final paint = Paint()..color = color;
    canvas.drawPath(top, paint);
    canvas.drawRect(const Rect.fromLTWH(0, 64, 120, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(0, 80, 120, 9), paint);
    canvas.drawRect(const Rect.fromLTWH(0, 93, 120, 6), paint);
    canvas.drawRect(const Rect.fromLTWH(0, 103, 120, 5), Paint()..color = accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color || old.accent != accent;
}

/// «DalaCarbon AI» жазуы: AI — алтын түсті (сайттағыдай).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 18, this.color = Dc.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'DalaCarbon', style: TextStyle(color: color)),
        const TextSpan(text: ' AI', style: TextStyle(color: Dc.gold)),
      ]),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.4),
    );
  }
}

/// Логотип + жазу бір қатарда (экрандардың жоғарғы бұрышы үшін).
class BrandRow extends StatelessWidget {
  const BrandRow({super.key, this.logo = 30, this.text = 18});

  final double logo;
  final double text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LogoMark(size: logo),
      const SizedBox(width: 8),
      Wordmark(size: text),
    ]);
  }
}
