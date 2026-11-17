import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/fulfillment_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/order_service.dart';

/// Who is choosing how the produce changes hands, which decides what an
/// option outside the seller's reach does.
enum FulfillmentChooser {
  /// The buyer making an offer: what the seller cannot do is greyed out and
  /// cannot be picked, so no offer asks for the impossible.
  buyer,

  /// The seller countering: their own usual centers and couriers come
  /// first, but anything can be picked, e.g. to take a farther center and
  /// price the extra trip in.
  seller,
}

/// Pickup or courier, then which center or which courier. Shared by the
/// buyer's offer form and the seller's counter so both read the same.
class FulfillmentPicker extends StatelessWidget {
  const FulfillmentPicker({
    super.key,
    required this.reach,
    required this.allowsMeetup,
    required this.allowsDelivery,
    required this.value,
    required this.onChanged,
    required this.chooser,
    this.enabled = true,
  });

  /// What the seller can do; null while it loads.
  final SellerFulfillment? reach;

  /// The listing's deal methods; a method it does not offer is not shown.
  final bool allowsMeetup;
  final bool allowsDelivery;

  final OfferFulfillment? value;
  final ValueChanged<OfferFulfillment?> onChanged;
  final FulfillmentChooser chooser;
  final bool enabled;

  bool get _isBuyer => chooser == FulfillmentChooser.buyer;

  // The method currently showing: the chosen one, or the only one there is.
  DeliveryMethod? get _method {
    if (value != null) return value!.method;
    if (allowsMeetup && !allowsDelivery) return DeliveryMethod.meetup;
    if (allowsDelivery && !allowsMeetup) return DeliveryMethod.courier;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reach = this.reach;
    final method = _method;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('How will it change hands?'),
        const SizedBox(height: 8),
        Row(
          children: [
            if (allowsMeetup)
              Expanded(
                child: _MethodChoice(
                  icon: Icons.warehouse_outlined,
                  label: 'Pickup',
                  selected: method == DeliveryMethod.meetup,
                  onTap: enabled ? () => _chooseMethod(DeliveryMethod.meetup) : null,
                ),
              ),
            if (allowsMeetup && allowsDelivery) const SizedBox(width: 8),
            if (allowsDelivery)
              Expanded(
                child: _MethodChoice(
                  icon: Icons.local_shipping_outlined,
                  label: 'Courier delivery',
                  selected: method == DeliveryMethod.courier,
                  onTap: enabled ? () => _chooseMethod(DeliveryMethod.courier) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (method == null)
          const SizedBox.shrink()
        else if (reach == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green)),
            ),
          )
        else if (method == DeliveryMethod.meetup)
          ..._centers(reach)
        else
          ..._couriers(reach),
      ],
    );
  }

  void _chooseMethod(DeliveryMethod method) {
    if (_method == method && value != null) return;
    // A method alone is not terms yet: the center or courier comes next.
    // When only one is supported, it is picked to save a tap.
    final reach = this.reach;
    if (reach != null && method == DeliveryMethod.meetup) {
      final usable = reach.centers.where((entry) => entry.supported).toList();
      if (usable.length == 1) {
        onChanged(OfferFulfillment.pickup(centerId: int.parse(usable.first.center.id), centerName: usable.first.center.name));
        return;
      }
    }
    if (reach != null && method == DeliveryMethod.courier) {
      final usable = reach.couriers.where((entry) => entry.supported).toList();
      if (usable.length == 1) {
        onChanged(OfferFulfillment.courier(courierName: usable.first.name));
        return;
      }
    }
    onChanged(_placeholder(method));
  }

  // A method with nothing picked yet: an id of 0 / an empty courier name,
  // which [isCompleteFulfillment] reads as not ready to send.
  OfferFulfillment _placeholder(DeliveryMethod method) => method == DeliveryMethod.meetup
      ? const OfferFulfillment.pickup(centerId: 0)
      : const OfferFulfillment.courier(courierName: '');

  List<Widget> _centers(SellerFulfillment reach) {
    final entries = [...reach.centers]
      ..sort((a, b) => (b.supported ? 1 : 0) - (a.supported ? 1 : 0));
    if (entries.isEmpty) {
      return const [_Note('No bagsakan centers are set up yet. Choose courier delivery instead.')];
    }
    return [
      if (_isBuyer && reach.configuredCenters)
        const _Note('Showing the centers this seller drops off at.'),
      for (final entry in entries)
        _OptionTile(
          icon: Icons.location_on_outlined,
          title: entry.center.name,
          subtitle: [if (entry.center.addressLine.isNotEmpty) entry.center.addressLine, entry.center.locationLabel].join(', '),
          selected: value?.centerId == int.tryParse(entry.center.id),
          available: entry.supported || !_isBuyer,
          unavailableNote: entry.supported
              ? null
              : _isBuyer
                  ? "Not serviceable in seller's area"
                  : 'Outside your usual centers',
          onTap: !enabled || (!entry.supported && _isBuyer)
              ? null
              : () => onChanged(OfferFulfillment.pickup(centerId: int.parse(entry.center.id), centerName: entry.center.name)),
        ),
    ];
  }

  List<Widget> _couriers(SellerFulfillment reach) {
    final entries = [...reach.couriers]
      ..sort((a, b) => (b.supported ? 1 : 0) - (a.supported ? 1 : 0));
    return [
      if (reach.originLabel.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.store_mall_directory_outlined, size: 16, color: AppColors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pickup from ${reach.originLabel}',
                  style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      for (final entry in entries)
        _OptionTile(
          icon: Icons.local_shipping_outlined,
          title: entry.name,
          selected: value?.courierName == entry.name,
          available: entry.supported || !_isBuyer,
          unavailableNote: entry.supported
              ? null
              : _isBuyer
                  ? "Not serviceable in seller's area"
                  : 'Not one you usually book',
          onTap: !enabled || (!entry.supported && _isBuyer) ? null : () => onChanged(OfferFulfillment.courier(courierName: entry.name)),
        ),
    ];
  }
}

/// Whether [value] names a real center or courier, not just a method.
bool isCompleteFulfillment(OfferFulfillment? value) {
  if (value == null) return false;
  return value.isPickup ? (value.centerId ?? 0) > 0 : (value.courierName ?? '').isNotEmpty;
}

class _MethodChoice extends StatelessWidget {
  const _MethodChoice({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.green.withValues(alpha: 0.08) : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.green : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.green : AppColors.gray),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.green : AppColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.available,
    required this.onTap,
    this.subtitle,
    this.unavailableNote,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;

  /// False greys the row out; a buyer cannot pick it.
  final bool available;
  final String? unavailableNote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.black : AppColors.gray;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: available ? 1 : 0.55,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: available ? AppColors.white : AppColors.softBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? AppColors.green : AppColors.border, width: selected ? 1.6 : 1),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? AppColors.green : AppColors.gray),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                      if ((subtitle ?? '').isNotEmpty)
                        Text(subtitle!, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
                      if (unavailableNote != null)
                        Text(
                          unavailableNote!,
                          style: TextStyle(
                            color: available ? Colors.orange.shade800 : AppColors.gray,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: selected ? AppColors.green : AppColors.border,
                ),
              ],
            ),
          ),
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
    return Text(text, style: const TextStyle(color: AppColors.gray, fontSize: 14, fontWeight: FontWeight.w600));
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
    );
  }
}
