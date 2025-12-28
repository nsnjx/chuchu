import 'package:flutter/material.dart';

/// 🎨 Brand colors
const Color kPrimary = Color(0xFFF6339A); // Main brand color
const Color kSecondary = Color(0xFFE12AFB); // Secondary brand color
const Color kTertiary = Color(0xFF9810FA); // Tertiary brand color
const Color kYellow = Color(0xFFFFB900); // Yellow accent color
const Color kBlue = Color(0xFF006C9E); // Blue color
const Color kGreen = Color(0xFF009966); // Green color
const Color kBgWhite = Color(0xFFFFFFFF);
const Color kBgLight = Color(0xFFF8FAFC); // Light background color
const Color kTitleColor = Color(0xFF0F172B); // Light background color

/// 🌈 Gradient colors
const List<Color> kGradientColors = [
  Color(0xFFF6339A), // Pink
  Color(0xFFE12AFB), // Magenta
  Color(0xFF9810FA), // Purple
];

/// Helper function to create gradient
LinearGradient getBrandGradient({
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) {
  return LinearGradient(
    begin: begin,
    end: end,
    colors: kGradientColors,
  );
}

/// Horizontal gradient (left to right)
LinearGradient getBrandGradientHorizontal() {
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: kGradientColors,
  );
}

/// Diagonal gradient (bottom-left to top-right)
LinearGradient getBrandGradientDiagonal() {
  return LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: kGradientColors,
  );
}

/// ✏️ Text colors
const Color kTextPrimary = Color(0xFF45556C); // Main text (black-ish)
const Color kTextSecondary = Color(0xFF62748E); // Secondary text (gray)
const Color kTextTertiary = Color(0xFF90A1B9); // Tertiary text (light gray)

const Color kIconState = Color(0xFF8A96A3); // Icon default state color
 
const Color KBorderColor = Color(0xFFF0F0F0); //

/// 🎨 Additional colors
const Color kBgDark = Color(0xFF2C2C2C); // Dark background color (for private key display)
const Color kWarningBg = Color(0xFFFFFBEB); // Warning background color
const Color kWarningBorder = Color(0xFFFEF3C6); // Warning border color
const Color kWarningIcon = Color(0xFFFF9800); // Warning icon color
const Color kWarningText = Color(0xFF973C00); // Warning text color

final ColorScheme lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: kPrimary,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFFFE5F5), // Light pink tint
  onPrimaryContainer: Color(0xFF4A0026), // Dark pink for contrast

  secondary: kSecondary,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFFE5FC), // Light magenta tint
  onSecondaryContainer: Color(0xFF4A0033), // Dark magenta for contrast

  tertiary: kTertiary,
  onTertiary: Colors.white,

  error: Color(0xFFBA1A1A),
  onError: Colors.white,

  background: kBgWhite,
  onBackground: kTextPrimary,

  surface: Colors.white,
  onSurface: kTextPrimary,
  surfaceVariant: Color(0xFFF4F4F4),
  onSurfaceVariant: kTextSecondary,

  outline: kTextTertiary,
);

/// 📱 ThemeData
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lightScheme,
  fontFamily: 'Inter',
  textTheme: TextTheme(
    displayLarge: TextStyle(color: kTextPrimary),
    displayMedium: TextStyle(color: kTextPrimary),
    displaySmall: TextStyle(color: kTextPrimary),
    headlineLarge: TextStyle(color: kTextPrimary),
    headlineMedium: TextStyle(color: kTextPrimary),
    headlineSmall: TextStyle(color: kTextPrimary),
    titleLarge: TextStyle(color: kTextPrimary),
    titleMedium: TextStyle(color: kTextPrimary),
    titleSmall: TextStyle(color: kTextPrimary),
    bodyLarge: TextStyle(color: kTextSecondary),
    bodyMedium: TextStyle(color: kTextSecondary),
    bodySmall: TextStyle(color: kTextTertiary),
    labelLarge: TextStyle(color: kTextSecondary),
    labelMedium: TextStyle(color: kTextTertiary),
    labelSmall: TextStyle(color: kTextTertiary),
  ),
  scaffoldBackgroundColor: kBgWhite,
  appBarTheme: const AppBarTheme(
    backgroundColor: kBgWhite,
    foregroundColor: kPrimary,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
);
