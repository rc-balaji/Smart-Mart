import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/shop_state.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  final AuthService _auth;
  final http.Client _client;

  Future<ShopStateModel> state() => _shopAction('STATE');

  Future<ShopStateModel> claimTrolley(String trolleyCode) =>
      _shopAction('CLAIM_TROLLEY', {'trolleyCode': trolleyCode});

  Future<ShopStateModel> addProduct(String productCode) =>
      _shopAction('ADD_PRODUCT', {'productCode': productCode});

  Future<ShopStateModel> changeQty(String cartItemId, int quantity) =>
      _shopAction(
          'CHANGE_QTY', {'cartItemId': cartItemId, 'quantity': quantity});

  Future<ShopStateModel> checkout(String method) =>
      _shopAction('CHECKOUT', {'method': method});

  Future<ShopStateModel> cancelSession(String reasonCode) =>
      _shopAction('CANCEL_SESSION', {'reasonCode': reasonCode});

  Future<ShopStateModel> switchTrolley(
    String newTrolleyCode,
    String reasonCode,
  ) =>
      _shopAction('SWITCH_TROLLEY', {
        'newTrolleyCode': newTrolleyCode,
        'reasonCode': reasonCode,
      });

  Future<ShopStateModel> cancelOrder(
    String orderId,
    String reasonCode,
  ) =>
      _shopAction('CANCEL_ORDER', {
        'orderId': orderId,
        'reasonCode': reasonCode,
      });

  Future<ShopStateModel> _shopAction(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (!AppConfig.hasApiBaseUrl) {
      throw ApiException('API_BASE_URL is missing from this build.');
    }

    String token;
    try {
      token = await _auth.freshIdToken();
    } catch (_) {
      throw ApiException(
          'Firebase anonymous sign-in failed. Enable Anonymous Authentication in Firebase.');
    }
    final uri = Uri.parse(AppConfig.endpoint('/api/customer/action'));

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': action, 'payload': payload}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(
          'Server timeout. Please check your connection and retry.');
    } on Exception {
      throw ApiException('Unable to reach Smark Mart server.');
    }

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw ApiException('Server returned an invalid response.',
          statusCode: response.statusCode);
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      final code = body['errorCode']?.toString();
      final serverMessage = body['error']?.toString();
      throw ApiException(
        _actionErrorMessage(code, serverMessage),
        statusCode: response.statusCode,
        code: code,
      );
    }

    final data = body['data'];
    if (data is! Map) {
      throw ApiException('Server response did not contain shopping state.');
    }
    return ShopStateModel.fromJson(Map<String, dynamic>.from(data));
  }

  String _actionErrorMessage(String? code, String? message) {
    const knownMessages = {
      'SESSION_NOT_CANCELLABLE':
          'This shopping session can no longer be cancelled. Please ask staff for help.',
      'TROLLEY_UNAVAILABLE':
          'That trolley is not available. Please scan a different trolley.',
      'ORDER_NOT_CANCELLABLE':
          'This order can no longer be cancelled from the app. Please ask staff for help.',
      'PAYMENT_ALREADY_CONFIRMED':
          'Payment has already been confirmed. Please contact staff to resolve the order.',
    };
    if (code != null && knownMessages.containsKey(code)) {
      return knownMessages[code]!;
    }
    return message ?? code ?? 'Request failed';
  }

  void dispose() => _client.close();
}
