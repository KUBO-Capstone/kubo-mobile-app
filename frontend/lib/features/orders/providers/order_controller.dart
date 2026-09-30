import 'package:flutter/foundation.dart';

import '../../../shared/data/order_service.dart';
import '../../login/services/auth_service.dart';

/// One order's detail page: the record plus the ship / deliver / cancel
/// actions, whichever the signed-in user's side and the status allow.
class OrderController extends ChangeNotifier {
  OrderController({required this.orderId, OrderService? service})
      : _service = service ?? OrderService();

  final int orderId;
  final OrderService _service;

  OrderRecord? order;
  bool isLoading = true;

  /// True while a ship / deliver / cancel request is in flight.
  bool isBusy = false;
  String? errorMessage;

  /// Whether anything changed since the page opened, so the caller knows
  /// to reload its own list or thread when this page pops.
  bool changed = false;

  int? get userId => AuthService.currentUserId;

  Future<void> load() async {
    final id = userId;
    if (id == null) {
      errorMessage = 'Log in to view orders.';
      isLoading = false;
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      order = await _service.fetchOrder(orderId: orderId);
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns an error string to show, or null on success.
  Future<String?> respond(OrderAction action, {String? courierName, String? trackingNumber}) async {
    final id = userId;
    if (id == null) return 'Log in to update orders.';
    isBusy = true;
    notifyListeners();
    try {
      order = await _service.respond(
        orderId: orderId,
        action: action,
        courierName: courierName,
        trackingNumber: trackingNumber,
      );
      changed = true;
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
