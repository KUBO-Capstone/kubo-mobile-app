import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../chat/widgets/counter_offer_dialog.dart' show formatAmount;
import '../widgets/confetti_burst.dart';

/// What the person chose on the celebration screen; null means "back to chat".
enum DealCelebrationAction { arrangePickup, viewEarnings }

/// Shown once to each side when an offer is accepted: the buyer is told the
/// seller said yes, the seller that they just closed a deal and for how much.
class DealCelebrationPage extends StatefulWidget {
  const DealCelebrationPage({
    super.key,
    required this.isSeller,
    required this.acceptedByMe,
    required this.counterpartyName,
    required this.cropName,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  /// Which side of the deal the viewer is on.
  final bool isSeller;

  /// The viewer tapped Accept (the seller on an offer, the buyer on a counter).
  final bool acceptedByMe;
  final String counterpartyName;
  final String cropName;
  final double quantity;
  final String unit;

  /// Agreed price per [unit].
  final double price;

  @override
  State<DealCelebrationPage> createState() => _DealCelebrationPageState();
}

class _DealCelebrationPageState extends State<DealCelebrationPage> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final seller = widget.isSeller;
    final total = widget.price * widget.quantity;
    final name = widget.counterpartyName;
    final headline =
        seller
            ? 'You just closed a deal!'
            : widget.acceptedByMe
            ? "It's a deal with $name!"
            : '$name accepted your offer!';
    final subline =
        seller
            ? (widget.acceptedByMe ? "You accepted $name's offer." : '$name accepted your counter-offer.')
            : (widget.acceptedByMe ? "You accepted $name's counter-offer." : 'Your produce is reserved for you.');
    final nextStep =
        seller
            ? '$name will now choose pickup at a bagsakan center or courier delivery. You will see the order in your chat.'
            : 'Next, choose how to get it: pick up at a bagsakan center or have it delivered.';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: AppColors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (context, constraints) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          // Centred on tall screens, scrollable on short ones.
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  seller ? AppAssets.bowingBearGif : AppAssets.congratsCowGif,
                                  height: 210,
                                  gaplessPlayback: true,
                                  semanticLabel: seller ? 'A bear taking a thankful bow' : 'A cartoon cow cheering "Congrats"',
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Congratulations!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.green, fontSize: 30, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  headline,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25),
                                ),
                                const SizedBox(height: 4),
                                Text(subline, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray, fontSize: 14)),
                                const SizedBox(height: 22),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                  decoration: BoxDecoration(color: AppColors.softBackground, borderRadius: BorderRadius.circular(16)),
                                  child: Column(
                                    children: [
                                      Text(
                                        seller ? 'Deal amount' : 'Your total',
                                        style: const TextStyle(color: AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? total : 0, end: total),
                                        duration: const Duration(milliseconds: 900),
                                        curve: Curves.easeOutCubic,
                                        builder:
                                            (_, value, __) => Text(
                                              formatPeso(value.roundToDouble() == total.roundToDouble() ? total : value.roundToDouble()),
                                              style: const TextStyle(
                                                color: AppColors.black,
                                                fontSize: 38,
                                                fontWeight: FontWeight.w900,
                                                height: 1.1,
                                              ),
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${formatAmount(widget.quantity)} ${widget.unit} ${widget.cropName} · ${formatPeso(widget.price)}/${widget.unit}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: AppColors.black, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  nextStep,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.gray, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(seller ? null : DealCelebrationAction.arrangePickup),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            seller ? 'Back to chat' : 'Arrange pickup or delivery',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(seller ? DealCelebrationAction.viewEarnings : null),
                        style: TextButton.styleFrom(foregroundColor: AppColors.green),
                        child: Text(seller ? 'See lifetime earnings' : 'Back to chat', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}
