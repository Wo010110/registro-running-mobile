import 'package:intl/intl.dart';

String _dos(int n) => n.toString().padLeft(2, '0');

/// hh:mm:ss
String formatearTiempo(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  return '${_dos(s ~/ 3600)}:${_dos(s ~/ 60 % 60)}:${_dos(s % 60)}';
}

/// Metros a km con dos decimales y coma ("5,01").
String formatearKm(double metros) =>
    NumberFormat('0.00', 'es').format(metros / 1000);

/// m:ss por km; "--:--" si no hay dato o pasa de 59:59 (no es un ritmo real).
String formatearRitmo(double? segundosPorKm) {
  if (segundosPorKm == null || !segundosPorKm.isFinite) return '--:--';
  final s = segundosPorKm.round();
  if (s > 3599) return '--:--';
  return '${s ~/ 60}:${_dos(s % 60)}';
}
