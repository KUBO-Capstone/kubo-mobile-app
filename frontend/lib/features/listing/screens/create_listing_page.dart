import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_options.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/market_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../login/services/auth_service.dart';
import '../models/listing_draft.dart';
import '../widgets/listing_draft_strip.dart';
import '../widgets/listing_form_fields.dart';
import '../widgets/listing_photo_row.dart';

/// Create form for new listings, or the edit form when [existing] is given.
///
/// In create mode the seller can open several drafts (one per crop) and
/// post them one at a time with "List it!" or together with "Post all".
/// Pops with the last saved [SyntheticListingRecord], or null when nothing
/// was posted, so the caller knows whether to refresh.
class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key, this.existing});

  /// Listing being edited; null means create.
  final SyntheticListingRecord? existing;

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  static const _maxDrafts = 10;

  final _service = ListingService();
  final _market = MarketService();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();

  late final List<ListingDraft> _drafts;
  int _index = 0;

  bool _saving = false;
  String _savingLabel = '';
  SyntheticListingRecord? _lastSaved;
  bool _dealMethodExpanded = true;

  // Market Watch price per crop name, null when nothing matched.
  final Map<String, MarketReference?> _references = <String, MarketReference?>{};
  Timer? _referenceDebounce;

  bool get _isEditing => widget.existing != null;
  ListingDraft get _draft => _drafts[_index];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _drafts = [existing == null ? ListingDraft() : ListingDraft.fromListing(existing)];
    _lookUpReference(immediately: true);
  }

  @override
  void dispose() {
    _referenceDebounce?.cancel();
    for (final draft in _drafts) {
      draft.dispose();
    }
    _scrollController.dispose();
    _service.dispose();
    _market.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Drafts
  // ---------------------------------------------------------------------

  void _selectDraft(int index) {
    if (index == _index) return;
    FocusScope.of(context).unfocus();
    setState(() => _index = index);
    _scrollToTop();
    _lookUpReference(immediately: true);
  }

  void _addDraft() {
    if (_drafts.length >= _maxDrafts) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _drafts.add(ListingDraft());
      _index = _drafts.length - 1;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: listingErrorColor),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _clearDraft() async {
    if (!_draft.isBlank &&
        !await _confirm(title: 'Clear details?', message: 'Photos and everything typed in Listing ${_index + 1} will be cleared.', action: 'Clear')) {
      return;
    }
    setState(_draft.clear);
  }

  Future<void> _deleteDraft() async {
    if (!_draft.isBlank &&
        !await _confirm(title: 'Delete this draft?', message: 'Listing ${_index + 1} will be removed. Your other drafts stay.', action: 'Delete')) {
      return;
    }
    setState(() => _removeDraftAt(_index));
  }

  // Drops a draft once it is posted or deleted; the caller wraps it in setState.
  void _removeDraftAt(int index) {
    _drafts.removeAt(index).dispose();
    if (_index >= _drafts.length) _index = _drafts.length - 1;
    if (_index < 0) _index = 0;
  }

  Future<void> _close() async {
    if (_saving) return;
    final unsaved = _drafts.where((draft) => !draft.isBlank).length;
    if (!_isEditing && unsaved > 0) {
      final discard = await _confirm(
        title: unsaved == 1 ? 'Discard this listing?' : 'Discard $unsaved drafts?',
        message: 'What you entered has not been posted yet.',
        action: 'Discard',
      );
      if (!discard) return;
    }
    if (mounted) Navigator.of(context).pop(_lastSaved);
  }

  // ---------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------

  Future<void> _addPhotos() async {
    final draft = _draft;
    final remaining = draft.remainingPhotoSlots;
    if (remaining <= 0) {
      _showMessage('A listing can have up to $maxListingPhotos photos.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: Text('Up to $remaining more'),
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
    if (source == null) return;

    final List<XFile> picked;
    try {
      // The picker rejects a limit under 2, so the last slot is a single pick.
      if (source == ImageSource.gallery && remaining >= 2) {
        picked = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: remaining);
      } else {
        final single = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
        picked = single == null ? const <XFile>[] : [single];
      }
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Could not open your photos.');
      return;
    }
    if (picked.isEmpty || !mounted) return;
    // Some platforms ignore the limit.
    final accepted = picked.take(draft.remainingPhotoSlots).toList();
    setState(() => draft.photos.addAll(accepted.map((file) => ListingPhoto.local(File(file.path)))));
    if (accepted.length < picked.length) {
      _showMessage('Only the first ${accepted.length} photos were added. A listing can have up to $maxListingPhotos.');
    }
  }

  Future<void> _editPhoto(int index) async {
    final draft = _draft;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Make cover photo'),
                subtitle: const Text('Buyers see this one first'),
                onTap: () => Navigator.of(sheetContext).pop('cover'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: listingErrorColor),
              title: const Text('Remove photo', style: TextStyle(color: listingErrorColor)),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() {
      final photo = draft.photos.removeAt(index);
      if (action == 'cover') draft.photos.insert(0, photo);
    });
  }

  void _reorderPhoto(int from, int to) {
    setState(() => _draft.photos.insert(to, _draft.photos.removeAt(from)));
  }

  // ---------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------

  Future<void> _pickOption({
    required String title,
    required List<ListingOption> options,
    required String? selected,
    required void Function(String value) apply,
  }) async {
    FocusScope.of(context).unfocus();
    final value = await showListingOptionSheet(context, title: title, options: options, selected: selected);
    if (value != null && mounted) setState(() => apply(value));
  }

  Future<void> _pickHarvestDate() async {
    FocusScope.of(context).unfocus();
    final draft = _draft;
    final today = dateOnly(DateTime.now());
    final first = draft.isPreorder ? today : today.subtract(const Duration(days: 90));
    final last = draft.isPreorder ? today.add(const Duration(days: 365)) : today;
    final current = draft.harvestDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first) && !current.isAfter(last) ? current : today,
      firstDate: first,
      lastDate: last,
      helpText: draft.isPreorder ? 'Expected harvest date' : 'Harvest date',
    );
    if (picked != null && mounted) setState(() => draft.harvestDate = picked);
  }

  // ---------------------------------------------------------------------
  // Market reference
  // ---------------------------------------------------------------------

  String _referenceKey(ListingDraft draft) => draft.title.text.trim().toLowerCase();

  // Looks up the Market Watch price for the current title so the seller
  // can price against it. Failures stay silent: it is only a hint.
  void _lookUpReference({bool immediately = false}) {
    _referenceDebounce?.cancel();
    final key = _referenceKey(_draft);
    if (key.length < 3 || _references.containsKey(key)) return;
    _referenceDebounce = Timer(immediately ? Duration.zero : const Duration(milliseconds: 600), () async {
      MarketReference? reference;
      try {
        reference = await _market.fetchReference(crop: key);
      } catch (error) {
        debugPrint('Market reference lookup failed: $error');
        return;
      }
      if (mounted) setState(() => _references[key] = reference);
    });
  }

  void _useMarketPrice(MarketReference reference, double price) {
    setState(() {
      _draft.price.text = formatQuantity(double.parse(price.toStringAsFixed(2)));
      if (ListingOptions.units.any((unit) => unit.value == reference.unit)) _draft.unit = reference.unit;
    });
  }

  // ---------------------------------------------------------------------
  // Posting
  // ---------------------------------------------------------------------

  Map<DraftField, String> _errorsFor(ListingDraft draft) => draft.validate(allowZeroQuantity: _isEditing);

  bool _draftHasErrors(int index) => _drafts[index].showErrors && _errorsFor(_drafts[index]).isNotEmpty;

  // Uploads any new photos, then creates or updates the listing.
  Future<SyntheticListingRecord> _save(ListingDraft draft) async {
    final pending = draft.photos.where((photo) => photo.needsUpload).toList();
    if (pending.isNotEmpty) {
      setState(() => _savingLabel = 'Uploading photos...');
      final paths = await _service.uploadImages(pending.map((photo) => photo.file!).toList());
      if (paths.length != pending.length) {
        throw Exception('Some photos could not be uploaded. Please use JPG, PNG, or WebP photos.');
      }
      for (var i = 0; i < pending.length; i++) {
        pending[i].serverPath = paths[i];
      }
    }
    if (mounted) setState(() => _savingLabel = _isEditing ? 'Saving...' : 'Posting...');
    final submission = draft.toSubmission(draft.photos.map((photo) => photo.serverPath!).toList());
    final existing = widget.existing;
    return existing == null
        ? _service.createListing(submission)
        : _service.updateListing(productId: existing.productId!, listing: submission);
  }

  bool _ensureSignedIn() {
    if (AuthService.currentUserId != null) return true;
    _showMessage('Please log in before ${_isEditing ? 'editing' : 'creating'} a listing.');
    return false;
  }

  Future<void> _postCurrent() async {
    FocusScope.of(context).unfocus();
    final draft = _draft;
    if (_errorsFor(draft).isNotEmpty) {
      setState(() => draft.showErrors = true);
      _showMessage('Please complete the details marked in red.');
      return;
    }
    if (!_ensureSignedIn()) return;
    setState(() => _saving = true);
    try {
      final saved = await _save(draft);
      if (!mounted) return;
      _lastSaved = saved;
      if (_isEditing || _drafts.length == 1) {
        // Edits are confirmed by whoever opened the form.
        if (!_isEditing) _showMessage('"${saved.title}" is now listed.');
        Navigator.of(context).pop(saved);
        return;
      }
      setState(() => _removeDraftAt(_drafts.indexOf(draft)));
      _showMessage('"${saved.title}" is listed. ${_drafts.length} draft${_drafts.length == 1 ? '' : 's'} left.');
      _lookUpReference(immediately: true);
    } catch (error) {
      if (mounted) _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _postAll() async {
    FocusScope.of(context).unfocus();
    final invalid = <int>[];
    for (var i = 0; i < _drafts.length; i++) {
      if (_errorsFor(_drafts[i]).isNotEmpty) invalid.add(i);
    }
    if (invalid.isNotEmpty) {
      setState(() {
        for (final i in invalid) {
          _drafts[i].showErrors = true;
        }
        _index = invalid.first;
      });
      _showMessage(invalid.length == 1
          ? 'Listing ${invalid.first + 1} needs a few more details.'
          : '${invalid.length} listings need a few more details.');
      return;
    }
    if (!_ensureSignedIn()) return;

    setState(() => _saving = true);
    var posted = 0;
    final total = _drafts.length;
    try {
      for (final draft in List<ListingDraft>.of(_drafts)) {
        if (!mounted) return;
        setState(() => _index = _drafts.indexOf(draft));
        _lastSaved = await _save(draft);
        posted++;
        if (!mounted) return;
        setState(() => _removeDraftAt(_drafts.indexOf(draft)));
      }
      if (!mounted) return;
      _showMessage('Posted $posted listing${posted == 1 ? '' : 's'}.');
      Navigator.of(context).pop(_lastSaved);
    } catch (error) {
      // The draft that failed is selected and stays; earlier ones are posted.
      if (mounted) {
        _showMessage(posted == 0 ? _errorText(error) : 'Posted $posted of $total. ${_errorText(error)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorText(Object error) => error.toString().replaceFirst('Exception: ', '');

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final errors = draft.showErrors ? _errorsFor(draft) : const <DraftField, String>{};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: AppColors.black),
            onPressed: _close,
          ),
          title: Text(
            _isEditing ? 'EDIT LISTING' : 'SELL YOUR PRODUCE',
            style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          centerTitle: true,
          actions: [
            if (!_isEditing && _drafts.length > 1)
              TextButton(
                onPressed: _saving ? null : _postAll,
                style: TextButton.styleFrom(foregroundColor: AppColors.black),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Post all (${_drafts.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (!_isEditing) ...[
                ListingDraftStrip(
                  drafts: _drafts,
                  selectedIndex: _index,
                  onSelect: _selectDraft,
                  onAdd: _addDraft,
                  hasErrors: _draftHasErrors,
                  maxDrafts: _maxDrafts,
                ),
                const SizedBox(height: 14),
              ],
              _buildHeader(),
              const SizedBox(height: 14),
              ..._buildPhotos(draft, errors),
              const SizedBox(height: 22),
              ..._buildDetails(draft, errors),
              const SizedBox(height: 22),
              ..._buildDescription(draft),
              const SizedBox(height: 22),
              ..._buildPriceAndStock(draft, errors),
              const SizedBox(height: 22),
              ..._buildHarvest(draft, errors),
              const SizedBox(height: 14),
              ..._buildDealMethod(draft, errors),
            ],
          ),
        ),
        bottomNavigationBar: _buildSubmitBar(),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEditing ? 'Update your produce' : 'Listing ${_index + 1}',
            style: const TextStyle(color: AppColors.black, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        if (!_isEditing)
          TextButton(
            onPressed: _clearDraft,
            style: TextButton.styleFrom(foregroundColor: AppColors.green),
            child: const Text('Clear details', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        if (!_isEditing && _drafts.length > 1)
          IconButton(
            tooltip: 'Delete this draft',
            onPressed: _deleteDraft,
            icon: const Icon(Icons.delete_outline, color: AppColors.black),
          ),
      ],
    );
  }

  List<Widget> _buildPhotos(ListingDraft draft, Map<DraftField, String> errors) {
    return [
      ListingPhotoRow(
        photos: draft.photos,
        onAdd: _addPhotos,
        onPhotoTap: _editPhoto,
        onReorder: _reorderPhoto,
        hasError: errors.containsKey(DraftField.photos),
      ),
      const SizedBox(height: 8),
      Text(
        draft.photos.isEmpty
            ? 'Add clear photos of your harvest. The first one is the cover.'
            : 'Tap to edit photos. Long-press and drag to reorder. ${draft.photos.length}/$maxListingPhotos',
        style: const TextStyle(color: AppColors.gray, fontSize: 12),
      ),
      ListingFieldError(errors[DraftField.photos]),
    ];
  }

  List<Widget> _buildDetails(ListingDraft draft, Map<DraftField, String> errors) {
    return [
      const ListingFieldLabel('Category'),
      ListingPickerField(
        placeholder: 'Select a category',
        value: draft.category == null ? null : ListingOptions.labelOf(ListingOptions.categories, draft.category),
        icon: ListingOptions.categories.where((option) => option.value == draft.category).firstOrNull?.icon,
        hasError: errors.containsKey(DraftField.category),
        onTap: () => _pickOption(
          title: 'Category',
          options: ListingOptions.categories,
          selected: draft.category,
          apply: (value) => draft.category = value,
        ),
      ),
      ListingFieldError(errors[DraftField.category]),
      const SizedBox(height: 18),
      const ListingFieldLabel('Listing title'),
      TextField(
        controller: draft.title,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        decoration: listingInputDecoration(
          hint: 'e.g. Lakatan bananas, Baguio strawberries',
          hasError: errors.containsKey(DraftField.title),
        ),
        onChanged: (_) {
          setState(() {});
          _lookUpReference();
        },
      ),
      ListingFieldError(errors[DraftField.title]),
      const SizedBox(height: 18),
      const ListingFieldLabel('Quality'),
      ListingPickerField(
        placeholder: 'Select quality',
        value: ListingOptions.labelOf(ListingOptions.qualityGrades, draft.qualityGrade),
        onTap: () => _pickOption(
          title: 'Quality',
          options: ListingOptions.qualityGrades,
          selected: draft.qualityGrade,
          apply: (value) => draft.qualityGrade = value,
        ),
      ),
      const SizedBox(height: 18),
      const ListingFieldLabel('Farming method'),
      ListingPickerField(
        placeholder: 'Select farming method',
        value: ListingOptions.labelOf(ListingOptions.farmingMethods, draft.farmingMethod),
        onTap: () => _pickOption(
          title: 'Farming method',
          options: ListingOptions.farmingMethods,
          selected: draft.farmingMethod,
          apply: (value) => draft.farmingMethod = value,
        ),
      ),
    ];
  }

  List<Widget> _buildDescription(ListingDraft draft) {
    return [
      const ListingFieldLabel('Description', optional: true),
      const Text('Choose a template', style: TextStyle(color: AppColors.gray, fontSize: 12)),
      const SizedBox(height: 8),
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: DescriptionTemplate.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final template = DescriptionTemplate.values[index];
            return ListingChoicePill(
              label: template.label,
              selected: draft.template == template,
              onTap: () => setState(() => draft.applyTemplate(template)),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: draft.description,
        minLines: 4,
        maxLines: 8,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        decoration: listingInputDecoration(
          hint: 'Variety, size, taste, how it was stored, and anything buyers should know.',
        ),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }

  List<Widget> _buildPriceAndStock(ListingDraft draft, Map<DraftField, String> errors) {
    final reference = _references[_referenceKey(draft)];
    final marketPrice = reference?.comparisonPrice;
    return [
      const ListingFieldLabel('Price'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: draft.price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: listingInputDecoration(
                hint: 'Price of your listing',
                prefix: 'PHP',
                hasError: errors.containsKey(DraftField.price),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: ListingPickerField(
              placeholder: 'Unit',
              value: 'per ${draft.unit}',
              onTap: () => _pickOption(
                title: 'Sold per',
                options: ListingOptions.units,
                selected: draft.unit,
                apply: (value) => draft.unit = value,
              ),
            ),
          ),
        ],
      ),
      ListingFieldError(errors[DraftField.price]),
      if (reference != null && marketPrice != null) _MarketHint(
        reference: reference,
        marketPrice: marketPrice,
        onUse: () => _useMarketPrice(reference, marketPrice),
      ),
      const SizedBox(height: 18),
      const ListingFieldLabel('Available quantity'),
      TextField(
        controller: draft.quantity,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
        decoration: listingInputDecoration(
          hint: 'How much you have to sell',
          hasError: errors.containsKey(DraftField.quantity),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              widthFactor: 1,
              child: Text(draft.unit, style: const TextStyle(color: AppColors.gray, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      ListingFieldError(errors[DraftField.quantity]),
    ];
  }

  List<Widget> _buildHarvest(ListingDraft draft, Map<DraftField, String> errors) {
    final date = draft.harvestDate;
    return [
      ListingSwitchRow(
        title: 'Pre-order',
        subtitle: 'List now, ship to the buyer once it is harvested',
        value: draft.isPreorder,
        onChanged: (value) => setState(() => draft.setPreorder(value)),
      ),
      const SizedBox(height: 10),
      ListingFieldLabel(draft.isPreorder ? 'Expected harvest date' : 'Harvest date', optional: !draft.isPreorder),
      Row(
        children: [
          Expanded(
            child: ListingPickerField(
              placeholder: draft.isPreorder ? 'When will it be ready?' : 'When was it picked?',
              value: date == null ? null : formatListingDate(date),
              icon: Icons.event_outlined,
              hasError: errors.containsKey(DraftField.harvestDate),
              onTap: _pickHarvestDate,
            ),
          ),
          if (date != null)
            IconButton(
              tooltip: 'Clear date',
              onPressed: () => setState(() => draft.harvestDate = null),
              icon: const Icon(Icons.close, color: AppColors.gray),
            ),
        ],
      ),
      ListingFieldError(errors[DraftField.harvestDate]),
    ];
  }

  List<Widget> _buildDealMethod(ListingDraft draft, Map<DraftField, String> errors) {
    return [
      InkWell(
        onTap: () => setState(() => _dealMethodExpanded = !_dealMethodExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text('Deal Method', style: TextStyle(color: AppColors.green, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Icon(_dealMethodExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.green),
            ],
          ),
        ),
      ),
      if (_dealMethodExpanded) ...[
        ListingSwitchRow(
          title: 'Meet-up',
          subtitle: 'Drop it off at a bagsakan center for the buyer to pick up',
          icon: Icons.warehouse_outlined,
          value: draft.allowsMeetup,
          onChanged: (value) => setState(() => draft.allowsMeetup = value),
        ),
        ListingSwitchRow(
          title: 'Delivery',
          subtitle: 'You book a courier and share the tracking number',
          icon: Icons.local_shipping_outlined,
          value: draft.allowsDelivery,
          onChanged: (value) => setState(() => draft.allowsDelivery = value),
        ),
      ],
      const Divider(height: 24, color: AppColors.border),
      ListingFieldError(errors[DraftField.dealMethod]),
    ];
  }

  Widget _buildSubmitBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _postCurrent,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white)),
                        const SizedBox(width: 12),
                        Text(_savingLabel, style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : Text(
                      _isEditing ? 'Save changes' : 'List it!',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Market Watch price for the crop being typed, with a one-tap "use it".
class _MarketHint extends StatelessWidget {
  const _MarketHint({required this.reference, required this.marketPrice, required this.onUse});

  final MarketReference reference;
  final double marketPrice;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final price = formatQuantity(double.parse(marketPrice.toStringAsFixed(2)));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined, size: 18, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Market avg for ${reference.name}: PHP $price/${reference.unit} nationwide'
              '${reference.source == marketSourceDa ? ' (DA Bantay Presyo)' : ''}',
              style: const TextStyle(color: AppColors.black, fontSize: 12, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onUse,
            style: TextButton.styleFrom(foregroundColor: AppColors.green),
            child: const Text('Use', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
