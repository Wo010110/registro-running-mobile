import 'package:flutter/material.dart';

/// Paleta única de la app.
///
/// Cada color tiene nombre por su función, no por su tono, y existe en dos
/// versiones: [AppColors.oscuro] y [AppColors.claro]. Las pantallas piden la
/// del tema activo con `AppColors.of(context)`. Regla del proyecto: fuera de
/// `lib/theme/` no se escribe ningún hex ni `Colors.xxx` (lo vigila
/// `test/colores_test.dart`).
@immutable
class AppColors {
  const AppColors._({
    required this.fondo,
    required this.superficie,
    required this.borde,
    required this.divisor,
    required this.textoPrincipal,
    required this.textoSecundario,
    required this.textoTenue,
    required this.textoDeshabilitado,
    required this.primario,
    required this.accion,
    required this.sobreAccion,
    required this.exito,
    required this.error,
    required this.errorTexto,
  });

  /// Paleta del tema activo.
  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oscuro : claro;

  /// Pantallas.
  final Color fondo;

  /// Tarjetas, campos y hojas sobre [fondo].
  final Color superficie;

  /// Contorno de tarjetas y campos.
  final Color borde;

  /// Línea entre filas de una lista.
  final Color divisor;

  final Color textoPrincipal;
  final Color textoSecundario;
  final Color textoTenue;
  final Color textoDeshabilitado;

  /// Color primario del tema: foco de campos, indicadores.
  final Color primario;

  /// Fondo de los botones de acción.
  final Color accion;

  /// Texto e íconos sobre [accion].
  final Color sobreAccion;

  final Color exito;

  /// Relleno y bordes de error.
  final Color error;

  /// Texto de mensajes de error.
  final Color errorTexto;

  static const oscuro = AppColors._(
    fondo: Color(0xFF0B0F14),
    superficie: Color(0xFF151B23),
    borde: Color(0xFF2A333F),
    divisor: Color(0xFF1E2630),
    textoPrincipal: Color(0xFFF5F7FA),
    textoSecundario: Color(0xFFB4BDC9),
    textoTenue: Color(0xFF8893A1),
    textoDeshabilitado: Color(0xFF55606E),
    primario: Color(0xFF2F6BFF),
    accion: Color(0xFF2F6BFF),
    sobreAccion: Color(0xFFFFFFFF),
    exito: Color(0xFF34C77B),
    error: Color(0xFFE5484D),
    errorTexto: Color(0xFFFF8A8E),
  );

  static const claro = AppColors._(
    fondo: Color(0xFFF5F5F7),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFD9DDE3),
    divisor: Color(0xFFE6E8EC),
    textoPrincipal: Color(0xFF0B0F14),
    textoSecundario: Color(0xFF47515E),
    textoTenue: Color(0xFF6B7584),
    textoDeshabilitado: Color(0xFFA3ABB7),
    primario: Color(0xFF2F6BFF),
    accion: Color(0xFF2F6BFF),
    sobreAccion: Color(0xFFFFFFFF),
    exito: Color(0xFF1F9D5C),
    error: Color(0xFFD92D33),
    errorTexto: Color(0xFFB4232A),
  );
}
