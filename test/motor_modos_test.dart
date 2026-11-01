import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/motor_modos.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';

final _t0 = DateTime.utc(2026, 1, 1, 8);
const _mPorGrado = 111194.93;

PuntoGps _p(double metros, int s) => PuntoGps(
  lat: 4 + metros / _mPorGrado,
  lng: -74,
  precisionM: 2,
  instante: _t0.add(Duration(seconds: s)),
);

/// Un punto por segundo de [desde] a [hasta] a [v] m/s, empezando en la
/// posición [m0] en el segundo [s0].
List<PuntoGps> _mueve(
  int desde,
  int hasta, {
  double v = 3,
  double m0 = 0,
  int s0 = 0,
}) => [for (var s = desde; s <= hasta; s++) _p(m0 + v * (s - s0), s)];

PausaCarrera _pausa(int ini, [int? fin, bool descanso = false]) => PausaCarrera(
  inicio: _t0.add(Duration(seconds: ini)),
  fin: fin == null ? null : _t0.add(Duration(seconds: fin)),
  descanso: descanso,
);

EstadoModo _ev(
  ModoActividad modo,
  List<PuntoGps> puntos,
  int s, [
  List<PausaCarrera> pausas = const [],
]) => evaluarModo(
  modo: modo,
  inicio: _t0,
  puntos: puntos,
  pausas: pausas,
  ahora: _t0.add(Duration(seconds: s)),
);

void main() {
  group('intervalos: tramo', () {
    const porDistancia = ModoIntervalos(
      tramo: 400,
      descanso: 90,
      repeticiones: 3,
    );

    test('por distancia: avanza, da el ritmo y avisa al completar', () {
      final e = _ev(porDistancia, _mueve(0, 100), 100);
      expect(e.fase, FaseModo.corriendo);
      expect(e.repeticion, 1);
      expect(e.progreso, closeTo(300, 3));
      expect(e.objetivo, 400);
      expect(e.tiempoTramoS, 100);
      expect(e.ritmoTramoSKm, closeTo(333.3, 5));
      expect(e.evento, isNull);

      final listo = _ev(porDistancia, _mueve(0, 134), 134);
      expect(listo.evento, EventoModo.empezarDescanso);
    });

    test('por tiempo: se completa a los segundos del tramo', () {
      const modo = ModoIntervalos(
        tramoMedida: Medida.tiempo,
        tramo: 120,
        repeticiones: 3,
      );
      final pts = _mueve(0, 130);
      expect(_ev(modo, pts, 119).evento, isNull);
      final e = _ev(modo, pts, 120);
      expect(e.progreso, 120);
      expect(e.evento, EventoModo.empezarDescanso);
    });

    test('la pausa manual congela el tramo (el tiempo es en movimiento)', () {
      const modo = ModoIntervalos(
        tramoMedida: Medida.tiempo,
        tramo: 120,
        repeticiones: 3,
      );
      final pts = _mueve(0, 170);
      final pausas = [_pausa(50, 100)];
      final e = _ev(modo, pts, 130, pausas);
      expect(e.tiempoTramoS, 80);
      expect(e.evento, isNull);
      // Pausado ahora mismo: sigue sin avanzar.
      expect(_ev(modo, pts, 160, [_pausa(50)]).tiempoTramoS, 50);
      expect(_ev(modo, pts, 170, pausas).evento, EventoModo.empezarDescanso);
    });

    test('la pausa manual no suma metros al tramo por distancia', () {
      final pts = [..._mueve(0, 50), ..._mueve(51, 100, m0: 150, s0: 50)];
      final e = _ev(porDistancia, pts, 100, [_pausa(50, 70)]);
      // 100 s a 3 m/s serían 300 m; los 20 s de pausa no suman.
      expect(e.distanciaTramoM, closeTo(240, 4));
    });
  });

  group('intervalos: descanso', () {
    const porTiempo = ModoIntervalos(tramo: 400, descanso: 90, repeticiones: 3);

    test('por tiempo: cuenta atrás, valores del tramo congelados', () {
      final pts = [
        ..._mueve(0, 134),
        ..._mueve(135, 164, v: 1, m0: 402, s0: 134),
      ];
      final pausas = [_pausa(134, null, true)];
      final e = _ev(porTiempo, pts, 164, pausas);
      expect(e.fase, FaseModo.descansando);
      expect(e.repeticion, 1);
      expect(e.restanteDescanso, closeTo(60, 0.01));
      expect(e.tiempoTramoS, 134);
      expect(e.distanciaTramoM, closeTo(402, 4));
      expect(e.ritmoTramoSKm, closeTo(333.3, 5));
      expect(e.evento, isNull);

      expect(_ev(porTiempo, pts, 223, pausas).evento, isNull);
      expect(_ev(porTiempo, pts, 224, pausas).evento, EventoModo.empezarTramo);
    });

    test('por metros: cuentan los puntos recibidos en el descanso', () {
      const modo = ModoIntervalos(
        tramo: 400,
        descansoMedida: Medida.distancia,
        descanso: 100,
        repeticiones: 3,
      );
      final pausas = [_pausa(134, null, true)];
      List<PuntoGps> hasta(int s) => [
        ..._mueve(0, 134),
        ..._mueve(135, s, v: 1, m0: 402, s0: 134),
      ];
      final a = _ev(modo, hasta(194), 194, pausas); // 60 m caminados
      expect(a.fase, FaseModo.descansando);
      expect(a.restanteDescanso, closeTo(40, 1));
      expect(a.evento, isNull);
      // Lo caminado no se suma al tramo.
      expect(a.distanciaTramoM, closeTo(402, 4));

      final b = _ev(modo, hasta(236), 236, pausas); // 102 m
      expect(b.restanteDescanso, 0);
      expect(b.evento, EventoModo.empezarTramo);
    });

    test(
      'al acabar el descanso empieza la repetición siguiente desde cero',
      () {
        final pts = [
          ..._mueve(0, 134),
          ..._mueve(135, 240, v: 1, m0: 402, s0: 134),
        ];
        final pausas = [_pausa(134, 224, true)];
        final e = _ev(porTiempo, pts, 240, pausas);
        expect(e.fase, FaseModo.corriendo);
        expect(e.repeticion, 2);
        expect(e.tiempoTramoS, 16);
        expect(e.progreso, closeTo(16, 2)); // caminando a 1 m/s
        expect(e.evento, isNull);
      },
    );

    test('saltar el descanso es cerrarlo antes: el tramo cuenta desde ahí', () {
      final pts = _mueve(0, 160);
      final pausas = [_pausa(134, 140, true)];
      final e = _ev(porTiempo, pts, 160, pausas);
      expect(e.repeticion, 2);
      expect(e.tiempoTramoS, 20);
    });
  });

  group('intervalos: repeticiones y final', () {
    test('con repeticiones fijas la última no descansa: termina', () {
      const modo = ModoIntervalos(tramo: 100, descanso: 10, repeticiones: 2);
      // Tramo 1 de 0 a 34 s, descanso 34 a 44 s, tramo 2 desde 44 s.
      final pausas = [_pausa(34, 44, true)];
      final pts = [..._mueve(0, 34), ..._mueve(45, 80, m0: 102, s0: 44)];
      final antes = _ev(modo, pts, 60, pausas);
      expect(antes.repeticion, 2);
      expect(antes.fase, FaseModo.corriendo);
      expect(antes.evento, isNull);

      final fin = _ev(modo, pts, 80, pausas);
      expect(fin.fase, FaseModo.terminado);
      expect(fin.evento, EventoModo.finIntervalos);
      // Sigue terminado aunque pase el tiempo o haya pausa manual.
      expect(
        _ev(modo, pts, 90, [...pausas, _pausa(85)]).fase,
        FaseModo.terminado,
      );
    });

    test('la repetición intermedia pide descanso, no fin', () {
      const modo = ModoIntervalos(tramo: 100, descanso: 10, repeticiones: 2);
      expect(_ev(modo, _mueve(0, 40), 40).evento, EventoModo.empezarDescanso);
    });

    test('sin límite nunca termina', () {
      const modo = ModoIntervalos(
        tramoMedida: Medida.tiempo,
        tramo: 30,
        descanso: 10,
        repeticiones: null,
      );
      final pausas = [
        _pausa(30, 40, true),
        _pausa(70, 80, true),
        _pausa(110, 120, true),
      ];
      final pts = _mueve(0, 200);
      final e = _ev(modo, pts, 150, pausas);
      expect(e.repeticion, 4);
      expect(e.evento, EventoModo.empezarDescanso);
      expect(e.fase, FaseModo.corriendo);
    });
  });

  group('meta', () {
    test('por distancia: se alcanza al llegar y sigue marcada después', () {
      const modo = ModoMeta(valor: 1000);
      final pts = _mueve(0, 340);
      final antes = _ev(modo, pts.sublist(0, 333), 332);
      expect(antes.progreso, closeTo(996, 5));
      expect(antes.evento, isNull);
      expect(_ev(modo, pts, 340).evento, EventoModo.metaAlcanzada);
    });

    test('por tiempo en movimiento: las pausas no cuentan', () {
      const modo = ModoMeta(medida: Medida.tiempo, valor: 60);
      final pts = _mueve(0, 100);
      final pausas = [_pausa(10, 30)];
      final e = _ev(modo, pts, 70, pausas);
      expect(e.progreso, 50);
      expect(e.evento, isNull);
      expect(_ev(modo, pts, 80, pausas).evento, EventoModo.metaAlcanzada);
    });

    test('en libre no hay nada que hacer', () {
      final e = _ev(const ModoLibre(), _mueve(0, 50), 50);
      expect(e.evento, isNull);
      expect(e.fase, FaseModo.corriendo);
    });
  });
}
