import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF),
        brightness: Brightness.light,
      ).copyWith(
        surface: const Color(0xCCF2F2F2), // Background for dialogs/modals
        onSurface: Colors.black, // Text color
        surfaceContainerHighest: Colors.black12, // Divider/Border color
        error: const Color(0xFFFF3B30),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xCCF2F2F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black),
      ),
      extensions: <ThemeExtension<dynamic>>[
        LauncherThemeExtension(
          dialogBgColor: const Color(0xCCF2F2F2),
          menuBgColor: const Color(0xCCF9F9F9),
          sheetBgColor: const Color(0xFFF2F2F2).withOpacity(0.85),
          panelBgColor: Colors.black.withOpacity(0.05),
          borderColor: Colors.black.withOpacity(0.08),
          dividerColor: Colors.black.withOpacity(0.15),
          textColor: Colors.black,
          subTextColor: Colors.black.withOpacity(0.7),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF),
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xCC1E1E1E),
        onSurface: Colors.white,
        surfaceContainerHighest: Colors.white24,
        error: const Color(0xFFFF3B30),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xCC1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
      extensions: <ThemeExtension<dynamic>>[
        LauncherThemeExtension(
          dialogBgColor: const Color(0xCC1E1E1E),
          menuBgColor: const Color(0xCC252525),
          sheetBgColor: const Color(0xFF1E1E1E).withOpacity(0.85),
          panelBgColor: Colors.white.withOpacity(0.1),
          borderColor: Colors.white.withOpacity(0.08),
          dividerColor: Colors.white.withOpacity(0.15),
          textColor: Colors.white,
          subTextColor: Colors.white.withOpacity(0.7),
        ),
      ],
    );
  }
}

class LauncherThemeExtension extends ThemeExtension<LauncherThemeExtension> {
  final Color dialogBgColor;
  final Color menuBgColor;
  final Color sheetBgColor;
  final Color panelBgColor;
  final Color borderColor;
  final Color dividerColor;
  final Color textColor;
  final Color subTextColor;

  const LauncherThemeExtension({
    required this.dialogBgColor,
    required this.menuBgColor,
    required this.sheetBgColor,
    required this.panelBgColor,
    required this.borderColor,
    required this.dividerColor,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  ThemeExtension<LauncherThemeExtension> copyWith({
    Color? dialogBgColor,
    Color? menuBgColor,
    Color? sheetBgColor,
    Color? panelBgColor,
    Color? borderColor,
    Color? dividerColor,
    Color? textColor,
    Color? subTextColor,
  }) {
    return LauncherThemeExtension(
      dialogBgColor: dialogBgColor ?? this.dialogBgColor,
      menuBgColor: menuBgColor ?? this.menuBgColor,
      sheetBgColor: sheetBgColor ?? this.sheetBgColor,
      panelBgColor: panelBgColor ?? this.panelBgColor,
      borderColor: borderColor ?? this.borderColor,
      dividerColor: dividerColor ?? this.dividerColor,
      textColor: textColor ?? this.textColor,
      subTextColor: subTextColor ?? this.subTextColor,
    );
  }

  @override
  ThemeExtension<LauncherThemeExtension> lerp(
      ThemeExtension<LauncherThemeExtension>? other, double t) {
    if (other is! LauncherThemeExtension) {
      return this;
    }
    return LauncherThemeExtension(
      dialogBgColor: Color.lerp(dialogBgColor, other.dialogBgColor, t)!,
      menuBgColor: Color.lerp(menuBgColor, other.menuBgColor, t)!,
      sheetBgColor: Color.lerp(sheetBgColor, other.sheetBgColor, t)!,
      panelBgColor: Color.lerp(panelBgColor, other.panelBgColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      subTextColor: Color.lerp(subTextColor, other.subTextColor, t)!,
    );
  }
}
