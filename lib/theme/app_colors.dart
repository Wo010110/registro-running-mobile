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
    required this.sombra,
    required this.divisor,
    required this.textoPrincipal,
    required this.textoSecundario,
    required this.textoTenue,
    required this.textoDeshabilitado,
    required this.primario,
    required this.primarioSuave,
    required this.medalla,
    required this.accion,
    required this.sobreAccion,
    required this.exito,
    required this.advertencia,
    required this.intensidadSuave,
    required this.intensidadDura,
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

  /// Sombra de lo que flota sobre el mapa (contenedores, botones, títulos).
  final Color sombra;

  /// Línea entre filas de una lista.
  final Color divisor;

  final Color textoPrincipal;
  final Color textoSecundario;
  final Color textoTenue;
  final Color textoDeshabilitado;

  /// Color primario del tema: foco de campos, indicadores.
  final Color primario;

  /// Tinte translúcido del primario: fichas, íconos en círculo, barras vacías.
  final Color primarioSuave;

  /// Dorado de medallas y récords.
  final Color medalla;

  /// Fondo de los botones de acción.
  final Color accion;

  /// Texto e íconos sobre [accion].
  final Color sobreAccion;

  final Color exito;

  /// Señal o estado intermedio (amarillo).
  final Color advertencia;

  /// Verde amarillento y naranja: los niveles intermedios de intensidad,
  /// entre [exito], [advertencia] y [error].
  final Color intensidadSuave;
  final Color intensidadDura;

  /// Relleno y bordes de error.
  final Color error;

  /// Texto de mensajes de error.
  final Color errorTexto;

  static const oscuro = AppColors._(
    fondo: Color(0xFF0B0F14),
    superficie: Color(0xFF151B23),
    borde: Color(0xFF2A333F),
    sombra: Color(0x66000000),
    divisor: Color(0xFF1E2630),
    textoPrincipal: Color(0xFFF5F7FA),
    textoSecundario: Color(0xFFB4BDC9),
    textoTenue: Color(0xFF8893A1),
    textoDeshabilitado: Color(0xFF55606E),
    primario: Color(0xFF2F6BFF),
    primarioSuave: Color(0x262F6BFF),
    medalla: Color(0xFFF5B83D),
    accion: Color(0xFF2F6BFF),
    sobreAccion: Color(0xFFFFFFFF),
    exito: Color(0xFF34C77B),
    advertencia: Color(0xFFF5C542),
    intensidadSuave: Color(0xFF9BCB3C),
    intensidadDura: Color(0xFFF08A3C),
    error: Color(0xFFE5484D),
    errorTexto: Color(0xFFFF8A8E),
  );

  static const claro = AppColors._(
    fondo: Color(0xFFF5F5F7),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFD9DDE3),
    sombra: Color(0x33000000),
    divisor: Color(0xFFE6E8EC),
    textoPrincipal: Color(0xFF0B0F14),
    textoSecundario: Color(0xFF47515E),
    textoTenue: Color(0xFF6B7584),
    textoDeshabilitado: Color(0xFFA3ABB7),
    primario: Color(0xFF2F6BFF),
    primarioSuave: Color(0x1A2F6BFF),
    medalla: Color(0xFFD99A12),
    accion: Color(0xFF2F6BFF),
    sobreAccion: Color(0xFFFFFFFF),
    exito: Color(0xFF1F9D5C),
    advertencia: Color(0xFFE0A100),
    intensidadSuave: Color(0xFF6FA81E),
    intensidadDura: Color(0xFFE06A12),
    error: Color(0xFFD92D33),
    errorTexto: Color(0xFFB4232A),
  );
}
