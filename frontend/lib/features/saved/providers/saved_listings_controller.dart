import 'package:flutter/foundation.dart';

import '../../../shared/data/saved_listing_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../login/services/auth_service.dart';

/// The signed-in user's saved (hearted) listings.
///
/// Unlike the per-screen controllers this is one app-wide instance, in the
/// same spirit as the static `AuthService.currentUser`: the heart on an
/// explore card, a map row, the listing carousel and the Saved page all have
/// to agree, so they all read [isSaved] here and rebuild off the same
/// notifier. Toggles are optimistic - the heart flips at once and flips back
/// if the server says no.
class SavedListingsController extends ChangeNotifier {
  SavedListingsController._();

  static final SavedListingsController instance = SavedListingsController._();

  final SavedListingService _service = SavedListingService();

  Set<int> _savedIds = <int>{};
  List<SyntheticListingRecord> listings = const [];
  bool isLoading = false;
  String? errorMessage;

  /// Which account [_savedIds] / [listings] belong to. The drawer's Logout
  /// does not clear `AuthService.currentUser`, so a login as someone else
  /// must not inherit the previous user's hearts.
  int? _loadedForUserId;

  int? get userId => AuthService.currentUserId;

  int get savedCount => _savedIds.length;

  bool isSaved(int? productId) => productId != null && _savedIds.contains(productId);

  /// Fetches the id set (cheap) so the hearts are right on every grid. Call
  /// from the landing screen; safe to call repeatedly.
  Future<void> loadIds() async {
    final id = userId;
    if (id == null) {
      _reset();
      notifyListeners();
      return;
    }
    if (id != _loadedForUserId) _reset();
    try {
      _savedIds = await _service.fetchSavedIds(userId: id);
      _loadedForUserId = id;
    } catch (error) {
      // A grid without hearts is fine; the Saved page reports errors.
      debugPrint('Saved ids fetch failed: $error');
    }
    notifyListeners();
  }

  /// Fetches the full rows for the Saved page.
  Future<void> load() async {
    final id = userId;
    if (id == null) {
      _reset();
      errorMessage = 'Log in to see your saved listings.';
      notifyListeners();
      return;
    }
    if (id != _loadedForUserId) _reset();
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      listings = await _service.fetchSaved(userId: id);
      _savedIds = listings.map((l) => l.productId).whereType<int>().toSet();
      _loadedForUserId = id;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Saves or unsaves [listing]. Returns the new saved state, or null when
  /// the server rejected it (the heart has already been put back).
  Future<bool?> toggle(SyntheticListingRecord listing) async {
    final id = userId;
    final productId = listing.productId;
    if (id == null || productId == null) return null;

    final nowSaved = !isSaved(productId);
    _apply(listing, saved: nowSaved);
    try {
      if (nowSaved) {
        await _service.save(userId: id, productId: productId);
      } else {
        await _service.unsave(userId: id, productId: productId);
      }
      return nowSaved;
    } catch (error) {
      _apply(listing, saved: !nowSaved);
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  void _apply(SyntheticListingRecord listing, {required bool saved}) {
    final productId = listing.productId!;
    if (saved) {
      _savedIds = {..._savedIds, productId};
      if (!listings.any((l) => l.productId == productId)) {
        listings = [listing, ...listings];
      }
    } else {
      _savedIds = {..._savedIds}..remove(productId);
      listings = listings.where((l) => l.productId != productId).toList(growable: false);
    }
    notifyListeners();
  }

  void _reset() {
    _savedIds = <int>{};
    listings = const [];
    errorMessage = null;
    _loadedForUserId = null;
  }
}
