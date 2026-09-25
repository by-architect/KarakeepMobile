import 'package:material_ui/material_ui.dart';

/// Design tokens, taken from the official Karakeep mobile app's dark palette
/// (`apps/mobile/globals.css`) so the app feels at home next to it.
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const foreground = Color(0xFFFFFFFF);
  static const card = Color(0xFF151518);
  static const popover = Color(0xFF282828);
  static const primary = Color(0xFF0385FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const muted = Color(0xFF707073);
  static const mutedForeground = Color(0xFFA1A1A6);
  static const border = Color(0xFF282828);
  static const input = Color(0xFF333333);
  static const destructive = Color(0xFFFE4336);
  static const success = Color(0xFF30D158);
}

abstract final class AppRadii {
  static const card = 12.0;
  static const button = 12.0;
  static const pill = 9.0;
}
