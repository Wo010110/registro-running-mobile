import 'dart:math';

import '../models/tipo_actividad.dart';
import 'carrera_calculos.dart';
import 'carreras_db.dart';

const diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// "Carrera de la mañana", "Caminata de la tarde"... según la hora local.
String tituloActividad(TipoActividad tipo, DateTime inicioUtc) {
  final h = inicioUtc.toLocal().hour;
  final franja = h < 6
      ? 'de la madrugada'
      : h < 12
      ? 'de la mañana'
      : h < 19
      ? 'de la tarde'
      : 'de la noche';
  return '${tipo == TipoActividad.correr ? 'Carrera' : 'Caminata'} $franja';
}

/// Segundos por km del tiempo en movimiento; null sin distancia suficiente.
double? ritmoMedioSKm(CarreraLocal c) => c.distanciaM < ritmoMedioMinM
    ? null
    : c.tiempoMovimientoS / (c.distanciaM / 1000);

/// Kilómetros de lunes a domingo de la semana de [ahora], hora local.
List<double> kmPorDiaSemana(Iterable<CarreraLocal> carreras, DateTime ahora) {
  final dia = DateTime.utc(ahora.year, ahora.month, ahora.day);
  final lunes = dia.subtract(Duration(days: dia.weekday - 1));
  final km = List<double>.filled(7, 0);
  for (final c in carreras) {
    final l = c.inicioUtc.toLocal();
    final i = DateTime.utc(l.year, l.month, l.day).difference(lunes).inDays;
    if (i >= 0 && i < 7) km[i] += c.distanciaM / 1000;
  }
  return km;
}

/// Dibujo de la ruta con los puntos aceptados, de 0 a 1 en cada eje. Conserva
/// las proporciones del recorrido dentro de una caja de ancho [aspecto] por 1
/// de alto, centrado. Devuelve como mucho [maxPuntos] puntos.
List<(double, double)> trazoNormalizado(
  List<PuntoGps> puntos, {
  double aspecto = 2.8,
  int maxPuntos = 60,
}) {
  final p = [
    for (final q in puntos)
      if (q.aceptado) q,
  ];
  if (p.length < 2) return const [];
  final paso = p.length <= maxPuntos ? 1 : (p.length / maxPuntos).ceil();
  final m = [for (var i = 0; i < p.length; i += paso) p[i]];
  if (m.last != p.last) m.add(p.last);

  // Un grado de longitud mide cos(latitud) veces menos que uno de latitud.
  final k = cos(p.first.lat * pi / 180);
  final xs = [for (final q in m) q.lng * k];
  final ys = [for (final q in m) -q.lat];
  final minX = xs.reduce(min);
  final minY = ys.reduce(min);
  final ancho = xs.reduce(max) - minX;
  final alto = ys.reduce(max) - minY;
  if (ancho == 0 && alto == 0) return const [];

  final escala = min(
    ancho > 0 ? aspecto / ancho : double.infinity,
    alto > 0 ? 1 / alto : double.infinity,
  );
  final dx = (aspecto - ancho * escala) / 2;
  final dy = (1 - alto * escala) / 2;
  return [
    for (var i = 0; i < m.length; i++)
      (((xs[i] - minX) * escala + dx) / aspecto, (ys[i] - minY) * escala + dy),
  ];
}
