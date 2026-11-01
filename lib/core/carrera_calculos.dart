import 'dart:math';

import '../models/tipo_actividad.dart';

/// Precisión (m) máxima para aceptar un punto.
const double precisionMaxM = 20;

/// Velocidad (m/s) máxima entre dos puntos aceptados; más es un salto.
const double velocidadMaxCorrerMs = 12;

/// Caminando nunca se llega a ~14 km/h.
const double velocidadMaxCaminarMs = 4;

/// Silencio (s) entre dos puntos, fuera de pausa, que se marca como hueco.
const int huecoMinS = 30;

/// Ventana (s) del ritmo actual.
const int ventanaRitmoS = 30;

/// Distancia (m) mínima para dar el ritmo medio.
const double ritmoMedioMinM = 100;

/// Distancia (m) mínima en la ventana para dar el ritmo actual.
const double ritmoActualMinM = 20;

class PuntoGps {
  PuntoGps({
    required this.lat,
    required this.lng,
    this.altitud,
    required this.precisionM,
    this.velocidad,
    required DateTime instante,
    this.aceptado = true,
  }) : instante = instante.toUtc();

  final double lat;
  final double lng;
  final double? altitud;
  final double precisionM;
  final double? velocidad;
  final DateTime instante;

  /// false: se guarda crudo pero no cuenta en distancia ni ritmo.
  final bool aceptado;

  PuntoGps conAceptado(bool valor) => PuntoGps(
    lat: lat,
    lng: lng,
    altitud: altitud,
    precisionM: precisionM,
    velocidad: velocidad,
    instante: instante,
    aceptado: valor,
  );
}

class PausaCarrera {
  PausaCarrera({required DateTime inicio, DateTime? fin, this.descanso = false})
    : inicio = inicio.toUtc(),
      fin = fin?.toUtc();

  final DateTime inicio;

  /// Pausa automática del descanso de los intervalos (no la pidió el usuario).
  final bool descanso;

  /// null: sigue en pausa.
  final DateTime? fin;
}

class HuecoGps {
  const HuecoGps(this.inicio, this.fin);

  final DateTime inicio;
  final DateTime fin;
}

class ResumenCarrera {
  const ResumenCarrera({
    required this.distanciaM,
    required this.tiempoMovimientoS,
    required this.ritmoMedioSKm,
    required this.ritmoActualSKm,
    required this.parcialesS,
    required this.huecos,
  });

  final double distanciaM;
  final int tiempoMovimientoS;

  /// Segundos por km; null si aún no hay distancia suficiente.
  final double? ritmoMedioSKm;
  final double? ritmoActualSKm;

  /// Segundos de cada kilómetro completo.
  final List<int> parcialesS;
  final List<HuecoGps> huecos;
}

double distanciaHaversineM(double lat1, double lng1, double lat2, double lng2) {
  const radioTierraM = 6371000.0;
  double rad(double g) => g * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * radioTierraM * asin(sqrt(a));
}

double _distancia(PuntoGps a, PuntoGps b) =>
    distanciaHaversineM(a.lat, a.lng, b.lat, b.lng);

/// Decide al llegar cada punto si cuenta (aceptado) o se guarda solo crudo.
class FiltroGps {
  FiltroGps({PuntoGps? ultimoAceptado, this.tipo = TipoActividad.correr})
    : _ancla = ultimoAceptado;

  final TipoActividad tipo;
  PuntoGps? _ancla;

  PuntoGps clasificar(PuntoGps p) {
    final ok = _acepta(p);
    if (ok) _ancla = p;
    return p.conAceptado(ok);
  }

  bool _acepta(PuntoGps p) {
    if (p.precisionM > precisionMaxM) return false;
    final a = _ancla;
    if (a == null) return true;
    final d = _distancia(a, p);
    // Desplazamiento menor que la precisión: ruido estando quieto.
    if (d < p.precisionM) return false;
    final dt = p.instante.difference(a.instante).inMilliseconds / 1000;
    final maxMs = switch (tipo) {
      TipoActividad.correr => velocidadMaxCorrerMs,
      TipoActividad.caminar => velocidadMaxCaminarMs,
    };
    return dt > 0 && d / dt <= maxMs;
  }
}

/// Separación mínima entre puntos de la línea dibujada (evita el temblor).
const double separacionVisualM = 1.5;

/// Elige los puntos de la línea DIBUJADA. Es más fino que [FiltroGps]: no
/// exige moverse más que la precisión, así la línea sigue las curvas. Solo es
/// visual; la distancia sigue saliendo de los puntos aceptados.
class FiltroVisual {
  FiltroVisual({this.tipo = TipoActividad.correr});

  final TipoActividad tipo;
  PuntoGps? _ultimo;

  bool admite(PuntoGps p) {
    if (p.precisionM > precisionMaxM) return false;
    final a = _ultimo;
    if (a != null) {
      final d = _distancia(a, p);
      if (d < separacionVisualM) return false;
      final dt = p.instante.difference(a.instante).inMilliseconds / 1000;
      final maxMs = switch (tipo) {
        TipoActividad.correr => velocidadMaxCorrerMs,
        TipoActividad.caminar => velocidadMaxCaminarMs,
      };
      if (dt <= 0 || d / dt > maxMs) return false;
    }
    _ultimo = p;
    return true;
  }
}

/// Línea dibujada de una lista completa de puntos (al recuperar o terminar),
/// en trozos: se corta en cada pausa y los puntos recibidos durante ella no
/// se dibujan, así no hay recta entre el antes y el después.
List<List<PuntoGps>> rutaVisual(
  List<PuntoGps> puntos,
  TipoActividad tipo,
  List<PausaCarrera> pausas,
) {
  final trozos = <List<PuntoGps>>[];
  var filtro = FiltroVisual(tipo: tipo);
  PuntoGps? previo;
  var cortar = false;
  for (final p in puntos) {
    final t = p.instante;
    if (pausas.any(
      (q) => !t.isBefore(q.inicio) && (q.fin == null || t.isBefore(q.fin!)),
    )) {
      continue;
    }
    final a = previo?.instante;
    if (a != null &&
        pausas.any((q) => q.inicio.isAfter(a) && q.inicio.isBefore(t))) {
      filtro = FiltroVisual(tipo: tipo);
      cortar = true;
    }
    previo = p;
    if (!filtro.admite(p)) continue;
    if (trozos.isEmpty || cortar) trozos.add([]);
    cortar = false;
    trozos.last.add(p);
  }
  return trozos;
}

typedef _Intervalo = (DateTime, DateTime);

/// Calcula el resumen. [puntos] va en orden de llegada e incluye los crudos
/// (aceptado=false); [ahora] sirve para anular el ritmo actual si ya pasó la
/// ventana desde el último punto aceptado.
ResumenCarrera calcularCarrera(
  List<PuntoGps> puntos,
  List<PausaCarrera> pausas, {
  DateTime? ahora,
}) {
  if (puntos.isEmpty) {
    return const ResumenCarrera(
      distanciaM: 0,
      tiempoMovimientoS: 0,
      ritmoMedioSKm: null,
      ritmoActualSKm: null,
      parcialesS: [],
      huecos: [],
    );
  }
  final finAbierto = DateTime.utc(9999);
  final intervalosPausa = _unir([
    for (final p in pausas) (p.inicio, p.fin ?? finAbierto),
  ]);

  final huecos = <HuecoGps>[];
  for (var i = 1; i < puntos.length; i++) {
    final a = puntos[i - 1].instante;
    final b = puntos[i].instante;
    final libre = b.difference(a) - _solape(a, b, intervalosPausa);
    if (libre.inSeconds > huecoMinS) huecos.add(HuecoGps(a, b));
  }
  final inactivos = _unir([
    ...intervalosPausa,
    for (final h in huecos) (h.inicio, h.fin),
  ]);

  Duration activo(DateTime a, DateTime b) =>
      b.difference(a) - _solape(a, b, inactivos);

  final inicio = puntos.first.instante;
  final tiempoS = activo(inicio, puntos.last.instante).inMilliseconds / 1000;

  final ac = puntos.where((p) => p.aceptado).toList();
  var distancia = 0.0;
  var marca = 1000.0;
  var inicioKm = inicio;
  final parciales = <int>[];
  for (var i = 1; i < ac.length; i++) {
    final a = ac[i - 1];
    final b = ac[i];
    if (_solape(a.instante, b.instante, inactivos) > Duration.zero) continue;
    final d = _distancia(a, b);
    if (d <= 0) continue;
    while (distancia + d >= marca) {
      final fraccion = (marca - distancia) / d;
      final cruce = a.instante.add(
        Duration(
          microseconds:
              (b.instante.difference(a.instante).inMicroseconds * fraccion)
                  .round(),
        ),
      );
      parciales.add(activo(inicioKm, cruce).inSeconds);
      inicioKm = cruce;
      marca += 1000;
    }
    distancia += d;
  }

  return ResumenCarrera(
    distanciaM: distancia,
    tiempoMovimientoS: tiempoS.round(),
    ritmoMedioSKm: distancia >= ritmoMedioMinM
        ? tiempoS / (distancia / 1000)
        : null,
    ritmoActualSKm: _ritmoActual(ac, inactivos, ahora),
    parcialesS: parciales,
    huecos: huecos,
  );
}

double? _ritmoActual(
  List<PuntoGps> ac,
  List<_Intervalo> inactivos,
  DateTime? ahora,
) {
  if (ac.length < 2) return null;
  final fin = ac.last.instante;
  if (ahora != null && ahora.difference(fin).inSeconds > ventanaRitmoS) {
    return null;
  }
  var metros = 0.0;
  var segundos = 0.0;
  for (var i = ac.length - 1; i > 0 && segundos < ventanaRitmoS; i--) {
    final a = ac[i - 1];
    final b = ac[i];
    if (_solape(a.instante, b.instante, inactivos) > Duration.zero) break;
    metros += _distancia(a, b);
    segundos += b.instante.difference(a.instante).inMilliseconds / 1000;
  }
  return metros >= ritmoActualMinM ? segundos / (metros / 1000) : null;
}

/// Ordena y fusiona intervalos para no restar dos veces lo mismo.
List<_Intervalo> _unir(List<_Intervalo> intervalos) {
  final orden = [...intervalos]..sort((x, y) => x.$1.compareTo(y.$1));
  final fusion = <_Intervalo>[];
  for (final i in orden) {
    if (fusion.isNotEmpty && !i.$1.isAfter(fusion.last.$2)) {
      if (i.$2.isAfter(fusion.last.$2)) {
        fusion[fusion.length - 1] = (fusion.last.$1, i.$2);
      }
    } else {
      fusion.add(i);
    }
  }
  return fusion;
}

Duration _solape(DateTime a, DateTime b, List<_Intervalo> fusionados) {
  var total = Duration.zero;
  for (final (ini, fin) in fusionados) {
    final desde = ini.isAfter(a) ? ini : a;
    final hasta = fin.isBefore(b) ? fin : b;
    if (hasta.isAfter(desde)) total += hasta.difference(desde);
  }
  return total;
}

/// Tiempo entre [inicio] y [fin] sin las pausas manuales; sigue corriendo en
/// los huecos de GPS.
int tiempoTranscurridoS(
  DateTime inicio,
  DateTime fin,
  List<PausaCarrera> pausas,
) {
  final intervalos = _unir([for (final p in pausas) (p.inicio, p.fin ?? fin)]);
  return (fin.difference(inicio) - _solape(inicio, fin, intervalos)).inSeconds
      .clamp(0, 1 << 31);
}
