import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/fulfillment_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../listing/widgets/fulfillment_picker.dart';

/// New terms entered in [showCounterOfferDialog]. [fulfillment] is null when
/// the handover stays as it was.
class CounterOffer {
  const CounterOffer({required this.price, required this.quantity, this.fulfillment});

  final double price;
  final double quantity;
  final OfferFulfillment? fulfillment;
}

/// Edits the terms on the table in reply to [offer]: the price, the
/// quantity, and how the produce changes hands. A seller can move the
/// pickup to a center they reach or take the buyer's farther one and raise
/// the price to cover the trip. Sending it replaces the offer that was on
/// the table, so only one is ever open.
///
/// [bySeller] decides what the handover choices allow: the seller may pick
/// anything, the buyer only what the seller supports. Resolves to null when
/// dismissed; the caller sends the counter and handles the result.
Future<CounterOffer?> showCounterOfferDialog(
  BuildContext context,
  NegotiationRecord offer, {
  required bool bySeller,
}) {
  return showModalBottomSheet<CounterOffer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _CounterOfferSheet(offer: offer, bySeller: bySeller),
  );
}

class _CounterOfferSheet extends StatefulWidget {
  const _CounterOfferSheet({required this.offer, required this.bySeller});

  final NegotiationRecord offer;
  final bool bySeller;

  @override
  State<_CounterOfferSheet> createState() => _CounterOfferSheetState();
}

class _CounterOfferSheetState extends State<_CounterOfferSheet> {
  late final _priceController = TextEditingController(text: formatAmount(widget.offer.offeredPrice));
  late final _quantityController = TextEditingController(text: formatAmount(widget.offer.offeredQuantity));
  final _fulfillmentService = FulfillmentService();
  late OfferFulfillment? _fulfillment = widget.offer.fulfillment;
  SellerFulfillment? _reach;
  String? _error;

  NegotiationRecord get offer => widget.offer;

  @override
  void initState() {
    super.initState();
    _fulfillmentService.fetchForListing(offer.productId).then((reach) {
      if (mounted) setState(() => _reach = reach);
    }).catchError((Object _) {
      // The picker keeps spinning; price and quantity can still be countered.
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _fulfillmentService.dispose();
    super.dispose();
  }

  // The seller picked a center or courier outside their usual area.
  bool get _farther {
    final reach = _reach;
    final value = _fulfillment;
    if (!widget.bySeller || reach == null || !isCompleteFulfillment(value)) return false;
    return value!.isPickup ? !reach.supportsCenter('${value.centerId}') : !reach.supportsCourier(value.courierName!);
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
    final fulfillment = _fulfillment;
    if (fulfillment != null && !isCompleteFulfillment(fulfillment)) {
      setState(() => _error = fulfillment.isPickup ? 'Pick a bagsakan center.' : 'Pick a courier.');
      return;
    }
    final handoverChanged = fulfillment != null && fulfillment != offer.fulfillment;
    if (price == offer.offeredPrice && quantity == offer.offeredQuantity && !handoverChanged) {
      setState(() => _error = 'Change the price, quantity or handover, or accept the offer instead.');
      return;
    }
    Navigator.of(context).pop(CounterOffer(
      price: price,
      quantity: quantity,
      fulfillment: handoverChanged ? fulfillment : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final current = [
      'PHP ${formatAmount(offer.offeredPrice)} / ${offer.unit} × ${formatAmount(offer.offeredQuantity)} ${offer.unit}',
      if (offer.fulfillment != null) offer.fulfillment!.label,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Text(
                    'Counter on ${offer.cropName}',
                    style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text('On the table: $current', style: const TextStyle(color: AppColors.gray, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text(
                    'Your counter replaces this offer.',
                    style: TextStyle(color: AppColors.gray, fontSize: 12),
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
                  const SizedBox(height: 20),
                  FulfillmentPicker(
                    reach: _reach,
                    allowsMeetup: offer.allowsMeetup,
                    allowsDelivery: offer.allowsDelivery,
                    value: _fulfillment,
                    chooser: widget.bySeller ? FulfillmentChooser.seller : FulfillmentChooser.buyer,
                    onChanged: (value) => setState(() {
                      _fulfillment = value;
                      _error = null;
                    }),
                  ),
                  if (_farther)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.local_gas_station_outlined, size: 16, color: AppColors.black),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Farther than you usually go. You can raise the price per unit to cover the extra transport.',
                              style: TextStyle(color: AppColors.black, fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.black,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Send counter', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks the seller why they are declining, from a short list, before the
/// decline goes through, so the buyer knows what to change. Resolves to the
/// picked reason, or null when the seller backs out.
Future<DeclineReason?> showDeclineReasonDialog(BuildContext context) {
  return showModalBottomSheet<DeclineReason>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _DeclineReasonSheet(),
  );
}

class _DeclineReasonSheet extends StatefulWidget {
  const _DeclineReasonSheet();

  @override
  State<_DeclineReasonSheet> createState() => _DeclineReasonSheetState();
}

class _DeclineReasonSheetState extends State<_DeclineReasonSheet> {
  DeclineReason? _reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Decline this offer?', style: TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Pick a reason. The buyer sees it in the chat, so they know what to change.',
              style: TextStyle(color: AppColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in DeclineReason.values)
                  ChoiceChip(
                    label: Text(reason.label),
                    selected: _reason == reason,
                    onSelected: (selected) => setState(() => _reason = selected ? reason : null),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: _reason == reason ? AppColors.green : AppColors.black,
                      fontWeight: _reason == reason ? FontWeight.w700 : FontWeight.w500,
                    ),
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? AppColors.green.withValues(alpha: 0.1) : AppColors.white,
                    ),
                    shape: StadiumBorder(side: BorderSide(color: _reason == reason ? AppColors.green : AppColors.border)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Keep offer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _reason == null ? null : () => Navigator.of(context).pop(_reason),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `120` for whole numbers, `120.5` otherwise — keeps `kg` labels tidy.
String formatAmount(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
