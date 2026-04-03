import 'package:flutter/material.dart';

import '../../../../shared/components/glass_card.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GlassCard(
        padding: padding,
        borderRadius: BorderRadius.circular(26),
        blurSigma: 6,
        child: child,
      ),
    );
  }
}
