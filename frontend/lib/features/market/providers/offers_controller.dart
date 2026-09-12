import 'package:flutter/foundation.dart';

import '../../../shared/data/negotiation_service.dart';
import '../../login/services/auth_service.dart';

/// Which side of the user's negotiations the Market tab is showing.
enum OffersSide { received, sent }

/// Loads and mutates the signed-in user's negotiations for the Market tab.
///
/// `received` are offers on the user's own listings (they are the seller);
/// `sent` are offers the user made on other people's listings (buyer).
class OffersController extends ChangeNotifier {
  OffersController({NegotiationService? service})
      : _service = service ?? NegotiationService();

  final NegotiationService _service;

  OffersSide side = OffersSide.received;
  List<NegotiationRecord> received = const [];
  List<NegotiationRecord> sent = const [];
  bool isLoading = false;
  String? errorMessage;

  /// Id of the negotiation currently being accepted/declined/countered, so the
  /// card can disable its buttons while the request is in flight.
  int? busyNegotiationId;

  int? get userId => AuthService.currentUserId;

  List<NegotiationRecord> get visible => side == OffersSide.received ? received : sent;

  /// Open offers on the current side that are waiting on this user.
  int get pendingActionCount {
    final id = userId;
    if (id == null) return 0;
    return visible.where((offer) => offer.isTurnOf(id)).length;
  }

  Future<void> load() async {
    final id = userId;
    if (id == null) {
      errorMessage = 'Log in to see your offers.';
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      // Two calls rather than one so each tab is already split server-side.
      final results = await Future.wait([
        _service.fetchNegotiations(userId: id, role: 'seller'),
        _service.fetchNegotiations(userId: id, role: 'buyer'),
      ]);
      received = results[0];
      sent = results[1];
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void showSide(OffersSide next) {
    if (side == next) return;
    side = next;
    notifyListeners();
  }

  /// Sends [action] and swaps the updated record into place. Returns an error
  /// message for the caller to show, or null on success.
  Future<String?> respond(
    NegotiationRecord offer,
    NegotiationAction action, {
    double? price,
    double? quantity,
  }) async {
    final id = userId;
    if (id == null) return 'Log in to respond to offers.';
    busyNegotiationId = offer.id;
    notifyListeners();
    try {
      final updated = await _service.respond(
        negotiationId: offer.id,
        userId: id,
        action: action,
        price: price,
        quantity: quantity,
      );
      received = _replace(received, updated);
      sent = _replace(sent, updated);
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      busyNegotiationId = null;
      notifyListeners();
    }
  }

  List<NegotiationRecord> _replace(List<NegotiationRecord> list, NegotiationRecord updated) {
    return list.map((offer) => offer.id == updated.id ? updated : offer).toList(growable: false);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
