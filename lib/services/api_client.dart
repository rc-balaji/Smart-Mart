import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/shop_state.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  final AuthService _auth;
  final http.Client _client;

  Future<ShopStateModel> state() => _shopAction('STATE');

  Future<ShopStateModel> claimTrolley(String trolleyCode) =>
      _shopAction('CLAIM_TROLLEY', {'trolleyCode': trolleyCode});

  Future<ShopStateModel> addProduct(String productCode) =>
      _shopAction('ADD_PRODUCT', {'productCode': productCode});

  Future<ShopStateModel> changeQty(String cartItemId, int quantity) =>
      _shopAction('CHANGE_QTY', {'cartItemId': cartItemId, 'quantity': quantity});

  Future<ShopStateModel> checkout(String method) =>
      _shopAction('CHECKOUT', {'method': method});

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
      throw ApiException('Firebase anonymous sign-in failed. Enable Anonymous Authentication in Firebase.');
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
      throw ApiException('Server timeout. Please check your connection and retry.');
    } on Exception {
      throw ApiException('Unable to reach Smark Mart server.');
    }

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw ApiException('Server returned an invalid response.', statusCode: response.statusCode);
    }

    if (response.statusCode < 200 || response.statusCode >= 300 || body['ok'] != true) {
      throw ApiException(
        '${body['error'] ?? 'Request failed'}',
        statusCode: response.statusCode,
      );
    }

    final data = body['data'];
    if (data is! Map) throw ApiException('Server response did not contain shopping state.');
    return ShopStateModel.fromJson(Map<String, dynamic>.from(data));
  }

  void dispose() => _client.close();
}
