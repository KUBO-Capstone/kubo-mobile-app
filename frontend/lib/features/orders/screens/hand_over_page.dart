import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/order_service.dart';
import '../../../shared/widgets/photo_picker_strip.dart';
import '../../chat/widgets/counter_offer_dialog.dart' show formatAmount;

/// Most handover photos one order can carry; matches the backend limit.
const maxHandoverPhotos = 5;

/// What the seller records when the produce leaves their hands.
class HandoverDetails {
  const HandoverDetails({required this.courierName, required this.trackingNumber, required this.photos});

  /// Empty for a bagsakan drop-off, and when the seller leaves it blank.
  final String courierName;
  final String trackingNumber;

  /// Server paths of the uploaded photos.
  final List<String> photos;
}

/// The seller hands the order over: to the courier (courier, tracking
/// number) or at the bagsakan center, with optional photos of the produce as
/// it left. Everything entered here shows on the order for both sides.
///
/// [uploadPhotos] stores the photos and returns their server paths; [ship]
/// sends the details and resolves to an error to show, or null when done.
/// Pops with true once the order is marked.
class HandOverPage extends StatefulWidget {
  const HandOverPage({super.key, required this.order, required this.uploadPhotos, required this.ship, this.picker});

  final OrderRecord order;
  final Future<List<String>> Function(List<File> files) uploadPhotos;
  final Future<String?> Function(HandoverDetails details) ship;

  /// Injected in tests.
  final ImagePicker? picker;

  @override
  State<HandOverPage> createState() => _HandOverPageState();
}

class _HandOverPageState extends State<HandOverPage> {
  late final _courier = TextEditingController(text: widget.order.courierName ?? '');
  final _tracking = TextEditingController();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  final List<File> _photos = <File>[];

  /// Server paths of [_photos] once uploaded, so a retry after a failed
  /// ship does not upload them again.
  List<String>? _uploaded;
  bool _submitting = false;

  OrderRecord get order => widget.order;

  @override
  void dispose() {
    _courier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picked = await pickPhotos(context, _picker, remaining: maxHandoverPhotos - _photos.length, max: maxHandoverPhotos);
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(picked);
      _uploaded = null;
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _uploaded = null;
    });
  }

  Future<void> _pasteTracking() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    _tracking.text = text.length > 100 ? text.substring(0, 100) : text;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    try {
      var photos = _uploaded;
      if (photos == null) {
        photos = _photos.isEmpty ? const <String>[] : await widget.uploadPhotos(List<File>.of(_photos));
        if (photos.length != _photos.length) {
          throw Exception('Some photos could not be uploaded. Please use JPG, PNG, or WebP photos.');
        }
        _uploaded = photos;
      }
      error = await widget.ship(HandoverDetails(
        courierName: order.isMeetup ? '' : _courier.text.trim(),
        trackingNumber: order.isMeetup ? '' : _tracking.text.trim(),
        photos: photos,
      ));
    } catch (caught) {
      error = caught.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    if (error != null) {
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(order.isMeetup
          ? '${order.buyerName} can see it is ready for pickup.'
          : 'Marked as shipped. ${order.buyerName} can see the details on the order.'),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final meetup = order.isMeetup;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(meetup ? 'Drop off at the center' : 'Hand over to courier'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _OrderLine(order: order),
          const SizedBox(height: 20),
          if (meetup) ..._dropOff() else ..._courierFields(),
          const SizedBox(height: 24),
          PhotoPickerStrip(
            title: 'Photo of the produce (optional)',
            photos: _photos,
            max: maxHandoverPhotos,
            onAdd: _submitting ? null : _addPhoto,
            onRemove: _submitting ? null : _removePhoto,
            helper: meetup
                ? 'Show how it was packed and left at the center. ${order.buyerName} sees it on the order.'
                : 'Show the packed produce or the parcel as handed over. ${order.buyerName} sees it on the order.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                  : Text(meetup ? 'Mark as dropped off' : 'Mark as shipped', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dropOff() {
    final address = [
      if ((order.centerAddress ?? '').isNotEmpty) order.centerAddress!,
      if ((order.centerLocation ?? '').isNotEmpty) order.centerLocation!,
    ].join(', ');
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.softBackground, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warehouse_outlined, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.centerName ?? 'Bagsakan center',
                    style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (address.isNotEmpty) Text(address, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Mark it once the produce is at the center. ${order.buyerName} is told it is ready for pickup.',
        style: const TextStyle(color: AppColors.gray, fontSize: 12),
      ),
    ];
  }

  List<Widget> _courierFields() {
    final agreed = order.courierName;
    return [
      TextField(
        controller: _courier,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.words,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: 'Courier',
          hintText: 'e.g. J&T Express, LBC, Lalamove',
          helperText: (agreed ?? '').isEmpty ? null : 'Agreed in the offer',
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _tracking,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.characters,
        maxLength: 100,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Tracking number',
          helperText: '${order.buyerName} can copy it from the order.',
          border: const OutlineInputBorder(),
          counterText: '',
          suffixIcon: IconButton(
            tooltip: 'Paste tracking number',
            icon: const Icon(Icons.content_paste),
            onPressed: _submitting ? null : _pasteTracking,
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Both are optional. You can also send the tracking link in the chat.',
        style: TextStyle(color: AppColors.gray, fontSize: 12),
      ),
    ];
  }
}

/// What is being handed over and to whom, at the top of the page.
class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${order.id} · ${order.cropName}',
            style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatAmount(order.quantity)} ${order.unit} for ${order.buyerName}',
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
