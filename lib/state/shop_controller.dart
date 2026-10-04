import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/shop_state.dart';
import '../services/api_client.dart';

class ShopController extends ChangeNotifier {
  ShopController(this._api);

  final ApiClient _api;
  final Map<String, CartItemModel> _pendingProducts = {};
  final Set<String> _failedProducts = {};
  Future<void> _addQueue = Future<void>.value();
  int _pendingId = 0;

  ShopStateModel _serverData = ShopStateModel.empty();
  ShopStateModel data = ShopStateModel.empty();
  bool loading = false;
  bool refreshing = false;
  String? error;
  bool initialized = false;

  bool get hasSession => data.session != null;
  bool get cartEditable => data.session?.status == 'ACTIVE';
  int get itemCount => data.cart.fold<int>(0, (a, b) => a + b.qty);
  int get pendingProductCount =>
      _pendingProducts.length - _failedProducts.length;
  int get failedProductCount => _failedProducts.length;
  bool isProductFailed(String cartItemId) =>
      _failedProducts.contains(cartItemId);

  Future<void> bootstrap() async {
    await _run(() => _api.state(), markInitialized: true);
  }

  Future<bool> claimTrolley(String code) => _run(() => _api.claimTrolley(code));

  void addProduct(String code) {
    final pendingId =
        'pending:${DateTime.now().microsecondsSinceEpoch}:${_pendingId++}';
    _pendingProducts[pendingId] = CartItemModel(
      cartItemId: pendingId,
      productId: code,
      name: 'Adding product…',
      pack: code,
      qty: 1,
      unitPrice: 0,
      lineTotal: 0,
    );
    data = _withPendingProducts(_serverData);
    _queueProductWrite(pendingId, code);
  }

  void retryProduct(String cartItemId) {
    final item = _pendingProducts[cartItemId];
    if (item == null || !_failedProducts.contains(cartItemId)) return;
    _queueProductWrite(cartItemId, item.productId);
  }

  void removeFailedProduct(String cartItemId) {
    if (!_failedProducts.remove(cartItemId)) return;
    _pendingProducts.remove(cartItemId);
    data = _withPendingProducts(_serverData);
    notifyListeners();
  }

  void _queueProductWrite(String pendingId, String code) {
    _failedProducts.remove(pendingId);
    final item = _pendingProducts[pendingId];
    if (item != null) {
      _pendingProducts[pendingId] = CartItemModel(
        cartItemId: item.cartItemId,
        productId: item.productId,
        name: 'Adding product…',
        pack: item.pack,
        qty: item.qty,
        unitPrice: item.unitPrice,
        lineTotal: item.lineTotal,
      );
    }
    error = null;
    data = _withPendingProducts(_serverData);
    notifyListeners();
    _addQueue = _addQueue.then((_) async {
      try {
        final updated = await _api.addProduct(code);
        _pendingProducts.remove(pendingId);
        _serverData = updated;
      } on ApiException catch (e) {
        _failedProducts.add(pendingId);
        _setFailedProductLabel(pendingId);
        error = e.message;
      } catch (_) {
        _failedProducts.add(pendingId);
        _setFailedProductLabel(pendingId);
        error = 'Could not add this product. Please scan it again.';
      }
      data = _withPendingProducts(_serverData);
      notifyListeners();
    });
  }

  void _setFailedProductLabel(String pendingId) {
    final item = _pendingProducts[pendingId];
    if (item == null) return;
    _pendingProducts[pendingId] = CartItemModel(
      cartItemId: item.cartItemId,
      productId: item.productId,
      name: 'Could not add product',
      pack: item.pack,
      qty: item.qty,
      unitPrice: item.unitPrice,
      lineTotal: item.lineTotal,
    );
  }

  Future<bool> changeQty(String cartItemId, int qty) =>
      _run(() => _api.changeQty(cartItemId, qty));
  Future<bool> checkout(String method) async {
    await _addQueue;
    if (_failedProducts.isNotEmpty) {
      error =
          'Retry or remove products that could not be added before checkout.';
      notifyListeners();
      return false;
    }
    return _run(() => _api.checkout(method));
  }

  Future<bool> cancelSession(String reasonCode) async {
    if (!await _waitForProductWrites()) return false;
    return _run(() => _api.cancelSession(reasonCode));
  }

  Future<bool> switchTrolley(String newTrolleyCode, String reasonCode) async {
    if (!await _waitForProductWrites()) return false;
    return _run(() => _api.switchTrolley(newTrolleyCode, reasonCode));
  }

  Future<bool> cancelOrder(String orderId, String reasonCode) async {
    if (!await _waitForProductWrites()) return false;
    return _run(() => _api.cancelOrder(orderId, reasonCode));
  }

  Future<bool> _waitForProductWrites() async {
    await _addQueue;
    if (_failedProducts.isNotEmpty) {
      error = 'Retry or remove products that could not be added first.';
      notifyListeners();
      return false;
    }
    if (_pendingProducts.isNotEmpty) {
      error = 'Wait for product updates to finish before continuing.';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> refresh() async {
    refreshing = true;
    notifyListeners();
    try {
      await _addQueue;
      return await _run(() => _api.state(), quiet: true);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  ShopStateModel _withPendingProducts(ShopStateModel state) => ShopStateModel(
        session: state.session,
        cart: [...state.cart, ..._pendingProducts.values],
        total: state.total,
        order: state.order,
        trolleyReturn: state.trolleyReturn,
      );

  Future<bool> _run(
    Future<ShopStateModel> Function() operation, {
    bool quiet = false,
    bool markInitialized = false,
  }) async {
    if (!quiet) loading = true;
    error = null;
    notifyListeners();
    try {
      _serverData = await operation();
      data = _withPendingProducts(_serverData);
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
