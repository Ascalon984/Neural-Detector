import 'package:flutter/material.dart';
import 'glass_card.dart';

class EnhancedGlassCard extends StatelessWidget {
  final Widget? child;
  final double? height;
  final VoidCallback? onTap;

  const EnhancedGlassCard({Key? key, this.child, this.height, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: height,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
