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
  final ProfileService _service = ProfileService();
  final ImagePicker _picker = ImagePicker();
  File? _photo;
  bool _saving = false;

  int get _userId => int.parse(widget.user['user_id'].toString());

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.user['first_name']?.toString());
    _lastName = TextEditingController(text: widget.user['last_name']?.toString());
    _contactNumber = TextEditingController(text: widget.user['contact_number']?.toString());
    _bio = TextEditingController(text: widget.user['bio']?.toString() ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _contactNumber.dispose();
    _bio.dispose();
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
