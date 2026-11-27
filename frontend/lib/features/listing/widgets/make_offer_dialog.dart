import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/amount_input.dart';
import '../../../shared/data/fulfillment_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../login/services/auth_service.dart';
import '../../profile/widgets/complete_profile_prompt.dart';
import 'fulfillment_picker.dart';

/// Opens the offer form for [listing] and returns the created negotiation,
/// or null if the user dismissed it or the offer was refused.
///
/// The buyer names a price, a quantity and how the produce changes hands.
/// Only the bagsakan centers and couriers the seller can work with can be
/// picked, so the seller never gets an offer they cannot fulfil.
Future<NegotiationRecord?> showMakeOfferDialog(
  BuildContext context,
  SyntheticListingRecord listing,
) {
  final messenger = ScaffoldMessenger.of(context);
  final buyerId = AuthService.currentUserId;

  // These are the cases the server would reject anyway; catching them here
  // keeps the form from opening on something that can never succeed.
  if (buyerId == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Log in to make an offer.')));
    return Future.value(null);
  }
  if (listing.isSoldOut) {
    messenger.showSnackBar(const SnackBar(content: Text('This listing is sold out.')));
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
  // An account made with Google has no contact number or address yet.
  if (!ensureProfileComplete(context, toDo: 'make an offer')) {
    return Future.value(null);
  }

  return showModalBottomSheet<NegotiationRecord>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _MakeOfferSheet(listing: listing),
  );
}

class _MakeOfferSheet extends StatefulWidget {
  const _MakeOfferSheet({required this.listing});

  final SyntheticListingRecord listing;

  @override
  State<_MakeOfferSheet> createState() => _MakeOfferSheetState();
}

class _MakeOfferSheetState extends State<_MakeOfferSheet> {
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _service = NegotiationService();
  final _fulfillmentService = FulfillmentService();
  SellerFulfillment? _reach;
  String? _reachError;
  OfferFulfillment? _fulfillment;
  bool _submitting = false;
  String? _error;

  SyntheticListingRecord get listing => widget.listing;
  String get unit => listing.unit ?? 'unit';

  @override
  void initState() {
    super.initState();
    _loadReach();
  }

  Future<void> _loadReach() async {
    setState(() => _reachError = null);
    try {
      // The listing's own choices, or the seller's profile ones.
      final reach = await _fulfillmentService.fetchForListing(listing.productId!);
      if (mounted) setState(() => _reach = reach);
    } catch (error) {
      if (mounted) setState(() => _reachError = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _service.dispose();
    _fulfillmentService.dispose();
    super.dispose();
  }

  /// Set by Make Offer: from then on an empty field is marked too.
  bool _submitted = false;

  /// Shown under the price field as it is typed: not a number, too many
  /// decimals, zero, or (after Make Offer) empty.
  String? get _priceError => amountInputError(
        _priceController.text,
        what: 'your price per $unit',
        maxDecimals: 2,
        required: _submitted,
      );

  /// Shown under the quantity field as it is typed: the same checks, plus
  /// asking for more than the listing has left.
  String? get _quantityError => amountInputError(
        _quantityController.text,
        what: 'a quantity',
        maxDecimals: 3,
        required: _submitted,
        max: listing.availableQuantity,
        unit: unit,
      );

  Future<void> _submit() async {
    setState(() => _submitted = true);
    // The fields already say what is wrong, in red under themselves.
    if (_priceError != null || _quantityError != null) return;
    final price = double.parse(_priceController.text.trim());
    final quantity = double.parse(_quantityController.text.trim());
    final fulfillment = _fulfillment;
    if (!isCompleteFulfillment(fulfillment)) {
      setState(() => _error = fulfillment == null
          ? 'Choose pickup or courier delivery.'
          : fulfillment.isPickup
              ? 'Pick a bagsakan center.'
              : 'Pick a courier.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final offer = await _service.createOffer(
        productId: listing.productId!,
        price: price,
        quantity: quantity,
        fulfillment: fulfillment!,
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

    return Padding(
      // Lifts the sheet above the keyboard.
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
                    '${listing.sellerLabel} listed ${listing.title} for $asking',
                    style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
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
                    errorText: _priceError,
                    onChanged: (_) => setState(() {}),
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
                    errorText: _quantityError,
                    // Re-checks the format and what is available on every keystroke.
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  if (_reachError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Could not load the seller's pickup and delivery options. $_reachError",
                          style: const TextStyle(color: AppColors.gray, fontSize: 12),
                        ),
                        TextButton(onPressed: _loadReach, child: const Text('Try Again')),
                      ],
                    )
                  else
                    FulfillmentPicker(
                      reach: _reach,
                      allowsMeetup: listing.allowsMeetup,
                      allowsDelivery: listing.allowsDelivery,
                      value: _fulfillment,
                      chooser: FulfillmentChooser.buyer,
                      enabled: !_submitting,
                      onChanged: (value) => setState(() {
                        _fulfillment = value;
                        _error = null;
                      }),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4)),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
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
                        : const Text('Make Offer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
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
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool enabled;
  final bool autofocus;

  /// Turns the outline red and is shown under the field when set.
  final String? errorText;
  final ValueChanged<String>? onChanged;

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
      onChanged: onChanged,
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
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
        errorBorder: border(Colors.redAccent, 1.5),
        focusedErrorBorder: border(Colors.redAccent, 1.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

/// Drops a trailing `.0` so quantities read as `30 kg`, not `30.0 kg`.
String _trim(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
