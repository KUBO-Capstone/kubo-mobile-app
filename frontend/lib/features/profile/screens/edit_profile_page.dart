import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _contactNumber;
  late final TextEditingController _bio;
  late final TextEditingController _region;
  late final TextEditingController _province;
  late final TextEditingController _city;
  late final TextEditingController _barangay;
  late final TextEditingController _zip;
  late final TextEditingController _street;
  late final TextEditingController _landmark;
  final ProfileService _service = ProfileService();
  final ImagePicker _picker = ImagePicker();
  File? _photo;
  bool _saving = false;
  List<Map<String, dynamic>> _addresses = [];
  int? _selectedAddressId;
  bool _newAddress = false;

  int get _userId => int.parse(widget.user['user_id'].toString());

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.user['first_name']?.toString());
    _lastName = TextEditingController(text: widget.user['last_name']?.toString());
    _contactNumber = TextEditingController(text: widget.user['contact_number']?.toString());
    _bio = TextEditingController(text: widget.user['bio']?.toString() ?? '');
    _region = TextEditingController();
    _province = TextEditingController();
    _city = TextEditingController();
    _barangay = TextEditingController();
    _zip = TextEditingController();
    _street = TextEditingController();
    _landmark = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.fetchProfile(_userId);
      if (!mounted) return;
      final raw = profile['addresses'];
      if (raw is List) {
        _addresses = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      _selectedAddressId = profile['preferred_address_id'] as int?;
      _loadAddress(_addresses.cast<Map<String, dynamic>>().firstWhere(
        (address) => address['address_id'] == _selectedAddressId,
        orElse: () => <String, dynamic>{},
      ));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _loadAddress(Map<String, dynamic> address) {
    _region.text = address['region']?.toString() ?? '';
    _province.text = address['province']?.toString() ?? '';
    _city.text = address['city_municipality']?.toString() ?? '';
    _barangay.text = address['barangay']?.toString() ?? '';
    _zip.text = address['zip_code']?.toString() ?? '';
    _street.text = address['street_details']?.toString() ?? '';
    _landmark.text = address['landmark']?.toString() ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _contactNumber.dispose();
    _bio.dispose();
    for (final controller in [_region, _province, _city, _barangay, _zip, _street, _landmark]) {
      controller.dispose();
    }
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty || _contactNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and contact number are required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      var profile = await _service.updateProfile(
        userId: _userId,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        contactNumber: _contactNumber.text.trim(),
        bio: _bio.text.trim(),
      );
      final address = {
        'region': _region.text.trim(),
        'province': _region.text.trim().toUpperCase() == 'NCR' ? '' : _province.text.trim(),
        'city_municipality': _city.text.trim(),
        'barangay': _barangay.text.trim(),
        'zip_code': _zip.text.trim(),
        'street_details': _street.text.trim().isEmpty ? null : _street.text.trim(),
        'landmark': _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
      };
      if (_newAddress || _selectedAddressId == null) {
        profile = await _service.addAddress(userId: _userId, address: address);
      } else {
        await _service.updateAddress(userId: _userId, addressId: _selectedAddressId!, address: address);
        profile = await _service.choosePreferredAddress(userId: _userId, addressId: _selectedAddressId!);
      }
      if (_photo != null) profile = await _service.uploadPhoto(userId: _userId, file: _photo!);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: const Color(0xFFF3F3F3),
                  backgroundImage: _photo != null ? FileImage(_photo!) : null,
                  child: _photo == null ? const Icon(Icons.person_outline, size: 58, color: AppColors.black) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(onPressed: _pickPhoto, icon: const Icon(Icons.camera_alt_outlined)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextField(controller: _firstName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 14),
          TextField(controller: _lastName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name')),
          const SizedBox(height: 14),
          TextField(controller: _contactNumber, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact number')),
          const SizedBox(height: 14),
          TextField(controller: _bio, maxLength: 500, maxLines: 4, decoration: const InputDecoration(labelText: 'Bio', alignLabelWithHint: true)),
          const SizedBox(height: 22),
          const Text('Preferred address', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            key: ValueKey('${_selectedAddressId}_$_newAddress'),
            initialValue: _newAddress ? null : _selectedAddressId,
            decoration: const InputDecoration(labelText: 'Address'),
            items: [
              ..._addresses.map((address) => DropdownMenuItem<int>(
                value: address['address_id'] as int,
                child: Text('${address['city_municipality']}, ${address['province']?.toString().isEmpty == true ? address['region'] : address['province']}'),
              )),
              const DropdownMenuItem<int?>(value: null, child: Text('Add another address')),
            ],
            onChanged: (value) {
              setState(() {
                _newAddress = value == null;
                _selectedAddressId = value;
                _loadAddress(value == null ? <String, dynamic>{} : _addresses.firstWhere((item) => item['address_id'] == value));
              });
            },
          ),
          const SizedBox(height: 14),
          TextField(controller: _region, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Region')),
          const SizedBox(height: 14),
          if (_region.text.trim().toUpperCase() != 'NCR')
            TextField(controller: _province, decoration: const InputDecoration(labelText: 'Province')),
          const SizedBox(height: 14),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / municipality')),
          const SizedBox(height: 14),
          TextField(controller: _barangay, decoration: const InputDecoration(labelText: 'Barangay')),
          const SizedBox(height: 14),
          TextField(controller: _zip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ZIP code')),
          const SizedBox(height: 14),
          TextField(controller: _street, decoration: const InputDecoration(labelText: 'Street details (optional)')),
          const SizedBox(height: 14),
          TextField(controller: _landmark, decoration: const InputDecoration(labelText: 'Landmark (optional)')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
