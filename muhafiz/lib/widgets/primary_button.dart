import 'package:flutter/material.dart';
import 'package:muhafiz/core/constants.dart';

/// Main call-to-action button for Muhafiz.
///
/// Supports loading, disabled state, optional icon, and full-width layout.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final bool fullWidth;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledColor;
  final TextStyle? textStyle;

  const PrimaryButton({
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
    this.backgroundColor,
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
    final effectiveBackground = backgroundColor ?? AppColors.primary;
    final effectiveForeground = foregroundColor ?? AppColors.white;
    final effectiveDisabledColor = disabledColor ?? const Color(0xFFBDBDBD);
    final effectiveTextStyle = textStyle ??
        const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );

    final buttonChild = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
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
              Text(text),
            ],
          );

    final button = ElevatedButton(
      onPressed: effectiveDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveBackground,
        foregroundColor: effectiveForeground,
        disabledBackgroundColor: effectiveDisabledColor,
        disabledForegroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: effectivePadding,
        textStyle: effectiveTextStyle,
        elevation: 0,
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
