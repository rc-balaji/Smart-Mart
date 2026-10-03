import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
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

  @override
  void dispose() {
    _trolley.dispose();
    _product.dispose();
    super.dispose();
  }

  Future<String?> _scan(String title, String hint) {
    return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ScannerScreen(title: title, hint: hint)));
  }

  void _showErrorIfNeeded(ShopController shop) {
    final message = shop.error;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    shop.clearError();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopController>(
      builder: (context, shop, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showErrorIfNeeded(shop));
        if (!shop.initialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async { await shop.refresh(); },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: [
                  BrandHeader(
                    trailing: IconButton.filledTonal(
                      tooltip: 'Refresh',
                      onPressed: shop.loading ? null : () async { await shop.refresh(); },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!shop.hasSession) ...[
                    _WelcomeCard(
                      controller: _trolley,
                      busy: shop.loading,
                      onScan: () async {
                        final value = await _scan('Scan trolley', 'Point the camera at the trolley QR code.');
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
                    _SessionCard(shop: shop),
                    const SizedBox(height: 14),
                    if (shop.cartEditable)
                      _ScanProductCard(
                        controller: _product,
                        busy: shop.loading,
                        onScan: () async {
                          final value = await _scan('Scan product', 'Scan the product QR code or barcode before putting it in the trolley.');
                          if (value == null) return;
                          _product.text = value;
                          final ok = await shop.addProduct(value);
                          if (ok) _product.clear();
                        },
                        onAdd: () async {
                          final code = _product.text.trim();
                          if (code.isEmpty) return;
                          final ok = await shop.addProduct(code);
                          if (ok) _product.clear();
                        },
                      ),
                    const SizedBox(height: 14),
                    _CartCard(shop: shop),
                    const SizedBox(height: 14),
                    if (shop.cartEditable && shop.data.cart.isNotEmpty)
                      _CheckoutCard(
                        selected: _paymentMethod,
                        total: shop.data.total,
                        busy: shop.loading,
                        onSelected: (value) => setState(() => _paymentMethod = value),
                        onCheckout: () => shop.checkout(_paymentMethod),
                      ),
                    if (shop.data.order != null) ...[
                      const SizedBox(height: 14),
                      _OrderCard(shop: shop),
                    ],
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: shop.hasSession
              ? SafeArea(
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    child: Row(
                      children: [
                        Expanded(child: Text('${shop.itemCount} item${shop.itemCount == 1 ? '' : 's'}', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700))),
                        Text('₹${shop.data.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.controller, required this.busy, required this.onScan, required this.onClaim});
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
          Container(width: 52, height: 52, decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppTheme.green)),
          const SizedBox(height: 18),
          const Text('Start shopping', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('No login needed. Scan the QR fixed on your trolley and start adding products.', style: TextStyle(color: AppTheme.muted, height: 1.45)),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: busy ? null : onScan, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan Trolley QR')),
          const SizedBox(height: 12),
          TextField(controller: controller, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Or enter trolley code', hintText: 'SM-TROLLEY-01')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: busy ? null : onClaim, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Use trolley code')),
        ]),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.shop});
  final ShopController shop;
  @override
  Widget build(BuildContext context) {
    final s = shop.data.session!;
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.shopping_cart_rounded)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Active trolley', style: TextStyle(fontSize: 12, color: AppTheme.muted)), const SizedBox(height: 3), Text(s.trolleyId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))])),
      StatusChip(s.status),
    ])));
  }
}

class _ScanProductCard extends StatelessWidget {
  const _ScanProductCard({required this.controller, required this.busy, required this.onScan, required this.onAdd});
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Add products', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Scan every product before placing it in the trolley.', style: TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: busy ? null : onScan, icon: const Icon(Icons.document_scanner_rounded), label: const Text('Scan Product')),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'SM-PRD001 / barcode'))), const SizedBox(width: 10), SizedBox(height: 54, child: FilledButton(onPressed: busy ? null : onAdd, child: const Icon(Icons.add_rounded)))])
    ])));
  }
}

class _CartCard extends StatelessWidget {
  const _CartCard({required this.shop});
  final ShopController shop;
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Your cart', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), Text('${shop.itemCount} items', style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 8),
      if (shop.data.cart.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Column(children: [Icon(Icons.shopping_basket_outlined, size: 40, color: AppTheme.muted), SizedBox(height: 8), Text('Your cart is empty', style: TextStyle(color: AppTheme.muted))])))
      else
        ...shop.data.cart.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.inventory_2_outlined)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)), if (item.pack.isNotEmpty) Text(item.pack, style: const TextStyle(fontSize: 12, color: AppTheme.muted)), Text('₹${item.unitPrice.toStringAsFixed(2)} each', style: const TextStyle(fontSize: 12, color: AppTheme.muted))])),
          if (shop.cartEditable) Row(children: [
            IconButton.filledTonal(onPressed: shop.loading ? null : () => shop.changeQty(item.cartItemId, item.qty - 1), icon: const Icon(Icons.remove_rounded, size: 18)),
            SizedBox(width: 28, child: Text('${item.qty}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
            IconButton.filledTonal(onPressed: shop.loading ? null : () => shop.changeQty(item.cartItemId, item.qty + 1), icon: const Icon(Icons.add_rounded, size: 18)),
          ]) else Text('×${item.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text('₹${item.lineTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
        ]))),
      if (shop.data.cart.isNotEmpty) ...[const Divider(height: 22), Row(children: [const Expanded(child: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))), Text('₹${shop.data.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))])]
    ])));
  }
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({required this.selected, required this.total, required this.busy, required this.onSelected, required this.onCheckout});
  final String selected;
  final double total;
  final bool busy;
  final ValueChanged<String> onSelected;
  final VoidCallback onCheckout;
  @override
  Widget build(BuildContext context) {
    const methods = [('CASH', Icons.payments_outlined, 'Cash'), ('UPI', Icons.phone_android_rounded, 'UPI'), ('QR', Icons.qr_code_2_rounded, 'QR')];
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Checkout', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5), const Text('Select how you want to pay.', style: TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 14),
      Row(children: methods.map((m) => Expanded(child: Padding(padding: EdgeInsets.only(right: m.$1 == 'QR' ? 0 : 8), child: ChoiceChip(selected: selected == m.$1, onSelected: (_) => onSelected(m.$1), avatar: Icon(m.$2, size: 18), label: SizedBox(width: double.infinity, child: Text(m.$3, textAlign: TextAlign.center)))))).toList()),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : onCheckout, child: Text('Proceed to Pay • ₹${total.toStringAsFixed(2)}')),
    ])));
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.shop});
  final ShopController shop;
  @override
  Widget build(BuildContext context) {
    final o = shop.data.order!;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.verified_rounded, color: AppTheme.green, size: 40), const SizedBox(height: 10),
      const Text('Checkout submitted', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 6),
      const Text('Keep this screen open and proceed to the counter / dispatch gate.', style: TextStyle(color: AppTheme.muted, height: 1.4)),
      const SizedBox(height: 16),
      _InfoRow(label: 'Order', value: o.orderId), _InfoRow(label: 'Payment', value: o.paymentMethod), _InfoRow(label: 'Amount', value: '₹${o.total.toStringAsFixed(2)}'),
      const SizedBox(height: 12), Row(children: [StatusChip(o.paymentStatus), const SizedBox(width: 8), StatusChip(o.orderStatus)]),
    ])));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.muted))), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)))]));
}
