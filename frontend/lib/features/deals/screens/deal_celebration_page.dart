import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../chat/widgets/counter_offer_dialog.dart' show formatAmount;
import '../widgets/confetti_burst.dart';

/// What the person chose on the celebration screen; null means "later".
enum DealCelebrationAction { writeReview, viewEarnings }

/// Shown once to each side when a deal is really done: after the buyer taps
/// "Order received", confirming they have the produce in hand. Accepting an
/// offer only starts the order, so nothing is celebrated then. The screen
/// leads straight into the review, while the handover is fresh.
class DealCelebrationPage extends StatefulWidget {
  const DealCelebrationPage({
    super.key,
    required this.isSeller,
    required this.counterpartyName,
    required this.cropName,
    required this.quantity,
    required this.unit,
    required this.price,
    this.canReview = true,
  });

  /// Which side of the deal the viewer is on.
  final bool isSeller;
  final String counterpartyName;
  final String cropName;
  final double quantity;
  final String unit;

  /// Agreed price per [unit].
  final double price;

  /// The viewer has not reviewed this order yet; offers "Write a review".
  final bool canReview;

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
    final headline = 'You just closed a deal!';
    final subline = seller ? '$name received the produce.' : 'You received your order from $name.';
    final nextStep = widget.canReview
        ? (seller
            ? 'How was dealing with $name? Your review helps other growers.'
            : 'How was the produce? Your review helps other buyers, and photos of the quality and packaging help most.')
        : 'Thanks for trading on Kubo.';

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
                                        seller ? 'Deal Amount' : 'Your Total',
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
                          onPressed: () => Navigator.of(context).pop(widget.canReview ? DealCelebrationAction.writeReview : null),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            widget.canReview ? 'Write a Review' : 'Done',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // The earnings shortcut is the seller's own: a buyer never
                      // sees what the seller has made.
                      if (seller)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(DealCelebrationAction.viewEarnings),
                          style: TextButton.styleFrom(foregroundColor: AppColors.green),
                          child: const Text('See Lifetime Earnings', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      if (widget.canReview)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(foregroundColor: AppColors.gray),
                          child: const Text('Maybe Later', style: TextStyle(fontWeight: FontWeight.w700)),
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
