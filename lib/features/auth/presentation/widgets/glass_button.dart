import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum GlassButtonVariant { primary, secondary, google }

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = GlassButtonVariant.primary,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final bool isLoading;
  final Widget? icon;
  final GlassButtonVariant variant;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleForVariant(widget.variant);

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: RepaintBoundary(
        child: GestureDetector(
          onTapDown: _isEnabled ? (_) => _setPressed(true) : null,
          onTapUp: _isEnabled ? (_) => _setPressed(false) : null,
          onTapCancel: _isEnabled ? () => _setPressed(false) : null,
          onTap: _isEnabled
              ? () async {
                  await widget.onPressed!.call();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInOut,
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: style.backgroundColor,
              border: Border.all(color: style.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: _isPressed
                      ? (style.elevation + 1.5)
                      : style.elevation,
                  offset: Offset(0, _isPressed ? 1.5 : 2),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: widget.isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            style.foregroundColor,
                          ),
                        ),
                      )
                    : Row(
                        key: ValueKey(widget.label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            widget.icon!,
                            const SizedBox(width: 10),
                          ] else if (widget.variant ==
                              GlassButtonVariant.google) ...[
                            const _GoogleBadge(),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: style.foregroundColor.withValues(
                                    alpha: _isEnabled ? 1 : 0.55,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonStyleData {
  const _ButtonStyleData({
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.elevation,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final double elevation;
}

_ButtonStyleData _styleForVariant(GlassButtonVariant variant) {
  switch (variant) {
    case GlassButtonVariant.primary:
      return const _ButtonStyleData(
        backgroundColor: AppColors.accentPrimary,
        borderColor: AppColors.accentPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 3,
      );
    case GlassButtonVariant.secondary:
      return const _ButtonStyleData(
        backgroundColor: AppColors.backgroundSecondary,
        borderColor: AppColors.cardBorder,
        foregroundColor: AppColors.textPrimary,
        elevation: 2.5,
      );
    case GlassButtonVariant.google:
      return const _ButtonStyleData(
        backgroundColor: AppColors.cardBackground,
        borderColor: AppColors.cardBorder,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
      );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}
