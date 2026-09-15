import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/negotiation_service.dart';

/// New terms entered in [showCounterOfferDialog].
class CounterOffer {
  const CounterOffer({required this.price, required this.quantity});

  final double price;
  final double quantity;
}

/// Asks for a new price/quantity in reply to [offer]. Resolves to null when
/// dismissed; the caller sends the counter and handles the result.
Future<CounterOffer?> showCounterOfferDialog(BuildContext context, NegotiationRecord offer) {
  return showDialog<CounterOffer>(
    context: context,
    builder: (_) => _CounterOfferDialog(offer: offer),
  );
}

class _CounterOfferDialog extends StatefulWidget {
  const _CounterOfferDialog({required this.offer});

  final NegotiationRecord offer;

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog> {
  late final _priceController = TextEditingController(text: formatAmount(widget.offer.offeredPrice));
  late final _quantityController = TextEditingController(text: formatAmount(widget.offer.offeredQuantity));
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    if (price == widget.offer.offeredPrice && quantity == widget.offer.offeredQuantity) {
      setState(() => _error = 'Change the price or quantity, or accept the offer instead.');
      return;
    }
    Navigator.of(context).pop(CounterOffer(price: price, quantity: quantity));
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Counter on ${offer.cropName}',
        style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: PHP ${formatAmount(offer.offeredPrice)} / ${offer.unit} × ${formatAmount(offer.offeredQuantity)} ${offer.unit}',
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Price per ${offer.unit}', prefixText: 'PHP '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Quantity', suffixText: offer.unit),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.gray)),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          child: const Text('Send counter'),
        ),
      ],
    );
  }
}

/// `120` for whole numbers, `120.5` otherwise — keeps `kg` labels tidy.
String formatAmount(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
