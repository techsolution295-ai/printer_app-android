import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pro screen colors, matched to the printer app home bar and text.
class AppTheme {
  static const String? fontFamily = null;

  static const Color primaryColor = Color(0xFF6FA8FF);
  static const Color secondaryColor = Color(0xFF4D6FA6);
  /// Buttons, links, and the selected tab. Same blue family as the home header.
  static const Color actionColor = Color(0xFF4B7FDB);
  static const Color accentColor = Color(0xFFF4A640);

  static const Color textDark = Color(0xFF2B3A55);
  static const Color textLight = Color(0xFF6B7A96);
  static const Color mutedColor = Color(0xFF8A9BB5);
  static const Color borderColor = Color(0xFFE3EAF4);
  static const Color pageBackground = Color(0xFFF4F7FB);
  static const Color tintColor = Color(0xFFEAF2FF);

  static const LinearGradient gradientBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );

  /// Dark clock, battery, and signal icons on light screens.
  static const SystemUiOverlayStyle lightScreenOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  /// White clock, battery, and signal icons on the blue headers.
  static const SystemUiOverlayStyle darkHeaderOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
