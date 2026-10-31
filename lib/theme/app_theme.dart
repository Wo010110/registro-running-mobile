import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema de Material construido solo con [AppColors].
ThemeData construirTema(AppColors c, Brightness brillo) {
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c.borde),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    scaffoldBackgroundColor: c.fondo,
    fontFamily: 'Barlow',
    // Barlow en Medium es el mínimo: letra firme, sin pesos finos.
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w800),
      displayMedium: TextStyle(fontWeight: FontWeight.w800),
      displaySmall: TextStyle(fontWeight: FontWeight.w800),
      headlineLarge: TextStyle(fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      titleSmall: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontWeight: FontWeight.w600),
      bodySmall: TextStyle(fontWeight: FontWeight.w500),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontWeight: FontWeight.w700),
      labelSmall: TextStyle(fontWeight: FontWeight.w600),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: c.borde),
      ),
    ),
    colorScheme: ColorScheme(
      brightness: brillo,
      primary: c.primario,
      onPrimary: c.sobreAccion,
      secondary: c.accion,
      onSecondary: c.sobreAccion,
      error: c.error,
      onError: c.sobreAccion,
      surface: c.superficie,
      onSurface: c.textoPrincipal,
    ),
    dividerColor: c.divisor,
    appBarTheme: AppBarTheme(
      backgroundColor: c.fondo,
      foregroundColor: c.textoPrincipal,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: BorderSide(color: c.primario, width: 2),
      ),
      errorBorder: borde.copyWith(borderSide: BorderSide(color: c.error)),
      focusedErrorBorder: borde.copyWith(
        borderSide: BorderSide(color: c.error, width: 2),
      ),
      labelStyle: TextStyle(color: c.textoTenue),
      errorStyle: TextStyle(color: c.errorTexto),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accion,
        foregroundColor: c.sobreAccion,
        disabledBackgroundColor: c.borde,
        disabledForegroundColor: c.textoDeshabilitado,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textoPrincipal,
        side: BorderSide(color: c.borde),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primario),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primario),
  );
}
