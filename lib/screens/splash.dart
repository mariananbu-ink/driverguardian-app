import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui.dart';

/// Animated opening screen: compass-bus seal, app name and tagline, then [next].
/// The native splash (same navy colour + logo) shows while the app starts, so the
/// hand-over is seamless. Developed & Powered by Marian Anbu Juwan
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2100), _go);
  }

  void _go() {
    if (!mounted || _gone) return;
    _gone = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _in.dispose();
    _spin.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve c = Curves.easeOutCubic]) => CurvedAnimation(parent: _in, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final logo = _iv(0, .55, Curves.easeOutBack);
    final name = _iv(.35, .75);
    final tag = _iv(.5, .9);
    final foot = _iv(.7, 1);
    return Scaffold(
      backgroundColor: const Color(0xFF0B1033),
      body: GestureDetector(
        onTap: _go,
        child: Stack(children: [
          // soft glows
          Positioned(top: -120, right: -100, child: _glow(320, const Color(0xFF3B2FD0), .55)),
          Positioned(bottom: -140, left: -120, child: _glow(300, const Color(0xFF0E7C86), .35)),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 210,
                height: 210,
                child: Stack(alignment: Alignment.center, children: [
                  // rotating dashed dial
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (_, __) => Transform.rotate(angle: _spin.value * 2 * math.pi, child: CustomPaint(size: const Size(210, 210), painter: _DialPainter())),
                  ),
                  ScaleTransition(
                    scale: Tween(begin: .55, end: 1.0).animate(logo),
                    child: FadeTransition(opacity: _iv(0, .35), child: Image.asset('assets/icon/logo.png', width: 150, height: 150)),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: name,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(name),
                  child: const Text('DriverGuardian', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -.6)),
                ),
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: tag,
                child: const Text('School & College Bus Management', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13, fontWeight: FontWeight.w300, letterSpacing: .3)),
              ),
              const SizedBox(height: 26),
              FadeTransition(
                opacity: tag,
                child: SizedBox(width: 120, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: const LinearProgressIndicator(minHeight: 3, backgroundColor: Color(0x22FFFFFF), color: Color(0xFF7AA2FF)))),
              ),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: foot,
                child: const Column(children: [
                  Text(kCredit, textAlign: TextAlign.center, style: TextStyle(color: Color(0x80FFFFFF), fontSize: 11, fontWeight: FontWeight.w300)),
                  SizedBox(height: 2),
                  Text('v$kVersion', style: TextStyle(color: Color(0x55FFFFFF), fontSize: 10)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _glow(double size, Color c, double o) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: o), c.withValues(alpha: 0)]))),
      );
}

class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i * 2 * math.pi / 60;
      final long = i % 5 == 0;
      p.color = i == 0 ? const Color(0xFF7AA2FF) : Colors.white.withValues(alpha: long ? .35 : .15);
      final r1 = r - (long ? 10 : 5);
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r1, c + Offset(math.cos(a), math.sin(a)) * r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
