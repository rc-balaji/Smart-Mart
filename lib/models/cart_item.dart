class CartItemModel {
  const CartItemModel({
    required this.cartItemId,
    required this.productId,
    required this.name,
    required this.pack,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String cartItemId;
  final String productId;
  final String name;
  final String pack;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel(
        cartItemId: '${json['cartItemId'] ?? ''}',
        productId: '${json['productId'] ?? ''}',
        name: '${json['name'] ?? json['productId'] ?? 'Product'}',
        pack: '${json['pack'] ?? ''}',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      );
}
