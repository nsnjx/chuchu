import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum GradientButtonStyle {
  horizontal,
  vertical,
  diagonal,
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final double borderRadius;
  final EdgeInsets padding;
  final double fontSize;
  final FontWeight fontWeight;
  final GradientButtonStyle gradientStyle;
  final Widget? icon;
  final Widget? trailingIcon;
  final double? width;
  final double? height;

  const GradientButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.gradientStyle = GradientButtonStyle.horizontal,
    this.icon,
    this.trailingIcon,
    this.width,
    this.height,
  });

  bool get _isEnabled => !isDisabled && !isLoading && onTap != null;

  Gradient _getGradient() {
    switch (gradientStyle) {
      case GradientButtonStyle.horizontal:
        return getBrandGradientHorizontal();
      case GradientButtonStyle.vertical:
        return getBrandGradient();
      case GradientButtonStyle.diagonal:
        return getBrandGradientDiagonal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool hasFixedSize = width != null || height != null;

    Widget content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isEnabled ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          )
        : _buildContent(theme, hasFixedSize);

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              gradient: _isEnabled ? _getGradient() : null,
              color: _isEnabled ? null : theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: _isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: padding,
            alignment: hasFixedSize ? Alignment.center : null,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool hasFixedSize) {
    final textWidget = Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: _isEnabled ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5),
      ),
    );

    if (icon != null || trailingIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 8),
          ],
          textWidget,
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            trailingIcon!,
          ],
        ],
      );
    }

    // Only use Center when fixed size is specified, otherwise let content determine size
    return hasFixedSize ? Center(child: textWidget) : textWidget;
  }
}

