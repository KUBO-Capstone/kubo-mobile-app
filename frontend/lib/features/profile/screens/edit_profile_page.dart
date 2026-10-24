import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/profile_service.dart';
import '../models/profile_validation.dart';

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
  double _photoRotation = 0;
  bool _saving = false;

  Map<String, bool> _privacy = const {
    'public_profile': true,
    'show_bio': true,
    'show_contact_number': true,
    'show_location': true,
  };

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
    final privacy = widget.user['profile_privacy'];
    if (privacy is Map) {
      _privacy = Map<String, bool>.from(privacy.map((key, value) => MapEntry(key.toString(), value is bool ? value : false)));
    }
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

  Future<File> _prepareCroppedAvatar(File source, double rotationDegrees) async {
    final raw = await source.readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) return source;

    final rotated = img.copyRotate(decoded, angle: rotationDegrees.round());
    final side = min(rotated.width, rotated.height);
    final x = (rotated.width - side) ~/ 2;
    final y = (rotated.height - side) ~/ 2;
    final cropped = img.copyCrop(rotated, x: x, y: y, width: side, height: side);
    final encoded = img.encodeJpg(cropped, quality: 90);
    final output = File('${Directory.systemTemp.path}/kubo-avatar-${DateTime.now().microsecondsSinceEpoch}.jpg');
    await output.writeAsBytes(encoded, flush: true);
    return output;
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    final processed = await _prepareCroppedAvatar(File(picked.path), _photoRotation);
    if (!mounted) return;
    setState(() {
      _photo = processed;
      _photoRotation = 0;
    });
  }

  void _rotatePhoto(int direction) {
    if (_photo == null) return;
    setState(() {
      _photoRotation = (_photoRotation + direction * 90) % 360;
    });
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
        profilePrivacy: _privacy,
      );
      if (_photo != null) {
        final rotatedPhoto = await _prepareCroppedAvatar(_photo!, _photoRotation);
        profile = await _service.uploadPhoto(userId: _userId, file: rotatedPhoto);
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
                      child: Transform.rotate(
                        angle: _photoRotation * pi / 180,
                        child: Image.file(_photo!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(onPressed: _pickPhoto, icon: const Icon(Icons.camera_alt_outlined)),
                ),
                if (_photo != null)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _rotatePhoto(-1),
                          icon: const Icon(Icons.rotate_left),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () => _rotatePhoto(1),
                          icon: const Icon(Icons.rotate_right),
                        ),
                      ],
                    ),
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
          Text('Profile visibility', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _privacy['public_profile'] ?? true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Public profile'),
            onChanged: (value) => setState(() => _privacy['public_profile'] = value),
          ),
          SwitchListTile(
            value: _privacy['show_bio'] ?? true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show bio'),
            onChanged: (value) => setState(() => _privacy['show_bio'] = value),
          ),
          SwitchListTile(
            value: _privacy['show_contact_number'] ?? true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show contact number'),
            onChanged: (value) => setState(() => _privacy['show_contact_number'] = value),
          ),
          SwitchListTile(
            value: _privacy['show_location'] ?? true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show location'),
            onChanged: (value) => setState(() => _privacy['show_location'] = value),
          ),
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
