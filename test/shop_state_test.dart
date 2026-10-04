import 'package:flutter_test/flutter_test.dart';
import 'package:smart_mart/models/shop_state.dart';

void main() {
  test('parses shopping state safely', () {
    final state = ShopStateModel.fromJson({
      'session': {
        'sessionId': 'SES-1',
        'trolleyId': 'TROLLEY-01',
        'status': 'ACTIVE',
        'orderId': ''
      },
      'cart': [
        {
          'cartItemId': 'PRD001',
          'productId': 'PRD001',
          'name': 'Milk',
          'pack': '500 ml',
          'qty': 2,
          'unitPrice': 25,
          'lineTotal': 50
        }
      ],
      'total': 50,
      'order': null,
    });
    expect(state.session?.trolleyId, 'TROLLEY-01');
    expect(state.cart.single.qty, 2);
    expect(state.total, 50);
  });

  test('parses a pending trolley return after session cancellation', () {
    final state = ShopStateModel.fromJson({
      'session': null,
      'cart': [],
      'total': 0,
      'order': null,
      'trolleyReturn': {
        'trolleyId': 'TROLLEY-01',
        'status': 'RETURN_PENDING',
        'reasonCode': 'TROLLEY_DAMAGED',
      },
    });

    expect(state.session, isNull);
    expect(state.cart, isEmpty);
    expect(state.trolleyReturn?.trolleyId, 'TROLLEY-01');
    expect(state.trolleyReturn?.status, 'RETURN_PENDING');
    expect(state.trolleyReturn?.reasonCode, 'TROLLEY_DAMAGED');
  });
}
