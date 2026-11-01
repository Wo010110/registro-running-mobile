import '../models/modo_actividad.dart';
import 'carrera_calculos.dart';

enum FaseModo { corriendo, descansando, terminado }

/// Lo que toca hacer ahora. Es la condición vigente, no un aviso de una sola
/// vez: quien lo ejecuta evita repetir [finIntervalos] y [metaAlcanzada].
enum EventoModo { empezarDescanso, empezarTramo, finIntervalos, metaAlcanzada }

class EstadoModo {
  const EstadoModo({
    required this.fase,
    this.repeticion = 0,
    this.progreso = 0,
    this.objetivo = 0,
    this.tiempoTramoS = 0,
    this.distanciaTramoM = 0,
    this.ritmoTramoSKm,
    this.restanteDescanso = 0,
    this.evento,
  });

  final FaseModo fase;

  /// Tramo en curso; descansando, el que acaba de terminar. 0 si no hay.
  final int repeticion;

  /// Intervalos: avance del tramo (m o s según su medida). Meta: avance hacia
  /// la meta. [objetivo] es el valor al que se compara.
  final double progreso;
  final double objetivo;

  /// Del tramo en curso; descansando, los del último tramo (congelados).
  final int tiempoTramoS;
  final double distanciaTramoM;
  final double? ritmoTramoSKm;

  /// Lo que falta de descanso: s o m según su medida.
  final double restanteDescanso;
  final EventoModo? evento;
}

/// Estado del modo a partir de lo guardado, sin memoria propia: sirve igual en
/// vivo que al recuperar una actividad. [puntos] va en orden de llegada e
/// incluye los crudos (ordenados por instante); [distanciaTotalM] ahorra
/// recalcularla si quien llama ya la tiene; en los intervalos cada descanso es una pausa con
/// `descanso` y todas las demás son pausas manuales, que congelan el tramo.
EstadoModo evaluarModo({
  required ModoActividad modo,
  required DateTime inicio,
  required List<PuntoGps> puntos,
  required List<PausaCarrera> pausas,
  required DateTime ahora,
  double? distanciaTotalM,
}) => switch (modo) {
  ModoLibre() => const EstadoModo(fase: FaseModo.corriendo),
  ModoIntervalos() => _intervalos(modo, inicio, puntos, pausas, ahora),
  ModoMeta() => _meta(modo, inicio, puntos, pausas, ahora, distanciaTotalM),
};

/// Los puntos desde [desde] (inclusive) hasta [hasta]; recorre desde el final
/// porque están ordenados, así no pasa por toda la lista en cada evaluación.
List<PuntoGps> _desde(
  List<PuntoGps> puntos,
  DateTime desde, [
  DateTime? hasta,
]) {
  final r = <PuntoGps>[];
  for (var i = puntos.length - 1; i >= 0; i--) {
    final t = puntos[i].instante;
    if (t.isBefore(desde)) break;
    if (hasta == null || !t.isAfter(hasta)) r.add(puntos[i]);
  }
  return r.reversed.toList();
}

EstadoModo _meta(
  ModoMeta modo,
  DateTime inicio,
  List<PuntoGps> puntos,
  List<PausaCarrera> pausas,
  DateTime ahora,
  double? distanciaTotalM,
) {
  final progreso = modo.medida == Medida.distancia
      ? distanciaTotalM ?? calcularCarrera(puntos, pausas).distanciaM
      : tiempoTranscurridoS(inicio, ahora, pausas).toDouble();
  return EstadoModo(
    fase: FaseModo.corriendo,
    progreso: progreso,
    objetivo: modo.valor.toDouble(),
    evento: progreso >= modo.valor ? EventoModo.metaAlcanzada : null,
  );
}

typedef _Tramo = (int, double, double?);

/// (segundos en movimiento, metros, ritmo s/km) entre [ini] y [fin].
_Tramo _medirTramo(
  List<PuntoGps> puntos,
  List<PausaCarrera> manuales,
  DateTime ini,
  DateTime fin,
) {
  final dentro = _desde(puntos, ini, fin);
  final metros = calcularCarrera(dentro, manuales).distanciaM;
  final s = tiempoTranscurridoS(ini, fin, manuales);
  return (s, metros, metros >= ritmoActualMinM ? s / (metros / 1000) : null);
}

EstadoModo _intervalos(
  ModoIntervalos modo,
  DateTime inicio,
  List<PuntoGps> puntos,
  List<PausaCarrera> pausas,
  DateTime ahora,
) {
  final descansos = [
    for (final p in pausas)
      if (p.descanso) p,
  ];
  final manuales = [
    for (final p in pausas)
      if (!p.descanso) p,
  ];
  final descansando = descansos.isNotEmpty && descansos.last.fin == null;

  if (descansando) {
    final descanso = descansos.last;
    // El tramo que acaba de terminar empezó donde acabó el descanso anterior.
    final iniTramo = descansos.length >= 2
        ? descansos[descansos.length - 2].fin!
        : inicio;
    final (s, m, ritmo) = _medirTramo(
      puntos,
      manuales,
      iniTramo,
      descanso.inicio,
    );
    final restante = modo.descansoMedida == Medida.tiempo
        ? modo.descanso -
              ahora.toUtc().difference(descanso.inicio).inMilliseconds / 1000
        : modo.descanso -
              calcularCarrera(
                _desde(puntos, descanso.inicio),
                const [],
              ).distanciaM;
    return EstadoModo(
      fase: FaseModo.descansando,
      repeticion: descansos.length,
      progreso: (modo.tramoMedida == Medida.distancia ? m : s).toDouble(),
      objetivo: modo.tramo.toDouble(),
      tiempoTramoS: s,
      distanciaTramoM: m,
      ritmoTramoSKm: ritmo,
      restanteDescanso: restante < 0 ? 0 : restante,
      evento: restante <= 0 ? EventoModo.empezarTramo : null,
    );
  }

  final repeticion = descansos.length + 1;
  final iniTramo = descansos.isEmpty ? inicio : descansos.last.fin!;
  final (s, m, ritmo) = _medirTramo(puntos, manuales, iniTramo, ahora.toUtc());
  final progreso = (modo.tramoMedida == Medida.distancia ? m : s).toDouble();
  final completo = progreso >= modo.tramo;
  final ultimo = modo.repeticiones != null && repeticion >= modo.repeticiones!;
  return EstadoModo(
    fase: completo && ultimo ? FaseModo.terminado : FaseModo.corriendo,
    repeticion: repeticion,
    progreso: progreso,
    objetivo: modo.tramo.toDouble(),
    tiempoTramoS: s,
    distanciaTramoM: m,
    ritmoTramoSKm: ritmo,
    evento: !completo
        ? null
        : ultimo
        ? EventoModo.finIntervalos
        : EventoModo.empezarDescanso,
  );
}
