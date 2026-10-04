import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/cart_item.dart';
import '../models/shop_state.dart';
import '../state/shop_controller.dart';
import '../widgets/brand_header.dart';
import '../widgets/status_chip.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _trolley = TextEditingController();
  final _product = TextEditingController();
  String _paymentMethod = 'CASH';
  bool _paymentSheetOpen = false;
  bool _paymentMinimized = false;
  bool _paymentSubmitting = false;

  @override
  void dispose() {
    _trolley.dispose();
    _product.dispose();
    super.dispose();
  }

  Future<String?> _scan(String title, String hint) {
    return Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => ScannerScreen(title: title, hint: hint)));
  }

  void _showErrorIfNeeded(ShopController shop) {
    final message = shop.error;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    shop.clearError();
  }

  Future<String?> _pickReason(
    String title,
    String description,
    Map<String, String> reasons,
  ) =>
      showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 12),
              ...reasons.entries.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, reason.key),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(reason.value),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Go back'),
            ),
          ],
        ),
      );

  Future<void> _cancelShopping(ShopController shop) async {
    final reason = await _pickReason(
      'Cancel this shopping session?',
      'Your cart will be cancelled. Please return trolley ${shop.data.session!.trolleyId} to staff; it will not be released automatically.',
      const {
        'CUSTOMER_CANCELLED': 'I changed my mind',
        'TROLLEY_DAMAGED': 'The trolley is damaged',
        'CUSTOMER_NEEDS_TO_LEAVE': 'I need to leave',
      },
    );
    if (reason == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm cancellation'),
        content: const Text(
          'This will cancel your current cart. The trolley stays reserved until staff checks it in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep shopping'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await shop.cancelSession(reason);
    }
  }

  Future<void> _switchTrolley(ShopController shop) async {
    final reason = await _pickReason(
      'Why are you changing trolleys?',
      'Your cart will stay active on the new trolley.',
      const {
        'TROLLEY_DAMAGED': 'Current trolley is damaged',
        'CUSTOMER_CHANGED_TROLLEY': 'I need a different trolley',
      },
    );
    if (reason == null || !mounted) return;
    final code = await _scan(
      'Scan replacement trolley',
      'Scan the QR code on the available replacement trolley.',
    );
    if (code == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move to this trolley?'),
        content: Text(
          'The trolley you are using (${shop.data.session!.trolleyId}) will be marked for staff return. Transfer all items from your cart to trolley $code before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Transfer & switch'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await shop.switchTrolley(code, reason);
    }
  }

  Future<void> _cancelOrder(ShopController shop) async {
    final order = shop.data.order;
    if (order == null) return;
    final reason = await _pickReason(
      'Cancel this order?',
      'You can cancel only while payment is still pending. If payment was confirmed, staff must help with the order.',
      const {
        'CUSTOMER_CANCELLED': 'I changed my mind',
        'TROLLEY_DAMAGED': 'The trolley is damaged',
        'CUSTOMER_NEEDS_TO_LEAVE': 'I need to leave',
      },
    );
    if (reason == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm order cancellation'),
        content: Text(
          'Cancel order ${order.orderId} for ₹${order.total.toStringAsFixed(2)}? If payment has already been confirmed, the server will ask you to contact staff.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await shop.cancelOrder(order.orderId, reason);
    }
  }

  Future<void> _confirmCart(ShopController shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your cart?'),
        content: Text(
          shop.pendingProductCount == 0
              ? '${shop.itemCount} item${shop.itemCount == 1 ? '' : 's'} • ₹${shop.data.total.toStringAsFixed(2)}'
              : '${shop.itemCount} items • The total will be updated with your latest scans.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review cart'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _openPaymentSheet(shop);
  }

  Future<void> _openPaymentSheet(ShopController shop) async {
    if (_paymentSheetOpen) return;
    setState(() {
      _paymentSheetOpen = true;
      _paymentMinimized = false;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => PopScope(
          canPop: !_paymentSubmitting,
          child: Consumer<ShopController>(
            builder: (context, currentShop, _) => Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Choose payment',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Minimize payment',
                        onPressed: _paymentSubmitting
                            ? null
                            : () {
                                setState(() => _paymentMinimized = true);
                                Navigator.pop(sheetContext);
                              },
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentShop.pendingProductCount > 0
                        ? 'Your latest scans are being added. The final total is confirmed before payment.'
                        : currentShop.failedProductCount > 0
                            ? 'Retry or remove products that could not be added to continue.'
                            : 'Total • ₹${currentShop.data.total.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 18),
                  RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      if (currentShop.loading || value == null) return;
                      setState(() => _paymentMethod = value);
                      setSheetState(() {});
                    },
                    child: Column(
                      children: const [
                        ('CASH', Icons.payments_outlined, 'Cash'),
                        ('UPI', Icons.phone_android_rounded, 'UPI'),
                        ('QR', Icons.qr_code_2_rounded, 'QR'),
                      ]
                          .map(
                            (method) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RadioListTile<String>(
                                value: method.$1,
                                enabled: !currentShop.loading,
                                secondary:
                                    Icon(method.$2, color: AppTheme.deepGreen),
                                title: Text(method.$3,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                  side: BorderSide(color: Color(0xFFE9EAEC)),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: currentShop.loading ||
                            currentShop.failedProductCount > 0 ||
                            _paymentSubmitting
                        ? null
                        : () async {
                            setState(() => _paymentSubmitting = true);
                            setSheetState(() => _paymentSubmitting = true);
                            final ok =
                                await currentShop.checkout(_paymentMethod);
                            if (!sheetContext.mounted) return;
                            if (ok) {
                              Navigator.pop(sheetContext);
                            } else {
                              setState(() => _paymentSubmitting = false);
                              setSheetState(() => _paymentSubmitting = false);
                            }
                          },
                    child: _paymentSubmitting || currentShop.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            currentShop.pendingProductCount > 0
                                ? 'Confirm & pay'
                                : 'Confirm & pay • ₹${currentShop.data.total.toStringAsFixed(2)}',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _paymentSheetOpen = false;
      if (shop.data.order == null) _paymentMinimized = true;
      _paymentSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopController>(
      builder: (context, shop, _) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showErrorIfNeeded(shop));
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .98, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: shop.initialized
              ? KeyedSubtree(
                  key: const ValueKey('home'),
                  child: Scaffold(
                    body: SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await shop.refresh();
                            },
                            child: ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 120),
                              children: [
                                BrandHeader(
                                  trailing: IconButton.filledTonal(
                                    tooltip: 'Refresh',
                                    onPressed: shop.loading || shop.refreshing
                                        ? null
                                        : () async {
                                            await shop.refresh();
                                          },
                                    icon: shop.refreshing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.refresh_rounded),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (shop.data.trolleyReturn != null) ...[
                                  _TrolleyReturnCard(
                                    trolleyReturn: shop.data.trolleyReturn!,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (!shop.hasSession) ...[
                                  _WelcomeCard(
                                    controller: _trolley,
                                    busy: shop.loading,
                                    onScan: () async {
                                      final value = await _scan('Scan trolley',
                                          'Point the camera at the trolley QR code.');
                                      if (value == null) return;
                                      _trolley.text = value;
                                      await shop.claimTrolley(value);
                                    },
                                    onClaim: () async {
                                      final code = _trolley.text.trim();
                                      if (code.isEmpty) return;
                                      await shop.claimTrolley(code);
                                    },
                                  ),
                                ] else ...[
                                  _SessionCard(
                                    shop: shop,
                                    busy: shop.loading ||
                                        shop.pendingProductCount > 0 ||
                                        shop.failedProductCount > 0,
                                    onSwitch: () => _switchTrolley(shop),
                                    onCancel: () => _cancelShopping(shop),
                                  ),
                                  const SizedBox(height: 14),
                                  if (shop.cartEditable)
                                    _ScanProductCard(
                                      controller: _product,
                                      busy: shop.loading || shop.refreshing,
                                      onScan: () async {
                                        final value = await _scan(
                                            'Scan product',
                                            'Scan the product QR code or barcode before putting it in the trolley.');
                                        if (value == null) return;
                                        _product.text = value;
                                        shop.addProduct(value);
                                        _product.clear();
                                      },
                                      onAdd: () async {
                                        final code = _product.text.trim();
                                        if (code.isEmpty) return;
                                        shop.addProduct(code);
                                        _product.clear();
                                      },
                                    ),
                                  const SizedBox(height: 14),
                                  _CartCard(shop: shop),
                                ],
                                if (shop.data.order != null) ...[
                                  const SizedBox(height: 14),
                                  _OrderCard(
                                    shop: shop,
                                    canCancel: shop.data.order!.paymentStatus
                                                .trim()
                                                .toUpperCase() ==
                                            'PENDING' &&
                                        shop.data.order!.orderStatus
                                                .trim()
                                                .toUpperCase() ==
                                            'PAYMENT_PENDING',
                                    busy: shop.loading,
                                    onCancel: () => _cancelOrder(shop),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomNavigationBar: shop.hasSession
                        ? SafeArea(
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                      top: BorderSide(
                                          color: Color(0xFFE5E7EB)))),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 10, 18, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${shop.itemCount} item${shop.itemCount == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                              color: AppTheme.muted,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          shop.pendingProductCount > 0
                                              ? 'Updating total…'
                                              : '₹${shop.data.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.ink),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (shop.cartEditable &&
                                      shop.data.cart.isNotEmpty)
                                    FilledButton.icon(
                                      onPressed: shop.loading ||
                                              shop.refreshing ||
                                              _paymentSubmitting
                                          ? null
                                          : _paymentMinimized
                                              ? () => _openPaymentSheet(shop)
                                              : () => _confirmCart(shop),
                                      icon: Icon(
                                        _paymentMinimized
                                            ? Icons.payment_rounded
                                            : Icons.fact_check_rounded,
                                      ),
                                      label: Text(_paymentMinimized
                                          ? 'Continue payment'
                                          : 'Confirm cart'),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                )
              : const _StartupSplash(
                  key: ValueKey('startup-splash'),
                ),
        );
      },
    );
  }
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash({super.key});

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Opacity(
                      opacity: .82 + (_controller.value * .18),
                      child: Transform.scale(
                        scale: .94 + (_controller.value * .06),
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.green, AppTheme.deepGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.green.withValues(alpha: .22),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Smark Mart',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Getting your trolley ready',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(minHeight: 5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard(
      {required this.controller,
      required this.busy,
      required this.onScan,
      required this.onClaim});
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.shopping_cart_checkout_rounded,
                  color: AppTheme.green)),
          const SizedBox(height: 18),
          const Text('Start shopping',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'No login needed. Scan the QR fixed on your trolley and start adding products.',
              style: TextStyle(color: AppTheme.muted, height: 1.45)),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: busy ? null : onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Trolley QR')),
          const SizedBox(height: 12),
          TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Or enter trolley code',
                  hintText: 'SM-TROLLEY-01')),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: busy ? null : onClaim,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: const Text('Use trolley code')),
        ]),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.shop,
    required this.busy,
    required this.onSwitch,
    required this.onCancel,
  });

  final ShopController shop;
  final bool busy;
  final VoidCallback onSwitch;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = shop.data.session!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active trolley',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.trolleyId,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                StatusChip(s.status),
              ],
            ),
            if (shop.cartEditable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onSwitch,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Change trolley'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: busy ? null : onCancel,
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFB42318)),
                      label: const Text(
                        'Cancel shopping',
                        style: TextStyle(color: Color(0xFFB42318)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrolleyReturnCard extends StatelessWidget {
  const _TrolleyReturnCard({required this.trolleyReturn});

  final TrolleyReturnModel trolleyReturn;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFFAEB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.assignment_return_rounded,
                  color: Color(0xFFB54708)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Return trolley to staff',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trolleyReturn.trolleyId} is awaiting staff check-in. It cannot be used again until staff confirms its return.',
                      style:
                          const TextStyle(color: AppTheme.muted, height: 1.4),
                    ),
                    if (trolleyReturn.reasonCode == 'TROLLEY_DAMAGED') ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Please tell staff this trolley may be damaged.',
                        style: TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ScanProductCard extends StatelessWidget {
  const _ScanProductCard(
      {required this.controller,
      required this.busy,
      required this.onScan,
      required this.onAdd});
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add products',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('Scan every product before placing it in the trolley.',
                  style: TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: const Text('Scan Product')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            hintText: 'SM-PRD001 / barcode'))),
                const SizedBox(width: 10),
                SizedBox(
                    height: 54,
                    child: FilledButton(
                        onPressed: busy ? null : onAdd,
                        child: const Icon(Icons.add_rounded)))
              ])
            ])));
  }
}

class _CartCard extends StatelessWidget {
  const _CartCard({required this.shop});
  final ShopController shop;
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('Your cart',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      '${shop.itemCount} ${shop.itemCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                          color: AppTheme.deepGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 12),
              if (shop.data.cart.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                        child: Column(children: [
                      Icon(Icons.shopping_basket_outlined,
                          size: 40, color: AppTheme.muted),
                      SizedBox(height: 8),
                      Text('Your cart is empty',
                          style: TextStyle(color: AppTheme.muted))
                    ])))
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Column(
                    key: ValueKey(shop.data.cart
                        .map((item) => item.cartItemId)
                        .join('|')),
                    children: shop.data.cart.map((item) {
                      final pending = item.cartItemId.startsWith('pending:');
                      final failed = shop.isProductFailed(item.cartItemId);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CartItemTile(
                          key: ValueKey(item.cartItemId),
                          item: item,
                          editable: shop.cartEditable && !pending,
                          busy: shop.loading || shop.pendingProductCount > 0,
                          pending: pending,
                          failed: failed,
                          onRetry: () => shop.retryProduct(item.cartItemId),
                          onRemove: () =>
                              shop.removeFailedProduct(item.cartItemId),
                          onDecrease: () =>
                              shop.changeQty(item.cartItemId, item.qty - 1),
                          onIncrease: () =>
                              shop.changeQty(item.cartItemId, item.qty + 1),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (shop.data.cart.isNotEmpty) ...[
                const Divider(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.pendingProductCount > 0
                            ? 'Total is updating'
                            : shop.failedProductCount > 0
                                ? 'Some products need attention'
                                : 'Total',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (shop.pendingProductCount == 0)
                      Text(
                        '₹${shop.data.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900),
                      )
                    else
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ]
            ])));
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile(
      {super.key,
      required this.item,
      required this.editable,
      required this.busy,
      required this.pending,
      required this.failed,
      required this.onRetry,
      required this.onRemove,
      required this.onDecrease,
      required this.onIncrease});

  final CartItemModel item;
  final bool editable;
  final bool busy;
  final bool pending;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 280;
      final productDetails = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
          if (item.pack.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(item.pack,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
          if (!pending && !compact) ...[
            const SizedBox(height: 4),
            Text('₹${item.unitPrice.toStringAsFixed(2)} each',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          ],
        ],
      );
      final unitPrice = Text('₹${item.unitPrice.toStringAsFixed(2)} each',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted));
      final lineTotal = Text('₹${item.lineTotal.toStringAsFixed(2)}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w900));
      final quantity = editable
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              _QuantityButton(
                  icon: Icons.remove_rounded,
                  label: 'Decrease quantity',
                  busy: busy,
                  onPressed: onDecrease),
              SizedBox(
                  width: 30,
                  child: Text('${item.qty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              _QuantityButton(
                  icon: Icons.add_rounded,
                  label: 'Increase quantity',
                  busy: busy,
                  onPressed: onIncrease),
            ])
          : pending
              ? const SizedBox.shrink()
              : Text('Quantity: ${item.qty}',
                  style: const TextStyle(fontWeight: FontWeight.w800));
      final pendingIndicator = failed
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
                IconButton(
                  tooltip: 'Remove failed product',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 7),
                Text('Adding',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700)),
              ],
            );

      return Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _ProductIcon(compact: true),
                  const SizedBox(width: 10),
                  Expanded(child: productDetails),
                ]),
                const SizedBox(height: 10),
                if (pending)
                  Align(
                      alignment: Alignment.centerLeft, child: pendingIndicator)
                else ...[
                  unitPrice,
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerRight, child: lineTotal),
                ],
                if (!pending) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: quantity),
                ],
              ])
            : Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _ProductIcon(compact: false),
                  const SizedBox(width: 12),
                  Expanded(child: productDetails),
                  const SizedBox(width: 10),
                  pending ? pendingIndicator : lineTotal,
                ]),
                const SizedBox(height: 12),
                if (!pending)
                  Row(children: [unitPrice, const Spacer(), quantity]),
              ]),
      );
    });
  }
}

class _ProductIcon extends StatelessWidget {
  const _ProductIcon({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: compact ? 40 : 46,
        height: compact ? 40 : 46,
        decoration: BoxDecoration(
            color: AppTheme.green.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14)),
        child:
            const Icon(Icons.inventory_2_outlined, color: AppTheme.deepGreen),
      );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton(
      {required this.icon,
      required this.label,
      required this.busy,
      required this.onPressed});
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        height: 36,
        child: IconButton.filledTonal(
          tooltip: label,
          onPressed: busy ? null : onPressed,
          icon: Icon(icon, size: 18),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.shop,
    required this.canCancel,
    required this.busy,
    required this.onCancel,
  });

  final ShopController shop;
  final bool canCancel;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final o = shop.data.order!;
    final orderCancelled = const {'CANCELLED', 'CANCELED'}
        .contains(o.orderStatus.trim().toUpperCase());
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                orderCancelled ? Icons.cancel_outlined : Icons.verified_rounded,
                color:
                    orderCancelled ? const Color(0xFFB54708) : AppTheme.green,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                orderCancelled ? 'Order cancelled' : 'Checkout submitted',
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                orderCancelled
                    ? 'This order has been cancelled. Return the trolley to staff for check-in.'
                    : 'Keep this screen open and proceed to the counter / dispatch gate.',
                style: const TextStyle(color: AppTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'Order', value: o.orderId),
              _InfoRow(label: 'Payment', value: o.paymentMethod),
              _InfoRow(
                  label: 'Amount', value: '₹${o.total.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              Row(children: [
                StatusChip(o.paymentStatus),
                const SizedBox(width: 8),
                StatusChip(o.orderStatus)
              ]),
              if (canCancel && !orderCancelled) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel pending order'),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Orders with confirmed payment must be resolved by staff.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ])));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: AppTheme.muted))),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800)))
      ]));
}
