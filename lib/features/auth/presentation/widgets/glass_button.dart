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
              borderRadius: BorderRadius.circular(16),
              color: style.backgroundColor,
              border: Border.all(color: style.borderColor, width: 1.2),
              boxShadow: widget.variant == GlassButtonVariant.primary
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.10),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
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
  const darkGlass = Color(0xE51A1D22);
  switch (variant) {
    case GlassButtonVariant.primary:
      return _ButtonStyleData(
        backgroundColor: darkGlass,
        borderColor: AppColors.accent.withValues(alpha: 0.45),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      );
    case GlassButtonVariant.secondary:
      return _ButtonStyleData(
        backgroundColor: darkGlass,
        borderColor: AppColors.glassBorder,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      );
    case GlassButtonVariant.google:
      return _ButtonStyleData(
        backgroundColor: darkGlass,
        borderColor: AppColors.glassBorder,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
        color: AppColors.glassFill,
        border: Border.all(color: AppColors.glassBorder),
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
