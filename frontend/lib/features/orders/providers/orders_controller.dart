import 'package:flutter/foundation.dart';

import '../../../shared/data/order_service.dart';
import '../../login/services/auth_service.dart';

/// The signed-in user's orders, both sides: purchases where they are the
/// buyer and sales where they are the seller. Backs the profile's Orders tab.
class OrdersController extends ChangeNotifier {
  OrdersController({OrderService? service}) : _service = service ?? OrderService();

  final OrderService _service;

  List<OrderRecord> orders = const [];
  bool isLoading = false;
  String? errorMessage;

  int? get userId => AuthService.currentUserId;

  /// Orders that still need someone to act.
  int get openCount => orders.where((order) => order.status.isOpen).length;

  Future<void> load() async {
    final id = userId;
    if (id == null) {
      orders = const [];
      errorMessage = null;
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      orders = await _service.fetchOrders(userId: id);
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
