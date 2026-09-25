import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// The app is black-first, like Karakeep's dark UI. A light theme can be
  /// added later from the same tokens.
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.primary,
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      onSurfaceVariant: AppColors.mutedForeground,
      surfaceContainer: AppColors.card,
      surfaceContainerHigh: AppColors.popover,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.destructive,
      onError: AppColors.foreground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionHandleColor: AppColors.primary,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 14),
        hintStyle: TextStyle(color: AppColors.muted),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.foreground,
      ),
      // Material's default snackbar is a light slab on dark themes, and its
      // action text was unreadable. Keep it black like the app, outlined so
      // it stands out from the black page, with a blue Undo.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: const TextStyle(
          color: AppColors.foreground,
          fontSize: 15,
        ),
        actionTextColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.input),
        ),
      ),
    );
  }
}
