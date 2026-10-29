import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../shared/data/listing_options.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/synthetic_records.dart';

/// Most photos one listing can carry; matches the backend limit.
const int maxListingPhotos = 10;

/// One photo in a draft: a file picked on this device, or a photo the
/// listing already has on the server (edit mode).
class ListingPhoto {
  ListingPhoto.local(File this.file)
      : serverPath = null,
        displayUrl = null,
        id = _nextId++;

  ListingPhoto.remote({required String this.serverPath, required String this.displayUrl})
      : file = null,
        id = _nextId++;

  static int _nextId = 0;

  /// Stable key for drag-to-reorder.
  final int id;
  final File? file;

  /// What the backend stores, sent back unchanged on save. Set on a local
  /// photo once it is uploaded, so a retry after a failed post skips it.
  String? serverPath;

  /// Loadable URL of a photo that started on the server.
  final String? displayUrl;

  bool get needsUpload => serverPath == null;
}

/// Starting points for the description box. Each one writes a description
/// from whatever the seller has filled in so far.
enum DescriptionTemplate {
  casual('Casual'),
  simple('Simple'),
  bulletPoints('Bullet points'),
  writeMyOwn('Write my own');

  const DescriptionTemplate(this.label);

  final String label;
}

enum DraftField { photos, category, title, price, quantity, harvestDate, dealMethod }

/// One listing being written on the create page. Several drafts can be open
/// at once and posted together.
class ListingDraft {
  ListingDraft();

  /// Prefills every field from a published listing for editing.
  ListingDraft.fromListing(SyntheticListingRecord listing) {
    title.text = listing.title;
    price.text = listing.basePrice == null ? '' : formatQuantity(listing.basePrice!);
    quantity.text = listing.availableQuantity == null ? '' : formatQuantity(listing.availableQuantity!);
    description.text = listing.writtenDescription;
    category = listing.groups.firstOrNull;
    unit = listing.unit ?? 'kg';
    qualityGrade = listing.qualityGrade ?? 'standard';
    farmingMethod = listing.farmingMethod ?? 'conventional';
    harvestDate = listing.harvestDate;
    isPreorder = listing.isPreorder;
    allowsMeetup = listing.allowsMeetup;
    allowsDelivery = listing.allowsDelivery;
    template = listing.writtenDescription.isEmpty ? null : DescriptionTemplate.writeMyOwn;
    for (var i = 0; i < listing.imagePaths.length && i < listing.images.length; i++) {
      photos.add(ListingPhoto.remote(serverPath: listing.imagePaths[i], displayUrl: listing.images[i]));
    }
  }

  final title = TextEditingController();
  final price = TextEditingController();
  final quantity = TextEditingController();
  final description = TextEditingController();
  final List<ListingPhoto> photos = <ListingPhoto>[];

  String? category;
  String unit = 'kg';
  String qualityGrade = 'standard';
  String farmingMethod = 'conventional';
  DateTime? harvestDate;
  bool isPreorder = false;
  bool allowsMeetup = false;
  bool allowsDelivery = false;
  DescriptionTemplate? template;

  /// Set after the seller tries to post, so errors only show from then on.
  bool showErrors = false;

  int get remainingPhotoSlots => maxListingPhotos - photos.length;

  /// Nothing entered yet, so closing the page loses nothing.
  bool get isBlank =>
      photos.isEmpty &&
      category == null &&
      title.text.trim().isEmpty &&
      price.text.trim().isEmpty &&
      quantity.text.trim().isEmpty &&
      description.text.trim().isEmpty;

  /// Every problem blocking a post. [allowZeroQuantity] is for edits: a
  /// live listing can be brought down to nothing left.
  Map<DraftField, String> validate({bool allowZeroQuantity = false}) {
    final errors = <DraftField, String>{};
    if (photos.isEmpty) errors[DraftField.photos] = 'Please add at least one photo.';
    if (category == null) errors[DraftField.category] = 'Please choose a category.';
    if (title.text.trim().isEmpty) errors[DraftField.title] = 'Please enter a listing title.';

    final priceValue = double.tryParse(price.text.trim());
    if (price.text.trim().isEmpty) {
      errors[DraftField.price] = 'Please enter a price.';
    } else if (priceValue == null || priceValue <= 0) {
      errors[DraftField.price] = 'Enter a price above zero.';
    }

    final quantityValue = double.tryParse(quantity.text.trim());
    if (quantity.text.trim().isEmpty) {
      errors[DraftField.quantity] = 'Please enter how much you have to sell.';
    } else if (quantityValue == null || quantityValue < 0 || (!allowZeroQuantity && quantityValue == 0)) {
      errors[DraftField.quantity] = 'Enter a quantity above zero.';
    }

    if (isPreorder && harvestDate == null) {
      errors[DraftField.harvestDate] = 'Please pick the expected harvest date.';
    }
    if (!allowsMeetup && !allowsDelivery) errors[DraftField.dealMethod] = 'Please choose a deal method';
    return errors;
  }

  /// Switching pre-order on or off flips what the harvest date means, so a
  /// date that no longer fits is dropped rather than silently kept.
  void setPreorder(bool value) {
    isPreorder = value;
    final date = harvestDate;
    if (date == null) return;
    final today = dateOnly(DateTime.now());
    if (value && date.isBefore(today)) harvestDate = null;
    if (!value && date.isAfter(today)) harvestDate = null;
  }

  /// Fills the description box from [template]. "Write my own" empties it.
  void applyTemplate(DescriptionTemplate template) {
    this.template = template;
    description.text = template == DescriptionTemplate.writeMyOwn ? '' : buildDescription(template);
  }

  String buildDescription(DescriptionTemplate template) {
    final name = title.text.trim().isEmpty ? 'produce' : title.text.trim();
    final grade = ListingOptions.labelOf(ListingOptions.qualityGrades, qualityGrade);
    final qty = double.tryParse(quantity.text.trim());
    final stock = qty == null || qty <= 0 ? null : '${formatQuantity(qty)} $unit';
    final date = harvestDate == null ? null : formatListingDate(harvestDate!);
    final harvest = date == null ? null : (isPreorder ? 'Expected harvest: $date' : 'Harvested: $date');
    final deals = [
      if (allowsMeetup) 'meet-up at a bagsakan center',
      if (allowsDelivery) 'courier delivery',
    ];

    switch (template) {
      case DescriptionTemplate.casual:
        return [
          isPreorder ? 'Pre-order our $name before harvest!' : 'Fresh $name straight from our farm!',
          if (date != null) isPreorder ? 'We expect to harvest on $date.' : 'Picked on $date.',
          '${_farmingPhrase(capitalized: true)}, ${_gradePhrase()}.',
          if (stock != null) 'We have $stock ready for you.',
          'Message us for bulk orders or any questions.',
        ].join(' ');
      case DescriptionTemplate.simple:
        return [
          '$name. $grade grade, ${_farmingPhrase()}.',
          if (harvest != null) '$harvest.',
          if (stock != null) '$stock available.',
          if (deals.isNotEmpty) 'Available for ${deals.join(' or ')}.',
        ].join(' ');
      case DescriptionTemplate.bulletPoints:
        return [
          '- Produce: $name',
          '- Quality: $grade',
          '- Farming: ${ListingOptions.labelOf(ListingOptions.farmingMethods, farmingMethod)}',
          if (harvest != null) '- $harvest',
          if (stock != null) '- Available: $stock',
          if (deals.isNotEmpty) '- Deal: ${deals.join(', ')}',
        ].join('\n');
      case DescriptionTemplate.writeMyOwn:
        return description.text;
    }
  }

  String _gradePhrase() => switch (qualityGrade) {
        'premium' => 'premium quality',
        'imperfect' => 'a little imperfect in looks but just as fresh',
        _ => 'good everyday quality',
      };

  String _farmingPhrase({bool capitalized = false}) {
    final phrase = switch (farmingMethod) {
      'organic' => 'organically grown',
      'pesticide-free' => 'grown without pesticides',
      _ => 'conventionally grown',
    };
    return capitalized ? '${phrase[0].toUpperCase()}${phrase.substring(1)}' : phrase;
  }

  /// Resets every field, keeping the draft itself in the list.
  void clear() {
    for (final controller in [title, price, quantity, description]) {
      controller.clear();
    }
    photos.clear();
    category = null;
    unit = 'kg';
    qualityGrade = 'standard';
    farmingMethod = 'conventional';
    harvestDate = null;
    isPreorder = false;
    allowsMeetup = false;
    allowsDelivery = false;
    template = null;
    showErrors = false;
  }

  /// Only valid once [validate] is empty; [images] are the photos' server
  /// paths in display order.
  ListingSubmission toSubmission(List<String> images) => ListingSubmission(
        cropName: title.text.trim(),
        category: category!,
        price: double.parse(price.text.trim()),
        quantity: double.parse(quantity.text.trim()),
        unit: unit,
        description: description.text.trim(),
        qualityGrade: qualityGrade,
        farmingMethod: farmingMethod,
        harvestDate: harvestDate,
        isPreorder: isPreorder,
        allowsMeetup: allowsMeetup,
        allowsDelivery: allowsDelivery,
        images: images,
      );

  void dispose() {
    for (final controller in [title, price, quantity, description]) {
      controller.dispose();
    }
  }
}

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
