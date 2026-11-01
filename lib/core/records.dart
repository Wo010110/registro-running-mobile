import 'carrera_calculos.dart';

/// Distancias (m) de los récords personales.
const objetivosRecord = <double>[
  100,
  500,
  1000,
  5000,
  10000,
  21097.5,
  42195,
  100000,
];

/// Rótulo de cada objetivo.
final rotulosRecord = <double, String>{
  100: '100 m',
  500: '500 m',
  1000: '1 km',
  5000: '5 km',
  10000: '10 km',
  21097.5: '21 km',
  42195: '42 km',
  100000: '100 km',
};

/// Mejor tiempo (s) para cada distancia de [objetivosRecord] que la actividad
/// llegó a cubrir de forma CONTINUA: sin cruzar una pausa (manual o de
/// descanso) ni un hueco de GPS. Solo cuentan los puntos aceptados y los
/// recibidos fuera de pausa. Los bordes del tramo se interpolan.
Map<double, double> mejoresTramos(
  List<PuntoGps> puntos,
  List<PausaCarrera> pausas,
) {
  final resultado = <double, double>{};
  for (final segmento in _segmentosContinuos(puntos, pausas)) {
    final (d, t) = _acumulado(segmento);
    for (final objetivo in objetivosRecord) {
      final s = _mejorVentana(d, t, objetivo);
      if (s != null && s < (resultado[objetivo] ?? double.infinity)) {
        resultado[objetivo] = s;
      }
    }
  }
  return resultado;
}

bool _enPausa(DateTime t, List<PausaCarrera> pausas) => pausas.any(
  (p) => !t.isBefore(p.inicio) && (p.fin == null || t.isBefore(p.fin!)),
);

List<List<PuntoGps>> _segmentosContinuos(
  List<PuntoGps> puntos,
  List<PausaCarrera> pausas,
) {
  final segmentos = <List<PuntoGps>>[];
  PuntoGps? previo;
  for (final p in puntos) {
    if (!p.aceptado || _enPausa(p.instante, pausas)) continue;
    final a = previo?.instante;
    final corte =
        a == null ||
        p.instante.difference(a).inSeconds > huecoMinS ||
        pausas.any((q) => q.inicio.isAfter(a) && q.inicio.isBefore(p.instante));
    if (corte) segmentos.add([]);
    segmentos.last.add(p);
    previo = p;
  }
  return segmentos;
}

/// Distancia acumulada (m) y tiempo (s) desde el primer punto del segmento.
(List<double>, List<double>) _acumulado(List<PuntoGps> s) {
  final d = <double>[0];
  final t = <double>[0];
  for (var i = 1; i < s.length; i++) {
    d.add(
      d.last +
          distanciaHaversineM(s[i - 1].lat, s[i - 1].lng, s[i].lat, s[i].lng),
    );
    t.add(s[i].instante.difference(s[0].instante).inMicroseconds / 1e6);
  }
  return (d, t);
}

/// Menor tiempo para cubrir [objetivo] metros dentro del segmento, o null si
/// no llega. El tiempo es lineal entre puntos, así que la mejor ventana
/// empieza o termina en un punto: se prueban ambos casos con dos punteros.
double? _mejorVentana(List<double> d, List<double> t, double objetivo) {
  final n = d.length;
  if (n < 2 || d.last + 1e-9 < objetivo) return null;
  double? mejor;
  void anotar(double s) {
    if (mejor == null || s < mejor!) mejor = s;
  }

  // Ventana que termina en el punto j; el inicio se interpola.
  var i = 0;
  for (var j = 1; j < n; j++) {
    final x = d[j] - objetivo;
    if (x < 0) continue;
    while (i + 1 < j && d[i + 1] <= x) {
      i++;
    }
    final largo = d[i + 1] - d[i];
    final inicio = largo <= 0
        ? t[i]
        : t[i] + (t[i + 1] - t[i]) * (x - d[i]) / largo;
    anotar(t[j] - inicio);
  }

  // Ventana que empieza en el punto i; el final se interpola.
  var j = 1;
  for (var i2 = 0; i2 < n - 1; i2++) {
    final y = d[i2] + objetivo;
    if (y > d.last + 1e-9) break;
    while (j < n - 1 && d[j] < y - 1e-9) {
      j++;
    }
    final largo = d[j] - d[j - 1];
    final fin = largo <= 0
        ? t[j]
        : t[j - 1] + (t[j] - t[j - 1]) * (y - d[j - 1]) / largo;
    anotar(fin - t[i2]);
  }
  return mejor;
}
