import 'package:flutter/foundation.dart';
import '../models/shop_state.dart';
import '../services/api_client.dart';

class ShopController extends ChangeNotifier {
  ShopController(this._api);

  final ApiClient _api;

  ShopStateModel data = ShopStateModel.empty();
  bool loading = false;
  String? error;
  bool initialized = false;

  bool get hasSession => data.session != null;
  bool get cartEditable => data.session?.status == 'ACTIVE';
  int get itemCount => data.cart.fold<int>(0, (a, b) => a + b.qty);

  Future<void> bootstrap() async {
    await _run(() => _api.state(), markInitialized: true);
  }

  Future<bool> claimTrolley(String code) => _run(() => _api.claimTrolley(code));
  Future<bool> addProduct(String code) => _run(() => _api.addProduct(code));
  Future<bool> changeQty(String cartItemId, int qty) =>
      _run(() => _api.changeQty(cartItemId, qty));
  Future<bool> checkout(String method) => _run(() => _api.checkout(method));
  Future<bool> refresh() => _run(() => _api.state(), quiet: true);

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<bool> _run(
    Future<ShopStateModel> Function() operation, {
    bool quiet = false,
    bool markInitialized = false,
  }) async {
    if (!quiet) loading = true;
    error = null;
    notifyListeners();
    try {
      data = await operation();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Something went wrong. Please retry.';
      return false;
    } finally {
      if (!quiet) loading = false;
      if (markInitialized) initialized = true;
      notifyListeners();
    }
  }
}
