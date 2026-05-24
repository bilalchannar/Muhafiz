import 'package:flutter/material.dart';
import 'package:muhafiz/core/constants.dart';

/// Secondary call-to-action button for Muhafiz.
///
/// Supports loading, disabled state, optional icon, and full-width layout.
class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final bool fullWidth;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? foregroundColor;
  final Color? disabledColor;
  final TextStyle? textStyle;

  const OutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.fullWidth = true,
    this.height,
    this.borderRadius = 14,
    this.padding,
    this.borderColor,
    this.foregroundColor,
    this.disabledColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = isDisabled || isLoading || onPressed == null;
    final effectiveHeight = height ?? 52;
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 20);
    final effectiveBorderColor =
        borderColor ?? (effectiveDisabled ? const Color(0xFFBDBDBD) : AppColors.primary);
    final effectiveForeground =
        foregroundColor ?? (effectiveDisabled ? const Color(0xFFBDBDBD) : AppColors.primary);
    final effectiveTextStyle = textStyle ??
        const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );

    final buttonChild = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveForeground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = OutlinedButton(
      onPressed: effectiveDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: effectiveForeground,
        side: BorderSide(color: effectiveBorderColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: effectivePadding,
        textStyle: effectiveTextStyle,
      ),
      child: buttonChild,
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        height: effectiveHeight,
        child: button,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: effectiveHeight),
      child: button,
    );
  }
}
