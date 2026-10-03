import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/app_icon.png'),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Smark Mart', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink)),
              SizedBox(height: 2),
              Text('Scan • Shop • Pay • Go', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
