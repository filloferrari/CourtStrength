import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  AppColors._();
  static const Color background = Color(0xFF0D0D0D);
  static const Color card = Color(0xFF1F1F1F);
  static const Color cardHigh = Color(0xFF2A2A2A);
  static const Color outline = Color(0xFF333333);
  static const Color lime = Color(0xFFCCFF33);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF999999);
  static const Color blue = Color(0xFF4DA3FF);
  static const Color orange = Color(0xFFFF9F43);
  static const Color danger = Color(0xFFFF5252);
}

const List<Color> kBlockPalette = [AppColors.lime, AppColors.blue, AppColors.orange];

/// Assegna un colore a ogni blocco con almeno due esercizi (veri superset),
/// nell'ordine di prima apparizione.
Map<String, Color> blockColors(Iterable<String?> blockIds) {
  final order = <String>[];
  final counts = <String, int>{};
  for (final id in blockIds) {
    if (id == null) continue;
    if (!counts.containsKey(id)) order.add(id);
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final result = <String, Color>{};
  var i = 0;
  for (final id in order) {
    if ((counts[id] ?? 0) > 1) {
      result[id] = kBlockPalette[i % kBlockPalette.length];
      i++;
    }
  }
  return result;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.dark(
    primary: AppColors.lime,
    onPrimary: Colors.black,
    secondary: AppColors.blue,
    onSecondary: Colors.black,
    tertiary: AppColors.orange,
    surface: AppColors.card,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: Colors.black,
        disabledBackgroundColor: AppColors.cardHigh,
        disabledForegroundColor: AppColors.textSecondary,
        minimumSize: const Size(64, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF444444)),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.lime,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardHigh,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      helperStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.cardHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cardHigh,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.lime,
      foregroundColor: Colors.black,
      extendedTextStyle:
          const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerColor: AppColors.outline,
  );
}
