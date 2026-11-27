import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/ph_addresses.dart';
import '../../../shared/data/profile_service.dart';
import '../../../shared/widgets/kubo_picker_field.dart';
import '../models/profile_validation.dart';
import 'profile_photo_editor_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user, this.highlightMissing = false});

  final Map<String, dynamic> user;

  /// Marks the empty required fields in red from the start: the page was
  /// opened by "Complete your profile", so the person should see at once
  /// what is missing.
  final bool highlightMissing;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

enum _SaveChoice { save, keepEditing, discard }

/// Address fields that can be missing or wrong, for the messages under them.
enum _AddressField { region, province, city, barangay, zip }

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _contactNumber;
  late final TextEditingController _bio;
  late final TextEditingController _location;
  late final TextEditingController _businessName;
  late final TextEditingController _businessType;
  late final TextEditingController _zip;
  late final TextEditingController _street;
  late final TextEditingController _landmark;
  final ProfileService _service = ProfileService();
  final ImagePicker _picker = ImagePicker();
  File? _photo;
  bool _saving = false;
  bool _profileLoading = true;
  bool _profileLoadFailed = false;
  List<Map<String, dynamic>> _addresses = [];
  int? _selectedAddressId;
  bool _newAddress = false;

  // The chosen region, province, town and barangay, spelled as sign-up
  // saves them ("REGION III", "BULACAN", "MALOLOS CITY").
  String _region = '';
  String _province = '';
  String _city = '';
  String _barangay = '';

  /// Errors show under the fields once Save was tapped (or right away when
  /// [EditProfilePage.highlightMissing]), then update as the person types.
  late bool _showErrors = widget.highlightMissing;

  /// What the form held once it finished loading; anything else is unsaved.
  String? _savedSnapshot;

  int get _userId => int.parse(widget.user['user_id'].toString());

  List<TextEditingController> get _textControllers =>
      [_firstName, _lastName, _contactNumber, _bio, _location, _businessName, _businessType, _zip, _street, _landmark];

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
    _zip = TextEditingController();
    _street = TextEditingController();
    _landmark = TextEditingController();
    // Every keystroke can change an error message or the unsaved state.
    for (final controller in _textControllers) {
      controller.addListener(_onEdited);
    }
    _load();
  }

  void _onEdited() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _loadProfile();
    if (!mounted) return;
    setState(() => _savedSnapshot = _snapshot());
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
      setState(() {
        _profileLoading = false;
        _profileLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileLoadFailed = true;
      });
    }
  }

  void _loadAddress(Map<String, dynamic> address) {
    _region = address['region']?.toString() ?? '';
    _province = address['province']?.toString() ?? '';
    _city = address['city_municipality']?.toString() ?? '';
    _barangay = address['barangay']?.toString() ?? '';
    _zip.text = address['zip_code']?.toString() ?? '';
    _street.text = address['street_details']?.toString() ?? '';
    _landmark.text = address['landmark']?.toString() ?? '';
    _matchAddressToPlaces();
  }

  // Swaps an older address's spellings ("Region III", "Malolos") for the
  // list's ("REGION III", "MALOLOS CITY"), so the dropdowns show them as
  // chosen and the next save stores the one format. Names the list does not
  // have are kept as they are.
  void _matchAddressToPlaces() {
    final region = PhAddresses.findRegion(_region);
    if (region == null) return;
    _region = region.regionName;
    final ncr = PhAddresses.isNcr(region);
    final province = ncr ? null : PhAddresses.findByName(region.provinces, _province, (Province p) => p.name);
    if (!ncr && province == null) return;
    if (province != null) _province = province.name;
    final town = PhAddresses.findByName(PhAddresses.townsOf(region, province), _city, (Municipality t) => t.name);
    if (town == null) return;
    _city = town.name;
    _barangay = PhAddresses.findByName(town.barangays, _barangay, (String b) => b) ?? _barangay;
  }

  Region? get _regionEntry => PhAddresses.findRegion(_region);

  bool get _isNcr {
    final region = _regionEntry;
    return region != null && PhAddresses.isNcr(region);
  }

  Province? get _provinceEntry {
    final region = _regionEntry;
    if (region == null || PhAddresses.isNcr(region)) return null;
    return PhAddresses.findByName(region.provinces, _province, (Province p) => p.name);
  }

  List<Municipality> get _townOptions {
    final region = _regionEntry;
    return region == null ? const <Municipality>[] : PhAddresses.townsOf(region, _provinceEntry);
  }

  Municipality? get _townEntry => PhAddresses.findByName(_townOptions, _city, (Municipality t) => t.name);

  String _snapshot() => jsonEncode([
        for (final controller in _textControllers) controller.text,
        _region,
        _province,
        _city,
        _barangay,
        _selectedAddressId,
        _newAddress,
        _photo?.path,
      ]);

  bool get _hasUnsavedChanges {
    final saved = _savedSnapshot;
    return saved != null && !_saving && saved != _snapshot();
  }

  @override
  void dispose() {
    for (final controller in _textControllers) {
      controller.dispose();
    }
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
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  ProfileValidationResult get _profileValidation => ProfileValidation.validate(
        firstName: _firstName.text,
        lastName: _lastName.text,
        contactNumber: _contactNumber.text,
        bio: _bio.text,
        location: _location.text,
        businessName: _businessName.text,
        businessType: _businessType.text,
      );

  Map<_AddressField, String> get _addressErrors {
    final zip = _zip.text.trim();
    return {
      if (_region.trim().isEmpty) _AddressField.region: 'Choose your region.',
      if (!_isNcr && _province.trim().isEmpty) _AddressField.province: 'Choose your province.',
      if (_city.trim().isEmpty) _AddressField.city: 'Choose your city or municipality.',
      if (_barangay.trim().isEmpty) _AddressField.barangay: 'Choose your barangay.',
      if (zip.isEmpty)
        _AddressField.zip: 'ZIP code is required.'
      else if (!RegExp(r'^\d{4}$').hasMatch(zip))
        _AddressField.zip: 'ZIP codes have 4 digits.',
    };
  }

  // Nothing is marked until the saved profile is in, or every address field
  // would flash red while it loads.
  bool get _errorsVisible => _showErrors && _savedSnapshot != null;

  String? _profileError(ProfileField field) => _errorsVisible ? _profileValidation.fieldErrors[field] : null;

  String? _addressError(_AddressField field) => _errorsVisible ? _addressErrors[field] : null;

  Future<void> _save({bool confirmed = false}) async {
    final validation = _profileValidation;
    final addressErrors = _addressErrors;
    if (!validation.isValid || addressErrors.isNotEmpty) {
      setState(() => _showErrors = true);
      final count = validation.fieldErrors.length + addressErrors.length;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(count == 1 ? 'Fix the field marked in red.' : 'Fix the $count fields marked in red.'),
        ));
      return;
    }
    if (!confirmed) {
      final choice = await _askToSave(leaving: false);
      if (choice != _SaveChoice.save || !mounted) return;
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
      final address = {
        'region': _region.trim(),
        'province': _isNcr ? '' : _province.trim(),
        'city_municipality': _city.trim(),
        'barangay': _barangay.trim(),
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

  /// The one modal for saving: from Save Changes, and from Back with
  /// unsaved edits ([leaving]). Back also offers Discard, or the only way
  /// out of the page would be saving.
  Future<_SaveChoice?> _askToSave({required bool leaving}) {
    return showDialog<_SaveChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Changes?'),
        content: Text(leaving
            ? 'You have changes on this page that are not saved yet.'
            : 'Your profile will be updated with these changes.'),
        actions: [
          if (leaving)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(_SaveChoice.discard),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Discard'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_SaveChoice.keepEditing),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_SaveChoice.save),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _onBack() async {
    final navigator = Navigator.of(context);
    final choice = await _askToSave(leaving: true);
    if (!mounted) return;
    switch (choice) {
      case _SaveChoice.save:
        // Pops itself with the saved profile when it succeeds.
        await _save(confirmed: true);
      case _SaveChoice.discard:
        navigator.pop();
      case _SaveChoice.keepEditing || null:
        break;
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? error,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: capitalization,
      textInputAction: action,
      decoration: InputDecoration(labelText: label, hintText: hint, errorText: error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final region = _regionEntry;
    final town = _townEntry;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
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
                    child: IconButton.filled(
                      tooltip: 'Change photo',
                      onPressed: _choosePhotoSource,
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '* Required. Buyers and sellers need your contact number and address to arrange the handover.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _textField(_firstName, 'First Name *',
                error: _profileError(ProfileField.firstName), capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _textField(_lastName, 'Last Name *',
                error: _profileError(ProfileField.lastName), capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _textField(
              _contactNumber,
              'Contact Number *',
              hint: '0917 123 4567',
              error: _profileError(ProfileField.contactNumber),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(ProfileValidation.contactNumberCharacters),
                LengthLimitingTextInputFormatter(15),
              ],
            ),
            const SizedBox(height: 14),
            _textField(_location, 'Location / City',
                error: _profileError(ProfileField.location), capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _textField(_businessName, 'Business Name',
                error: _profileError(ProfileField.businessName), capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _textField(_businessType, 'Business Type',
                error: _profileError(ProfileField.businessType), capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            TextField(
              controller: _bio,
              maxLength: 500,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
                errorText: _profileError(ProfileField.bio),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Preferred Address', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                const DropdownMenuItem<int?>(value: null, child: Text('Add Another Address')),
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
            KuboPickerField(
              label: 'Region *',
              value: _region,
              options: [for (final r in PhAddresses.regions) r.regionName],
              errorText: _addressError(_AddressField.region),
              onChanged: (value) => setState(() {
                _region = value;
                _province = '';
                _city = '';
                _barangay = '';
              }),
            ),
            if (!_isNcr) ...[
              const SizedBox(height: 14),
              KuboPickerField(
                label: 'Province *',
                value: _province,
                options: [for (final p in region?.provinces ?? const <Province>[]) p.name],
                disabledHint: 'Choose a region first',
                errorText: _addressError(_AddressField.province),
                onChanged: (value) => setState(() {
                  _province = value;
                  _city = '';
                  _barangay = '';
                }),
              ),
            ],
            const SizedBox(height: 14),
            KuboPickerField(
              label: 'City / Municipality *',
              value: _city,
              options: [for (final t in _townOptions) t.name],
              disabledHint: _isNcr ? 'Choose a region first' : 'Choose a province first',
              errorText: _addressError(_AddressField.city),
              onChanged: (value) => setState(() {
                _city = value;
                _barangay = '';
              }),
            ),
            const SizedBox(height: 14),
            KuboPickerField(
              label: 'Barangay *',
              value: _barangay,
              options: town?.barangays ?? const <String>[],
              disabledHint: 'Choose a city or municipality first',
              errorText: _addressError(_AddressField.barangay),
              onChanged: (value) => setState(() => _barangay = value),
            ),
            const SizedBox(height: 14),
            _textField(
              _zip,
              'ZIP Code *',
              hint: '4 digits',
              error: _addressError(_AddressField.zip),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            ),
            const SizedBox(height: 14),
            _textField(_street, 'Street Details (optional)', capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _textField(_landmark, 'Landmark (optional)',
                capitalization: TextCapitalization.sentences, action: TextInputAction.done),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: (_saving || _profileLoading || _profileLoadFailed) ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
