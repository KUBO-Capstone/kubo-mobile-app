import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../login/services/auth_service.dart';

/// Opens the offer dialog for [listing] and returns the created negotiation,
/// or null if the user dismissed it or the offer was refused.
Future<NegotiationRecord?> showMakeOfferDialog(
  BuildContext context,
  SyntheticListingRecord listing,
) {
  final messenger = ScaffoldMessenger.of(context);
  final buyerId = AuthService.currentUserId;

  // These are the cases the server would reject anyway; catching them here
  // keeps the dialog from opening on something that can never succeed.
  if (buyerId == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Log in to make an offer.')));
    return Future.value(null);
  }
  if (!listing.canReceiveOffers) {
    messenger.showSnackBar(const SnackBar(content: Text('This listing cannot receive offers.')));
    return Future.value(null);
  }
  if (listing.sellerId == buyerId) {
    messenger.showSnackBar(const SnackBar(content: Text('This is your own listing.')));
    return Future.value(null);
  }

  return showDialog<NegotiationRecord>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _MakeOfferDialog(listing: listing, buyerId: buyerId),
  );
}

class _MakeOfferDialog extends StatefulWidget {
  const _MakeOfferDialog({required this.listing, required this.buyerId});

  final SyntheticListingRecord listing;
  final int buyerId;

  @override
  State<_MakeOfferDialog> createState() => _MakeOfferDialogState();
}

class _MakeOfferDialogState extends State<_MakeOfferDialog> {
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _service = NegotiationService();
  bool _submitting = false;
  String? _error;

  SyntheticListingRecord get listing => widget.listing;
  String get unit => listing.unit ?? 'unit';

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price per $unit.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    final available = listing.availableQuantity;
    if (available != null && quantity > available) {
      setState(() => _error = 'Only ${_trim(available)} $unit available.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final offer = await _service.createOffer(
        buyerId: widget.buyerId,
        productId: listing.productId!,
        price: price,
        quantity: quantity,
      );
      if (!mounted) return;
      Navigator.of(context).pop(offer);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asking = listing.basePrice == null ? listing.price : 'PHP ${_trim(listing.basePrice!)} / $unit';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${listing.sellerLabel} listed ${listing.title} for $asking',
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border, thickness: 1),
            const SizedBox(height: 12),
            _Label('Your price per $unit'),
            const SizedBox(height: 8),
            _OfferField(
              controller: _priceController,
              hint: 'Enter your offer',
              suffix: 'PHP',
              autofocus: true,
              enabled: !_submitting,
            ),
            const SizedBox(height: 14),
            _Label(
              listing.availableQuantity == null
                  ? 'Quantity'
                  : 'Quantity (${_trim(listing.availableQuantity!)} $unit available)',
            ),
            const SizedBox(height: 8),
            _OfferField(
              controller: _quantityController,
              hint: 'How much',
              suffix: unit,
              enabled: !_submitting,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                      )
                    : const Text(
                        'Make Offer',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.gray, fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

class _OfferField extends StatelessWidget {
  const _OfferField({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.enabled,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.gray, fontSize: 16),
        suffixText: '$suffix ',
        suffixStyle: const TextStyle(color: AppColors.green, fontSize: 16, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: AppColors.softBackground,
        border: border(AppColors.border, 0),
        enabledBorder: border(AppColors.border, 0),
        focusedBorder: border(AppColors.green, 1.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

/// Drops a trailing `.0` so quantities read as `30 kg`, not `30.0 kg`.
String _trim(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
