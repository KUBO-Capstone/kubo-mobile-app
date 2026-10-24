import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/profile_service.dart';
import '../models/profile_validation.dart';
import 'profile_photo_editor_page.dart';

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
  late final TextEditingController _location;
  late final TextEditingController _businessName;
  late final TextEditingController _businessType;
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
    _location = TextEditingController(text: widget.user['location']?.toString() ?? '');
    _businessName = TextEditingController(text: widget.user['business_name']?.toString() ?? '');
    _businessType = TextEditingController(text: widget.user['business_type']?.toString() ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _contactNumber.dispose();
    _bio.dispose();
    _location.dispose();
    _businessName.dispose();
    _businessType.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 2400, imageQuality: 92);
    if (picked == null || !mounted) return;
    final edited = await Navigator.of(context).push<File>(
      MaterialPageRoute<File>(
        fullscreenDialog: true,
        builder: (_) => ProfilePhotoEditorPage(source: File(picked.path)),
      ),
    );
    if (edited != null && mounted) setState(() => _photo = edited);
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _save({bool confirmed = false}) async {
    final validation = ProfileValidation.validate(
      firstName: _firstName.text,
      lastName: _lastName.text,
      contactNumber: _contactNumber.text,
      bio: _bio.text,
      location: _location.text,
      businessName: _businessName.text,
      businessType: _businessType.text,
    );
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.errors.first)),
      );
      return;
    }
    if (!confirmed) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Preview profile'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFFF3F3F3),
                    backgroundImage: _photo == null ? null : FileImage(_photo!),
                    child: _photo == null ? const Icon(Icons.person_outline, size: 40) : null,
                  ),
                ),
                const SizedBox(height: 18),
                Text('${_firstName.text.trim()} ${_lastName.text.trim()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                if (_businessName.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_businessName.text.trim()),
                ],
                if (_businessType.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_businessType.text.trim(), style: const TextStyle(color: AppColors.gray)),
                ],
                if (_location.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_location.text.trim(), style: const TextStyle(color: AppColors.gray)),
                ],
                if (_bio.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_bio.text.trim()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save profile'),
            ),
          ],
        ),
      );
      if (shouldSave != true || !mounted) return;
      return _save(confirmed: true);
    }
    setState(() => _saving = true);
    try {
      var profile = await _service.updateProfile(
        userId: _userId,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        contactNumber: _contactNumber.text.trim(),
        bio: _bio.text.trim(),
        location: _location.text.trim(),
        businessName: _businessName.text.trim(),
        businessType: _businessType.text.trim(),
      );
      if (_photo != null) {
        profile = await _service.uploadPhoto(userId: _userId, file: _photo!);
      }
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
                if (_photo != null)
                  Positioned.fill(
                    child: ClipOval(
                      child: Image.file(_photo!, fit: BoxFit.cover),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(onPressed: _choosePhotoSource, icon: const Icon(Icons.camera_alt_outlined)),
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
          TextField(controller: _location, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Location / city')),
          const SizedBox(height: 14),
          TextField(controller: _businessName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Business name')),
          const SizedBox(height: 14),
          TextField(controller: _businessType, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Business type')),
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
