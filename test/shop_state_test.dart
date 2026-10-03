import 'package:flutter_test/flutter_test.dart';
import 'package:smart_mart/models/shop_state.dart';

void main() {
  test('parses shopping state safely', () {
    final state = ShopStateModel.fromJson({
      'session': {'sessionId': 'SES-1', 'trolleyId': 'TROLLEY-01', 'status': 'ACTIVE', 'orderId': ''},
      'cart': [
        {'cartItemId': 'PRD001', 'productId': 'PRD001', 'name': 'Milk', 'pack': '500 ml', 'qty': 2, 'unitPrice': 25, 'lineTotal': 50}
      ],
      'total': 50,
      'order': null,
    });
    expect(state.session?.trolleyId, 'TROLLEY-01');
    expect(state.cart.single.qty, 2);
    expect(state.total, 50);
  });
}
