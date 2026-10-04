import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_mart/widgets/cart_checkout_bar.dart';

void main() {
  testWidgets('keeps cart summary readable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var checkoutTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: SafeArea(
            child: CartCheckoutBar(
              itemCount: 2,
              totalLabel: '₹220.00',
              showCheckout: true,
              continuePayment: false,
              busy: false,
              onCheckout: () => checkoutTapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₹220.00'), findsOneWidget);
    expect(find.text('Confirm cart'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Confirm cart'));
    expect(checkoutTapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
