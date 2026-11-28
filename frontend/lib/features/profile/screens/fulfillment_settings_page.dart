import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/fulfillment_service.dart';
import '../../../shared/widgets/kubo_page_app_bar.dart';

/// Where a seller ships from and how they can hand produce over: the
/// bagsakan centers they drop off at and the couriers they can book. Buyers'
/// offer forms only offer what is ticked here, so no offer asks for a
/// center the seller cannot reach.
///
/// Two versions of the page:
///  * [FulfillmentSettingsPage.profile]: the seller's own settings, used by
///    every listing that does not have its own.
///  * [FulfillmentSettingsPage.listing]: optional choices for one listing.
///    Off by default (the listing follows the profile). Turning it on never
///    changes the profile; turning it off sends the listing back to it.
///
/// Nothing ticked in a list means it is not narrowed down, and buyers may
/// pick any.
class FulfillmentSettingsPage extends StatefulWidget {
  const FulfillmentSettingsPage.profile({super.key, required int this.userId, this.service})
      : productId = null,
        listingTitle = null;

  const FulfillmentSettingsPage.listing({super.key, required int this.productId, required String this.listingTitle, this.service})
      : userId = null;

  /// Set for the profile version.
  final int? userId;

  /// Set for the listing version.
  final int? productId;
  final String? listingTitle;

  /// Injected in tests; a real client otherwise.
  final FulfillmentService? service;

  @override
  State<FulfillmentSettingsPage> createState() => _FulfillmentSettingsPageState();
}

class _FulfillmentSettingsPageState extends State<FulfillmentSettingsPage> {
  late final FulfillmentService _service = widget.service ?? FulfillmentService();
  SellerFulfillment? _loaded;
  String? _error;
  bool _saving = false;

  /// Listing version only: the listing has its own choices.
  bool _custom = false;

  // Ticked ids / names. Seeded from what was saved, not from the "everything
  // counts" default of lists nobody narrowed down.
  final Set<String> _centers = <String>{};
  final Set<String> _couriers = <String>{};

  bool get _isListing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final loaded = _isListing ? await _service.fetchForListing(widget.productId!) : await _service.fetch(widget.userId!);
      if (!mounted) return;
      setState(() {
        _loaded = loaded;
        _custom = loaded.isListingOwn;
        _seedFrom(loaded);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _seedFrom(SellerFulfillment choices) {
    _centers
      ..clear()
      ..addAll(choices.configuredCenters ? choices.centers.where((c) => c.supported).map((c) => c.center.id) : const <String>[]);
    _couriers
      ..clear()
      ..addAll(choices.configuredCouriers ? choices.couriers.where((c) => c.supported).map((c) => c.name) : const <String>[]);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final centerIds = _centers.map(int.parse).toList();
      final couriers = _couriers.toList();
      final saved = _isListing
          ? await _service.saveForListing(productId: widget.productId!, custom: _custom, centerIds: centerIds, couriers: couriers)
          : await _service.save(sellerId: widget.userId!, centerIds: centerIds, couriers: couriers);
      if (!mounted) return;
      setState(() => _loaded = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isListing
            ? (_custom ? 'This listing now uses its own pickup and delivery options.' : 'This listing now follows your profile settings.')
            : 'Pickup and delivery options saved.'),
      ));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _loaded;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: KuboPageAppBar(title: _isListing ? 'Listing Pickup & Delivery' : 'Pickup & Delivery'),
      body: loaded == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: AppColors.green)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray)),
                          TextButton(onPressed: _load, child: const Text('Try Again')),
                        ],
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (_isListing) ..._listingSwitch(),
                const _Heading('Ships from'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.softBackground, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.store_mall_directory_outlined, color: AppColors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loaded.originLabel.isEmpty ? 'Add an address to your profile' : loaded.originLabel,
                          style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Buyers choosing courier delivery see "Pickup from" this area. Change it in Edit profile.',
                  style: TextStyle(color: AppColors.gray, fontSize: 12),
                ),
                const SizedBox(height: 24),
                if (_isListing && !_custom) ..._followingProfile(loaded) else ..._choices(loaded),
              ],
            ),
      bottomNavigationBar: loaded == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
    );
  }

  // Listing version: whether this listing follows the profile.
  List<Widget> _listingSwitch() {
    return [
      Text(
        widget.listingTitle!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: SwitchListTile(
          value: !_custom,
          activeThumbColor: AppColors.green,
          title: const Text('Use My Profile Settings', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_custom
              ? 'This listing has its own centers and couriers. Your profile settings are not changed.'
              : 'This listing offers the centers and couriers set on your profile.'),
          onChanged: _saving
              ? null
              : (useProfile) => setState(() {
                    _custom = !useProfile;
                    // Starting from the profile's choices is the usual case:
                    // the seller drops or adds one or two for this listing.
                    if (_custom && !(_loaded?.isListingOwn ?? false)) _seedFrom(_loaded!);
                  }),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  // Listing version while it follows the profile: what buyers will see,
  // read-only, and where to change it.
  List<Widget> _followingProfile(SellerFulfillment loaded) {
    final centers = loaded.centers.where((c) => c.supported).map((c) => c.center.name).toList();
    final couriers = loaded.couriers.where((c) => c.supported).map((c) => c.name).toList();
    return [
      const _Heading('Bagsakan Centers'),
      const SizedBox(height: 4),
      _Hint(loaded.configuredCenters ? centers.join(' · ') : 'Any center'),
      const SizedBox(height: 16),
      const _Heading('Couriers'),
      const SizedBox(height: 4),
      _Hint(loaded.configuredCouriers ? couriers.join(' · ') : 'Any courier'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.softBackground, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.gray),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'These come from your profile. To change them for every listing, go to Account settings → Pickup & delivery. '
                'To change them for this listing only, turn off "Use my profile settings".',
                style: TextStyle(color: AppColors.gray, fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _choices(SellerFulfillment loaded) {
    return [
      const _Heading('Bagsakan centers you drop off at'),
      const SizedBox(height: 2),
      _Hint(_centers.isEmpty ? 'None ticked: buyers can pick any center.' : 'Buyers can only pick the ${_centers.length} ticked.'),
      for (final entry in loaded.centers)
        CheckboxListTile(
          value: _centers.contains(entry.center.id),
          onChanged: _saving
              ? null
              : (ticked) => setState(() => ticked == true ? _centers.add(entry.center.id) : _centers.remove(entry.center.id)),
          title: Text(entry.center.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(entry.center.locationLabel),
          activeColor: AppColors.green,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      const SizedBox(height: 16),
      const _Heading('Couriers You Can Book'),
      const SizedBox(height: 2),
      _Hint(_couriers.isEmpty ? 'None ticked: buyers can pick any courier.' : 'Buyers can only pick the ${_couriers.length} ticked.'),
      for (final entry in loaded.couriers)
        CheckboxListTile(
          value: _couriers.contains(entry.name),
          onChanged: _saving
              ? null
              : (ticked) => setState(() => ticked == true ? _couriers.add(entry.name) : _couriers.remove(entry.name)),
          title: Text(entry.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          activeColor: AppColors.green,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      if (!_isListing) ...[
        const SizedBox(height: 8),
        const _Hint('Listings you gave their own options keep them.'),
      ],
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w800));
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.gray, fontSize: 12));
  }
}
