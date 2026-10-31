import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// One short shower of confetti over its parent. Plays once; draws nothing
/// when the system asks for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 70, this.duration = const Duration(milliseconds: 2800)});

  final int pieces;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  static const _colors = <Color>[
    AppColors.green,
    AppColors.greenLight,
    Color(0xFFF5A623),
    Color(0xFFFF6FB5),
    Color(0xFF4FC3F7),
  ];

  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late final List<_Piece> _pieces;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    _pieces = List<_Piece>.generate(widget.pieces, (_) {
      return _Piece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.35,
        speed: 0.75 + random.nextDouble() * 0.6,
        sway: 0.02 + random.nextDouble() * 0.05,
        swayPhase: random.nextDouble() * math.pi * 2,
        spin: (random.nextDouble() - 0.5) * 12,
        width: 6 + random.nextDouble() * 6,
        height: 4 + random.nextDouble() * 8,
        color: _colors[random.nextInt(_colors.length)],
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!_reducedMotion && !_controller.isAnimating && _controller.value == 0) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _controller.value),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.swayPhase,
    required this.spin,
    required this.width,
    required this.height,
    required this.color,
  });

  final double x;
  final double delay;
  final double speed;
  final double sway;
  final double swayPhase;
  final double spin;
  final double width;
  final double height;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);

  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final piece in pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final dy = -0.08 + t * t * piece.speed * 1.15;
      final dx = piece.x + math.sin(t * math.pi * 4 + piece.swayPhase) * piece.sway;
      // Fade out over the last fifth of each piece's fall.
      final opacity = t > 0.8 ? (1 - t) / 0.2 : 1.0;
      paint.color = piece.color.withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(dx * size.width, dy * size.height)
        ..rotate(t * piece.spin)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: piece.width, height: piece.height),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
