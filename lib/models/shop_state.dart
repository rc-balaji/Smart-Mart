import 'cart_item.dart';

class SessionModel {
  const SessionModel({
    required this.sessionId,
    required this.trolleyId,
    required this.status,
    required this.orderId,
  });

  final String sessionId;
  final String trolleyId;
  final String status;
  final String orderId;

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        sessionId: '${json['sessionId'] ?? ''}',
        trolleyId: '${json['trolleyId'] ?? ''}',
        status: '${json['status'] ?? ''}',
        orderId: '${json['orderId'] ?? ''}',
      );
}

class OrderModel {
  const OrderModel({
    required this.orderId,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
  });

  final String orderId;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        orderId: '${json['orderId'] ?? ''}',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        paymentMethod: '${json['paymentMethod'] ?? ''}',
        paymentStatus: '${json['paymentStatus'] ?? ''}',
        orderStatus: '${json['orderStatus'] ?? ''}',
      );
}

class TrolleyReturnModel {
  const TrolleyReturnModel({
    required this.trolleyId,
    required this.status,
    required this.reasonCode,
  });

  final String trolleyId;
  final String status;
  final String reasonCode;

  factory TrolleyReturnModel.fromJson(Map<String, dynamic> json) =>
      TrolleyReturnModel(
        trolleyId: '${json['trolleyId'] ?? ''}',
        status: '${json['status'] ?? ''}',
        reasonCode: '${json['reasonCode'] ?? ''}',
      );
}

class ShopStateModel {
  const ShopStateModel({
    required this.session,
    required this.cart,
    required this.total,
    required this.order,
    this.trolleyReturn,
  });

  final SessionModel? session;
  final List<CartItemModel> cart;
  final double total;
  final OrderModel? order;
  final TrolleyReturnModel? trolleyReturn;

  factory ShopStateModel.empty() => const ShopStateModel(
        session: null,
        cart: [],
        total: 0,
        order: null,
        trolleyReturn: null,
      );

  factory ShopStateModel.fromJson(Map<String, dynamic> json) {
    final rawCart = (json['cart'] as List?) ?? const [];
    return ShopStateModel(
      session: json['session'] is Map
          ? SessionModel.fromJson(
              Map<String, dynamic>.from(json['session'] as Map))
          : null,
      cart: rawCart
          .whereType<Map>()
          .map((e) => CartItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      order: json['order'] is Map
          ? OrderModel.fromJson(Map<String, dynamic>.from(json['order'] as Map))
          : null,
      trolleyReturn: json['trolleyReturn'] is Map
          ? TrolleyReturnModel.fromJson(
              Map<String, dynamic>.from(json['trolleyReturn'] as Map))
          : null,
    );
  }
}
