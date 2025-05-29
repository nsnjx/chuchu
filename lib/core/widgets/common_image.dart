import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CommonImage extends StatelessWidget {
  final String iconName;
  final Color? color;
  final double? height;
  final double? width;
  final BoxFit? fit;

  const CommonImage({
    super.key,
    required this.iconName,
    this.color,
    double? height,
    double? width,
    double? size,
    this.fit,
  }) : height = size ?? height,
       width = size ?? width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/$iconName',
      width: width,
      height: height,
      color: color,
      fit: fit,
    );
  }
}

class CommonIconButton extends StatelessWidget {
  const CommonIconButton({
    super.key,
    required this.iconName,
    this.useTheme = false,
    this.color,
    double? height,
    double? width,
    double? size,
    this.fit,
    this.padding,
    required this.onPressed,
  }) : height = size ?? height,
       width = size ?? width;

  final String iconName;

  final bool useTheme;
  final Color? color;
  final double? height;
  final double? width;
  final BoxFit? fit;

  final EdgeInsetsGeometry? padding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: CommonImage(
          iconName: iconName,
          height: height,
          width: width,
          color: color,
        ),
      ),
    );
  }
}
