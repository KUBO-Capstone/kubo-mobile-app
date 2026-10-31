import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A produce listing card with peso coins and bills floating around it.
/// The pieces bob gently; with reduced motion turned on they stay still.
class EarningsIllustration extends StatefulWidget {
  const EarningsIllustration({super.key, this.height = 230});

  final double height;

  @override
  State<EarningsIllustration> createState() => _EarningsIllustrationState();
}

class _EarningsIllustrationState extends State<EarningsIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _float,
          builder: (context, _) {
            double bob(double phase, [double amount = 6]) => math.sin((_float.value + phase) * 2 * math.pi) * amount;
            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = widget.height;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: w * 0.16, top: h * 0.10 + bob(0.0), child: const _Bill(angle: -0.2)),
                    Positioned(right: w * 0.10, top: h * 0.36 + bob(0.3), child: const _Bill(angle: 0.18, dark: true)),
                    Positioned(right: w * 0.06, top: h * 0.56 + bob(0.55), child: const _Bill(angle: 0.08)),
                    Positioned(left: w * 0.08, top: h * 0.32 + bob(0.7, 4), child: const _Coin(size: 30, dark: true)),
                    Positioned(left: w * 0.20, top: h * 0.62 + bob(0.15, 5), child: const _Coin(size: 26)),
                    Positioned(right: w * 0.20, top: h * 0.06 + bob(0.45, 5), child: const _Coin(size: 32)),
                    Positioned(right: w * 0.30, bottom: h * 0.02 + bob(0.85, 4), child: const _Coin(size: 22)),
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, bob(0.25, 3)),
                        child: Transform.rotate(angle: -0.05, child: const _ProduceCard()),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProduceCard extends StatelessWidget {
  const _ProduceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F2E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shopping_basket_rounded, size: 64, color: AppColors.green),
                Positioned(top: 14, right: 22, child: Icon(Icons.eco_rounded, size: 26, color: AppColors.greenLight)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _bar(width: 92),
          const SizedBox(height: 7),
          _bar(width: 64),
        ],
      ),
    );
  }

  Widget _bar({required double width}) => Container(
        width: width,
        height: 8,
        decoration: BoxDecoration(color: const Color(0xFF8E8A85), borderRadius: BorderRadius.circular(4)),
      );
}

class _Bill extends StatelessWidget {
  const _Bill({required this.angle, this.dark = false});

  final double angle;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final body = dark ? const Color(0xFF1F7A45) : const Color(0xFF3CC37A);
    final mark = dark ? const Color(0xFF145C33) : const Color(0xFF1F9A57);
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 64,
        height: 34,
        decoration: BoxDecoration(color: body, borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.center,
        child: Container(width: 18, height: 18, decoration: BoxDecoration(color: mark, shape: BoxShape.circle)),
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final face = dark ? const Color(0xFF9E9E9E) : const Color(0xFFE0E0E0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: face,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF8A8A8A), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '₱',
        style: TextStyle(color: const Color(0xFF6B6B6B), fontSize: size * 0.5, fontWeight: FontWeight.w900, height: 1),
      ),
    );
  }
}
