import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/data/order_service.dart';
import '../../../shared/data/review_service.dart';
import '../../../shared/widgets/kubo_star_rating.dart';
import '../../chat/widgets/counter_offer_dialog.dart' show formatAmount;
import '../../login/services/auth_service.dart';

/// Rates the other party on a delivered order. Pops with the posted
/// [ReviewRecord], or null when the user backs out.
class WriteReviewPage extends StatefulWidget {
  const WriteReviewPage({super.key, required this.order, this.initialRating = 0, this.service});

  final OrderRecord order;

  /// Pre-selected stars, e.g. from tapping a star on the order page.
  final int initialRating;

  /// Injected in tests; a real client otherwise.
  final ReviewService? service;

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  static const _maxComment = 1000;
  // Every tag is praise, so they only make sense for a decent rating.
  static const _minRatingForTags = 3;

  late final ReviewService _service = widget.service ?? ReviewService();
  final _comment = TextEditingController();
  final Set<String> _tags = <String>{};
  late int _rating = widget.initialRating.clamp(0, 5);
  bool _submitting = false;

  int get _userId => AuthService.currentUserId ?? 0;
  bool get _reviewingSeller => widget.order.isBuyer(_userId);
  String get _otherName => widget.order.counterpartyName(_userId);
  List<ReviewTag> get _tagChoices => _reviewingSeller ? ReviewTags.aboutSeller : ReviewTags.aboutBuyer;

  @override
  void dispose() {
    _comment.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    setState(() {
      _rating = value;
      if (value < _minRatingForTags) _tags.clear();
    });
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final review = await _service.submitReview(
        orderId: widget.order.id,
        rating: _rating,
        comment: _comment.text,
        tags: _tagChoices.map((tag) => tag.key).where(_tags.contains).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks! Your review of $_otherName is posted.')),
      );
      Navigator.of(context).pop(review);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: AppColors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'RATE YOUR DEAL',
          style: TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _OrderSummary(order: order, otherName: _otherName, otherIsSeller: _reviewingSeller),
          const SizedBox(height: 28),
          Text(
            _reviewingSeller ? 'How was your order from $_otherName?' : 'How was dealing with $_otherName?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 16),
          KuboStarRatingInput(value: _rating, onChanged: _setRating),
          const SizedBox(height: 8),
          Text(
            _rating == 0 ? 'Tap a star to rate' : ratingLabels[_rating]!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _rating == 0 ? AppColors.gray : AppColors.black,
              fontSize: 15,
              fontWeight: _rating == 0 ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _rating >= _minRatingForTags ? _buildTags() : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tell others about it (Optional)',
            style: TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            minLines: 4,
            maxLines: 7,
            maxLength: _maxComment,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _reviewingSeller
                  ? 'Was the produce fresh? Did it match the photos? How was the handover?'
                  : 'Was the buyer on time and easy to deal with?',
              hintStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
              filled: true,
              fillColor: AppColors.softBackground,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.green, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.public, size: 14, color: AppColors.gray),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Your review is public and shows on $_otherName's profile. You can't edit it later.",
                  style: const TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _rating == 0 || _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                  : const Text('Submit review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTags() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What went well? (Optional)',
            style: TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tagChoices)
                FilterChip(
                  label: Text(tag.label),
                  selected: _tags.contains(tag.key),
                  onSelected: (selected) => setState(() => selected ? _tags.add(tag.key) : _tags.remove(tag.key)),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _tags.contains(tag.key) ? AppColors.green : AppColors.black,
                    fontWeight: _tags.contains(tag.key) ? FontWeight.w700 : FontWeight.w500,
                  ),
                  // Material 3 chips ignore selectedColor; color wins.
                  color: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.green.withValues(alpha: 0.1)
                        : AppColors.white,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(color: _tags.contains(tag.key) ? AppColors.green : AppColors.border),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order, required this.otherName, required this.otherIsSeller});

  final OrderRecord order;
  final String otherName;
  final bool otherIsSeller;

  @override
  Widget build(BuildContext context) {
    final image = order.productImage;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: image == null
                  ? const ColoredBox(color: AppColors.border, child: Icon(Icons.eco_outlined, color: AppColors.gray))
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: AppColors.border, child: Icon(Icons.eco_outlined, color: AppColors.gray)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.cropName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatAmount(order.quantity)} ${order.unit} · ${formatPeso(order.total)}',
                  style: const TextStyle(color: AppColors.black, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${otherIsSeller ? 'Sold by' : 'Bought by'} $otherName · Order #${order.id}',
                  style: const TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
