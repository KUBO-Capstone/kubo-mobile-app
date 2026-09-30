import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../login/services/auth_service.dart';

/// Create form for a new listing, or the edit form when [existing] is given.
///
/// Pops with the saved [SyntheticListingRecord] on success so the caller can
/// refresh without another fetch.
class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key, this.existing});

  /// Listing being edited; null means create.
  final SyntheticListingRecord? existing;

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  final _service = ListingService();
  late String _category;
  late String _unit;
  bool _isSaving = false;

  static const _images = <String>[
    'https://picsum.photos/id/1018/600/400',
    'https://picsum.photos/id/1015/600/400',
    'https://picsum.photos/id/1016/600/400',
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.title ?? '');
    _priceController = TextEditingController(text: _formatNumber(existing?.basePrice));
    _quantityController = TextEditingController(text: _formatNumber(existing?.availableQuantity));
    _category = existing?.groups.firstOrNull ?? 'vegetable';
    _unit = existing?.unit ?? 'kg';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _service.dispose();
    super.dispose();
  }

  // Prefills "12" rather than "12.0" for whole numbers.
  static String _formatNumber(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sellerId = AuthService.currentUserId;
    if (sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in before ${_isEditing ? 'editing' : 'creating'} a listing')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final existing = widget.existing;
      final SyntheticListingRecord saved;
      if (existing != null) {
        saved = await _service.updateListing(
          productId: existing.productId!,
          cropName: _nameController.text.trim(),
          category: _category,
          price: double.parse(_priceController.text),
          quantity: double.parse(_quantityController.text),
          unit: _unit,
        );
      } else {
        saved = await _service.createListing(
          cropName: _nameController.text.trim(),
          category: _category,
          price: double.parse(_priceController.text),
          quantity: double.parse(_quantityController.text),
          unit: _unit,
          images: _images,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.softBackground,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Listing' : 'Create Listing'), backgroundColor: AppColors.white),
      backgroundColor: AppColors.white,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_isEditing ? 'Update your produce' : 'Add your produce', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_isEditing ? 'Changes show up for buyers right away' : 'List your produce in just a few quick steps', style: const TextStyle(color: AppColors.gray)),
            const SizedBox(height: 24),
            TextFormField(controller: _nameController, decoration: _decoration('Product name'), validator: _required),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(initialValue: _category, decoration: _decoration('Category'), items: const ['vegetable', 'fruit', 'grain', 'legume', 'herb', 'spice'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _category = value!)),
            const SizedBox(height: 14),
            TextFormField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _decoration('Price (PHP)'), validator: _positiveNumber),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextFormField(controller: _quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _decoration('Available quantity'), validator: _positiveNumber)),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _unit, decoration: _decoration('Unit'), items: const ['kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _unit = value!))),
            ]),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white),
                child: Text(_isSaving ? (_isEditing ? 'Saving...' : 'Publishing...') : (_isEditing ? 'Save changes' : 'Publish listing')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
  String? _positiveNumber(String? value) => value == null || double.tryParse(value) == null || double.parse(value) <= 0 ? 'Enter a positive number' : null;
}
