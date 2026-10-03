import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'ACTIVE' => const Color(0xFF157F3D),
      'PAID' || 'READY_FOR_DISPATCH' => const Color(0xFF175CD3),
      'PAYMENT_PENDING' || 'PENDING' => const Color(0xFFB54708),
      'COMPLETED' => const Color(0xFF157F3D),
      _ => const Color(0xFF475467),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
      child: Text(normalized.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}
