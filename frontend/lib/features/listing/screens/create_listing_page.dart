import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_service.dart';
import '../../login/services/auth_service.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _service = ListingService();
  String _category = 'vegetable';
  String _unit = 'kg';
  bool _isSaving = false;

  static const _images = <String>[
    'https://picsum.photos/id/1018/600/400',
    'https://picsum.photos/id/1015/600/400',
    'https://picsum.photos/id/1016/600/400',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sellerId = int.tryParse(AuthService.currentUser?['user_id']?.toString() ?? '');
    if (sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before creating a listing')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _service.createListing(
        sellerId: sellerId,
        cropName: _nameController.text.trim(),
        category: _category,
        price: double.parse(_priceController.text),
        quantity: double.parse(_quantityController.text),
        unit: _unit,
        images: _images,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Create Listing'), backgroundColor: AppColors.white),
      backgroundColor: AppColors.white,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Add your produce', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('List your produce in just a few quick steps', style: TextStyle(color: AppColors.gray)),
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
            SizedBox(height: 52, child: ElevatedButton(onPressed: _isSaving ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white), child: Text(_isSaving ? 'Publishing...' : 'Publish listing'))),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
  String? _positiveNumber(String? value) => value == null || double.tryParse(value) == null || double.parse(value) <= 0 ? 'Enter a positive number' : null;
}