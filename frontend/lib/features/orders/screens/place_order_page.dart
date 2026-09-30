import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/bagsakan_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/order_service.dart';
import '../../chat/widgets/counter_offer_dialog.dart';
import '../../explore/models/bagsakan_center.dart';
import '../../login/services/auth_service.dart';

/// Buyer turns an accepted offer into an order: pick up at a bagsakan
/// center, or have it couriered. Pops with the placed [OrderRecord].
class PlaceOrderPage extends StatefulWidget {
  const PlaceOrderPage({super.key, required this.offer});

  /// The accepted negotiation being ordered.
  final NegotiationRecord offer;

  @override
  State<PlaceOrderPage> createState() => _PlaceOrderPageState();
}

class _PlaceOrderPageState extends State<PlaceOrderPage> {
  final _orders = OrderService();
  final _bagsakan = BagsakanService();

  DeliveryMethod _method = DeliveryMethod.meetup;
  List<BagsakanCenter> _centers = const [];
  BagsakanCenter? _center;
  bool _loadingCenters = true;
  String? _centersError;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  @override
  void dispose() {
    _orders.dispose();
    _bagsakan.dispose();
    super.dispose();
  }

  Future<void> _loadCenters() async {
    setState(() {
      _loadingCenters = true;
      _centersError = null;
    });
    try {
      final centers = await _bagsakan.fetchCenters();
      if (!mounted) return;
      setState(() {
        _centers = centers;
        _center ??= centers.isEmpty ? null : centers.first;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _centersError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingCenters = false);
    }
  }

  bool get _canPlace =>
      !_placing && (_method == DeliveryMethod.courier || _center != null);

  Future<void> _place() async {
    final buyerId = AuthService.currentUserId;
    if (buyerId == null) return;
    setState(() => _placing = true);
    try {
      final order = await _orders.placeOrder(
        negotiationId: widget.offer.id,
        method: _method,
        centerId: _method == DeliveryMethod.meetup ? int.tryParse(_center!.id) : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } catch (error) {
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ARRANGE PICKUP',
          style: TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SummaryCard(offer: offer),
          const SizedBox(height: 20),
          const _SectionTitle('How will you get it?'),
          const SizedBox(height: 8),
          _MethodTile(
            selected: _method == DeliveryMethod.meetup,
            icon: Icons.warehouse_outlined,
            title: 'Pick up at a bagsakan center',
            subtitle: 'The farmer drops it at the center; you collect it there.',
            onTap: () => setState(() => _method = DeliveryMethod.meetup),
          ),
          const SizedBox(height: 8),
          _MethodTile(
            selected: _method == DeliveryMethod.courier,
            icon: Icons.local_shipping_outlined,
            title: 'Courier delivery',
            subtitle: 'The farmer books a courier and shares the tracking number.',
            onTap: () => setState(() => _method = DeliveryMethod.courier),
          ),
          if (_method == DeliveryMethod.meetup) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Which center?'),
            const SizedBox(height: 8),
            _buildCenterPicker(),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canPlace ? _place : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _placing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : Text(
                      'Place order · PHP ${formatAmount(offer.total)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment is settled with the farmer at handover. Kubo does not take payments yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPicker() {
    if (_loadingCenters) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    final error = _centersError;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
          TextButton(onPressed: _loadCenters, child: const Text('Retry')),
        ],
      );
    }
    if (_centers.isEmpty) {
      return const Text(
        'No bagsakan centers are set up yet. Choose courier delivery instead.',
        style: TextStyle(color: AppColors.gray, fontSize: 12),
      );
    }
    return Column(
      children: [
        for (final center in _centers) ...[
          _CenterTile(
            center: center,
            selected: _center?.id == center.id,
            onTap: () => setState(() => _center = center),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.offer});

  final NegotiationRecord offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.cropName,
            style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'from ${offer.sellerName}',
            style: const TextStyle(color: AppColors.gray, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _Line('Agreed price', 'PHP ${formatAmount(offer.offeredPrice)} / ${offer.unit}'),
          _Line('Quantity', '${formatAmount(offer.offeredQuantity)} ${offer.unit}'),
          const Divider(height: 16, color: AppColors.border),
          _Line('Total', 'PHP ${formatAmount(offer.total)}', bold: true),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.black,
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 12))),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.green : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.green : AppColors.gray),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
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
    );
  }
}

class _CenterTile extends StatelessWidget {
  const _CenterTile({required this.center, required this.selected, required this.onTap});

  final BagsakanCenter center;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.green : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(center.name, style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [if (center.addressLine.isNotEmpty) center.addressLine, center.locationLabel].join(', '),
                    style: const TextStyle(color: AppColors.gray, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: selected ? AppColors.green : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
