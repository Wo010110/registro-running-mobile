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

/// Km con un decimal y coma ("23,7").
String formatearKmUno(double km) => NumberFormat('0.0', 'es').format(km);

const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "Hoy · 6:12", "Ayer · 18:30" o "Dom 25 oct · 7:00" (con año si no es el
/// actual), en hora local.
String formatearFechaActividad(DateTime inicioUtc, DateTime ahora) {
  final l = inicioUtc.toLocal();
  final dias = DateTime.utc(
    ahora.year,
    ahora.month,
    ahora.day,
  ).difference(DateTime.utc(l.year, l.month, l.day)).inDays;
  final hora = '${l.hour}:${_dos(l.minute)}';
  if (dias == 0) return 'Hoy · $hora';
  if (dias == 1) return 'Ayer · $hora';
  final anio = l.year == ahora.year ? '' : ' ${l.year}';
  return '${_diasCortos[l.weekday - 1]} ${l.day} '
      '${_mesesCortos[l.month - 1]}$anio · $hora';
}

/// m:ss por km; "--:--" si no hay dato o pasa de 59:59 (no es un ritmo real).
String formatearRitmo(double? segundosPorKm) {
  if (segundosPorKm == null || !segundosPorKm.isFinite) return '--:--';
  final s = segundosPorKm.round();
  if (s > 3599) return '--:--';
  return '${s ~/ 60}:${_dos(s % 60)}';
}
