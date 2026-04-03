import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 8,
    this.gradient,
    this.borderColor,
    this.boxShadow = const [
      BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 2)),
    ],
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Gradient? gradient;
  final Color? borderColor;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = blurSigma.clamp(0.0, 8.0);
    final effectiveBorder =
        borderColor ?? AppColors.accent.withValues(alpha: 0.25);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: effectiveBorder, width: 1.0),
                gradient:
                    gradient ??
                    LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
