// Заставка: спутник алқаптардың үстінен ұшады, сосын логотип пен атау шығады → кіру экраны.
// Экранды басса — бірден өтеді.
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/fade_route.dart';
import '../widgets/field_scan.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  final _scan = FieldScan();
  late final AnimationController _flight =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..forward();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  late final AnimationController _brand =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  final _timers = <Timer>[];
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 1500), () => _brand.forward()));
    _timers.add(Timer(const Duration(milliseconds: 4700), _next));
  }

  void _next() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(fadeRoute(const LoginScreen(), ms: 750));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flight.dispose();
    _pulse.dispose();
    _brand.dispose();
    super.dispose();
  }

  Animation<double> _part(double from, double to) =>
      CurvedAnimation(parent: _brand, curve: Interval(from, to, curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    final logoIn = _part(0, 0.6);
    final titleIn = _part(0.15, 0.75);
    final subIn = _part(0.35, 1);
    return Scaffold(
      backgroundColor: Dc.paper,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_flight, _pulse]),
              builder: (context, _) => CustomPaint(
                painter: FieldScanPainter(
                  scan: _scan,
                  t: Curves.easeInOutSine.transform(_flight.value),
                  pulse: _pulse.value,
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.48),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(logoIn),
                child: FadeTransition(opacity: logoIn, child: const LogoMark(size: 58)),
              ),
              const SizedBox(height: 14),
              _Rise(animation: titleIn, child: const Wordmark(size: 32)),
              const SizedBox(height: 10),
              _Rise(
                animation: subIn,
                child: const Text(
                  'Топырақтағы көміртегін өлшеп,\nтабысқа айналдырыңыз',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Dc.muted, fontSize: 14, height: 1.45),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Төменнен көтеріліп, біртіндеп пайда болу.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}
