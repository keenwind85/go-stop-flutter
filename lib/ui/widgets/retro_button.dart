import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// 3D Arcade Style Button
///
/// Features:
/// - Thick bottom border for 3D depth
/// - Press animation (translates down, reduces depth)
/// - High contrast retro colors
class RetroButton extends StatefulWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final Color color;
  final Color? textColor;
  final double? width;
  final double height;
  final double fontSize;
  final bool isEnabled;
  final EdgeInsetsGeometry padding;

  const RetroButton({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.color = AppColors.goRed,
    this.textColor,
    this.width,
    this.height = 50,
    this.fontSize = 20,
    this.isEnabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  }) : assert(text != null || child != null, 'Either text or child must be provided');

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Disabled state color
    final effectiveColor = widget.isEnabled
        ? widget.color
        : Colors.grey.shade400;

    // Calculate shadow/border colors for 3D effect
    final shadowColor = HSLColor.fromColor(effectiveColor)
        .withLightness((HSLColor.fromColor(effectiveColor).lightness - 0.2).clamp(0.0, 1.0))
        .toColor();

    final highlightColor = HSLColor.fromColor(effectiveColor)
        .withLightness((HSLColor.fromColor(effectiveColor).lightness + 0.1).clamp(0.0, 1.0))
        .toColor();

    // Press offset
    final double pressOffset = _isPressed ? 4.0 : 0.0;
    final double shadowHeight = _isPressed ? 0.0 : 4.0;

    // Use LayoutBuilder to handle unbounded constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        // If width is null and constraints are bounded, use constraint width
        // If width is null and constraints are unbounded, wrap content
        final double? effectiveWidth = widget.width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);

        Widget buttonContent = AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: effectiveWidth,
          height: widget.height,
          margin: EdgeInsets.only(top: pressOffset),
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlightColor,
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                highlightColor,
                effectiveColor,
              ],
            ),
            boxShadow: [
              // Bottom shadow for 3D effect
              BoxShadow(
                color: shadowColor,
                offset: Offset(0, shadowHeight),
                blurRadius: 0,
                spreadRadius: 0,
              ),
              // Outer shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: Offset(0, shadowHeight + 2),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: widget.padding,
              child: widget.child ?? Text(
                widget.text!,
                style: TextStyle(
                  color: widget.textColor ?? Colors.white,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return GestureDetector(
          onTapDown: widget.isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.isEnabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: widget.isEnabled ? () => setState(() => _isPressed = false) : null,
          onTap: widget.isEnabled ? widget.onPressed : null,
          child: buttonContent,
        );
      },
    );
  }
}
