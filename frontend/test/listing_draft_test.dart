import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/listing/models/listing_draft.dart';
import 'package:frontend/shared/data/synthetic_records.dart';

ListingDraft _completeDraft() {
  final draft = ListingDraft()
    ..category = 'fruit'
    ..allowsDelivery = true;
  draft.title.text = 'Lakatan banana';
  draft.price.text = '85';
  draft.quantity.text = '40';
  draft.photos.add(ListingPhoto.local(File('cover.jpg')));
  return draft;
}

void main() {
  test('a blank draft reports every required field', () {
    final errors = ListingDraft().validate();
    expect(errors.keys, containsAll(<DraftField>[
      DraftField.photos,
      DraftField.category,
      DraftField.title,
      DraftField.price,
      DraftField.quantity,
      DraftField.dealMethod,
    ]));
    expect(errors[DraftField.price], 'Please enter a price.');
    expect(errors[DraftField.dealMethod], 'Please choose a deal method');
  });

  test('a complete draft is valid; a pre-order also needs its harvest date', () {
    final draft = _completeDraft();
    expect(draft.validate(), isEmpty);

    draft.setPreorder(true);
    expect(draft.validate().keys, [DraftField.harvestDate]);

    draft.harvestDate = DateTime.now().add(const Duration(days: 14));
    expect(draft.validate(), isEmpty);
  });

  test('zero stock is only allowed when editing a live listing', () {
    final draft = _completeDraft()..quantity.text = '0';
    expect(draft.validate().keys, [DraftField.quantity]);
    expect(draft.validate(allowZeroQuantity: true), isEmpty);
  });

  test('switching pre-order drops a harvest date that no longer fits', () {
    final draft = _completeDraft()..harvestDate = DateTime.now().subtract(const Duration(days: 2));
    draft.setPreorder(true);
    expect(draft.harvestDate, isNull);

    draft.harvestDate = DateTime.now().add(const Duration(days: 5));
    draft.setPreorder(false);
    expect(draft.harvestDate, isNull);
  });

  test('templates write from the filled-in details', () {
    final draft = _completeDraft()
      ..qualityGrade = 'premium'
      ..farmingMethod = 'organic'
      ..allowsMeetup = true
      ..harvestDate = DateTime(2026, 10, 27);

    draft.applyTemplate(DescriptionTemplate.bulletPoints);
    expect(draft.description.text, '- Produce: Lakatan banana\n'
        '- Quality: Premium\n'
        '- Farming: Organic\n'
        '- Harvested: Oct 27, 2026\n'
        '- Available: 40 kg\n'
        '- Deal: meet-up at a bagsakan center, courier delivery');

    draft.applyTemplate(DescriptionTemplate.casual);
    expect(draft.description.text, startsWith('Fresh Lakatan banana straight from our farm! Picked on Oct 27, 2026.'));

    draft.applyTemplate(DescriptionTemplate.writeMyOwn);
    expect(draft.description.text, isEmpty);
    expect(draft.template, DescriptionTemplate.writeMyOwn);
  });

  test('submission matches the products API', () {
    final draft = _completeDraft()
      ..setPreorder(true)
      ..harvestDate = DateTime(2026, 11, 8);
    expect(draft.toSubmission(['/uploads/products/a.jpg']).toJson(), {
      'crop_name': 'Lakatan banana',
      'category': 'fruit',
      'base_price': 85.0,
      'available_quantity': 40.0,
      'unit_measurement': 'kg',
      'description': '',
      'quality_grade': 'standard',
      'farming_method': 'conventional',
      'harvest_date': '2026-11-08',
      'is_preorder': true,
      'allows_meetup': false,
      'allows_delivery': true,
      'images': ['/uploads/products/a.jpg'],
    });
  });

  test('a listing from the API keeps server paths for editing and URLs for display', () {
    final listing = SyntheticListingRecord.fromJson({
      'product_id': 8,
      'seller_id': 3,
      'crop_name': 'Pechay',
      'category': 'vegetable',
      'base_price': 60,
      'available_quantity': 20,
      'unit_measurement': 'kg',
      'description': '',
      'quality_grade': 'imperfect',
      'farming_method': 'pesticide-free',
      'harvest_date': '2026-10-29',
      'is_preorder': false,
      'allows_meetup': false,
      'allows_delivery': true,
      'images': ['/uploads/products/b.jpg', 'https://example.com/c.jpg'],
    });
    expect(listing.price, 'PHP 60 / kg');
    expect(listing.imagePaths, ['/uploads/products/b.jpg', 'https://example.com/c.jpg']);
    expect(listing.images.first, endsWith('/uploads/products/b.jpg'));
    expect(listing.images.first, startsWith('http'));
    expect(listing.images.last, 'https://example.com/c.jpg');
    expect(listing.writtenDescription, isEmpty);
    expect(listing.description, isNotEmpty);
    expect(listing.allowsMeetup, isFalse);
    expect(listing.harvestDate, DateTime(2026, 10, 29));

    final draft = ListingDraft.fromListing(listing);
    expect(draft.photos.map((photo) => photo.serverPath), listing.imagePaths);
    expect(draft.photos.every((photo) => !photo.needsUpload), isTrue);
    expect(draft.category, 'vegetable');
    expect(draft.qualityGrade, 'imperfect');
    expect(draft.allowsDelivery, isTrue);
    expect(draft.validate(allowZeroQuantity: true), isEmpty);
  });
}
