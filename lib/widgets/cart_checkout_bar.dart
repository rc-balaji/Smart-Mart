import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class CartCheckoutBar extends StatelessWidget {
  const CartCheckoutBar({
    super.key,
    required this.itemCount,
    required this.totalLabel,
    required this.showCheckout,
    required this.continuePayment,
    required this.busy,
    required this.onCheckout,
  });

  final int itemCount;
  final String totalLabel;
  final bool showCheckout;
  final bool continuePayment;
  final bool busy;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  totalLabel,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 19 : 21,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          );

          final checkoutButton = showCheckout
              ? SizedBox(
                  width: compact ? double.infinity : null,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onCheckout,
                    icon: Icon(
                      continuePayment
                          ? Icons.payment_rounded
                          : Icons.fact_check_rounded,
                    ),
                    label: Text(
                      continuePayment ? 'Continue payment' : 'Confirm cart',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : const SizedBox.shrink();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 18,
              compact ? 12 : 10,
              compact ? 16 : 18,
              12,
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      if (showCheckout) ...[
                        const SizedBox(height: 10),
                        checkoutButton,
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: summary),
                      if (showCheckout) checkoutButton,
                    ],
                  ),
          );
        },
      );
}
