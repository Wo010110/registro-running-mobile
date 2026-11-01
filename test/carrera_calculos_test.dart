import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';

final _t0 = DateTime.utc(2026, 1, 1, 8);

// Un grado de latitud son ~111 195 m con el radio que usa haversine.
const _mPorGrado = 111194.93;

PuntoGps _punto(
  double metrosNorte,
  int segundos, {
  double ruido = 0,
  double precision = 5,
}) => PuntoGps(
  lat: 4 + (metrosNorte + ruido) / _mPorGrado,
  lng: -74 + ruido / _mPorGrado,
  precisionM: precision,
  instante: _t0.add(Duration(seconds: segundos)),
);

List<PuntoGps> _clasificar(
  List<PuntoGps> crudos, [
  TipoActividad tipo = TipoActividad.correr,
]) {
  final filtro = FiltroGps(tipo: tipo);
  return crudos.map(filtro.clasificar).toList();
}

void main() {
  test('la línea dibujada sigue pasos cortos que la distancia descarta', () {
    // Caminando a 2 m/s con precisión 5 m: el filtro de distancia descarta
    // casi todo (cada paso < precisión); la línea dibujada los conserva.
    final crudos = [for (var s = 0; s <= 10; s++) _punto(s * 2.0, s)];
    final aceptados = _clasificar(
      crudos,
      TipoActividad.caminar,
    ).where((p) => p.aceptado).length;
    final visual = rutaVisual(
      crudos,
      TipoActividad.caminar,
      const [],
    ).single.length;
    expect(visual, greaterThan(aceptados));
    expect(visual, 11);
  });

  test('la línea dibujada omite temblor, mala precisión y saltos', () {
    final crudos = [
      _punto(0, 0),
      _punto(0.5, 1), // temblor < 1,5 m
      _punto(3, 2),
      _punto(6, 3, precision: 40), // mala precisión
      _punto(500, 4), // salto imposible caminando
      _punto(5, 5),
    ];
    final visual = rutaVisual(crudos, TipoActividad.caminar, const []).single;
    expect(visual.length, 3);
  });

  test('el punto normaliza el instante a UTC', () {
    final p = PuntoGps(
      lat: 0,
      lng: 0,
      precisionM: 5,
      instante: DateTime.parse('2026-01-01T08:00:00-05:00'),
    );
    expect(p.instante.isUtc, isTrue);
    expect(p.instante.hour, 13);
  });

  test('recta de 3000 m con ruido de GPS queda dentro de ±2 %', () {
    final azar = Random(7);
    // 3 m/s durante 1000 s, ruido uniforme de ±1 m por eje.
    final crudos = [
      for (var s = 0; s <= 1000; s++)
        PuntoGps(
          lat: 4 + (3.0 * s + (azar.nextDouble() * 2 - 1)) / _mPorGrado,
          lng: -74 + (azar.nextDouble() * 2 - 1) / _mPorGrado,
          precisionM: 5,
          instante: _t0.add(Duration(seconds: s)),
        ),
    ];
    final r = calcularCarrera(_clasificar(crudos), []);
    expect(r.distanciaM, closeTo(3000, 60));
    expect(r.tiempoMovimientoS, 1000);
    expect(r.ritmoMedioSKm, closeTo(333.3, 7));
  });

  test('caminata a 1,4 m/s con ruido queda dentro de ±2 %', () {
    final azar = Random(11);
    // 1,4 m/s durante 1000 s = 1400 m, ruido uniforme de ±1 m por eje.
    final crudos = [
      for (var s = 0; s <= 1000; s++)
        PuntoGps(
          lat: 4 + (1.4 * s + (azar.nextDouble() * 2 - 1)) / _mPorGrado,
          lng: -74 + (azar.nextDouble() * 2 - 1) / _mPorGrado,
          precisionM: 5,
          instante: _t0.add(Duration(seconds: s)),
        ),
    ];
    final r = calcularCarrera(_clasificar(crudos, TipoActividad.caminar), []);
    expect(r.distanciaM, closeTo(1400, 28));
    expect(r.tiempoMovimientoS, 1000);
    expect(r.ritmoMedioSKm, closeTo(714.3, 14));
    expect(r.parcialesS.length, 1);
  });

  test('un salto de 6 m/s se descarta caminando y se acepta corriendo', () {
    final crudos = [_punto(0, 0), _punto(6, 1)];
    expect(_clasificar(crudos, TipoActividad.caminar).last.aceptado, isFalse);
    expect(_clasificar(crudos).last.aceptado, isTrue);
  });

  test('salto imposible y precisión mala se descartan pero se conservan', () {
    final puntos = _clasificar([
      _punto(0, 0),
      _punto(6, 1),
      _punto(1000, 2), // 995 m en 1 s
      _punto(12, 3),
      _punto(15, 4, precision: 50),
      _punto(18, 5),
    ]);
    expect(puntos.map((p) => p.aceptado), [
      true,
      true,
      false,
      true,
      false,
      true,
    ]);
    expect(puntos.length, 6);
    final r = calcularCarrera(puntos, []);
    expect(r.distanciaM, closeTo(18, 0.5));
  });

  test('parado con ruido dentro de la precisión no suma metros', () {
    final azar = Random(3);
    final crudos = [
      for (var s = 0; s < 120; s++)
        PuntoGps(
          lat: 4 + (azar.nextDouble() * 6 - 3) / _mPorGrado,
          lng: -74 + (azar.nextDouble() * 6 - 3) / _mPorGrado,
          precisionM: 8,
          instante: _t0.add(Duration(seconds: s)),
        ),
    ];
    final r = calcularCarrera(_clasificar(crudos), []);
    expect(r.distanciaM, 0);
    expect(r.ritmoMedioSKm, isNull);
  });

  test('la pausa no cuenta en tiempo ni en distancia', () {
    // 0-100 s corriendo a 3 m/s, pausa 100-200 s (moviéndose 100 m), luego 100 s más.
    final crudos = [
      for (var s = 0; s <= 100; s++) _punto(3.0 * s, s),
      for (var s = 200; s <= 300; s++) _punto(300 + 100 + 3.0 * (s - 200), s),
    ];
    final pausa = PausaCarrera(
      inicio: _t0.add(const Duration(seconds: 100)),
      fin: _t0.add(const Duration(seconds: 200)),
    );
    final r = calcularCarrera(_clasificar(crudos), [pausa]);
    expect(r.tiempoMovimientoS, 200);
    expect(r.distanciaM, closeTo(600, 1));
    expect(r.ritmoMedioSKm, closeTo(333.3, 1));
    expect(r.huecos, isEmpty);
  });

  test('un silencio sin pausa es hueco y no suma distancia', () {
    final crudos = [
      for (var s = 0; s <= 60; s++) _punto(3.0 * s, s),
      // la app estuvo cerrada 10 min y el siguiente punto está 1500 m más allá
      for (var s = 660; s <= 720; s++) _punto(1500 + 3.0 * (s - 660), s),
    ];
    final r = calcularCarrera(_clasificar(crudos), []);
    expect(r.huecos.length, 1);
    expect(r.huecos.first.fin.difference(r.huecos.first.inicio).inSeconds, 600);
    expect(r.distanciaM, closeTo(360, 1));
    expect(r.tiempoMovimientoS, 120);
  });

  test('parciales por km: solo los kilómetros completos', () {
    // 2,5 km a 4 m/s: km 1 y 2 a 250 s, el tercero queda incompleto.
    final crudos = [for (var s = 0; s <= 625; s++) _punto(4.0 * s, s)];
    final r = calcularCarrera(_clasificar(crudos), []);
    expect(r.parcialesS, [250, 250]);
    // se pierde como mucho el último tramo corto (< precisión)
    expect(r.distanciaM, closeTo(2500, 10));
  });

  test('los parciales no cuentan el tiempo en pausa', () {
    // km 1 a 4 m/s (250 s), pausa de 60 s a mitad del km 2.
    final crudos = [
      for (var s = 0; s <= 375; s++) _punto(4.0 * s, s),
      for (var s = 435; s <= 625; s++) _punto(4.0 * (s - 60), s),
    ];
    final pausa = PausaCarrera(
      inicio: _t0.add(const Duration(seconds: 375)),
      fin: _t0.add(const Duration(seconds: 435)),
    );
    final r = calcularCarrera(_clasificar(crudos), [pausa]);
    // en el borde de la pausa se pierde como mucho un tramo corto
    expect(r.parcialesS.length, 2);
    expect(r.parcialesS[0], 250);
    expect(r.parcialesS[1], closeTo(250, 4));
  });

  test('ritmo actual usa la ventana de 30 s, no el promedio', () {
    // 200 s a 2 m/s y después 40 s a 4 m/s.
    final crudos = [
      for (var s = 0; s <= 200; s++) _punto(2.0 * s, s),
      for (var s = 201; s <= 240; s++) _punto(400 + 4.0 * (s - 200), s),
    ];
    final r = calcularCarrera(_clasificar(crudos), []);
    expect(r.ritmoActualSKm, closeTo(250, 5));
    expect(r.ritmoMedioSKm, greaterThan(300));
    final tarde = calcularCarrera(
      _clasificar(crudos),
      [],
      ahora: _t0.add(const Duration(seconds: 400)),
    );
    expect(tarde.ritmoActualSKm, isNull);
  });

  test(
    'sin 100 m no hay ritmo medio; sin 20 m en la ventana no hay actual',
    () {
      final corto = calcularCarrera(
        _clasificar([for (var s = 0; s <= 30; s++) _punto(2.0 * s, s)]),
        [],
      );
      expect(corto.distanciaM, closeTo(60, 1));
      expect(corto.ritmoMedioSKm, isNull);
      expect(corto.ritmoActualSKm, isNotNull);
      final lento = calcularCarrera(
        _clasificar([for (var s = 0; s <= 30; s++) _punto(0.5 * s, s)]),
        [],
      );
      expect(lento.ritmoActualSKm, isNull);
    },
  );

  test('tiempo transcurrido: sin pausas, corre en los huecos', () {
    final pausas = [
      PausaCarrera(
        inicio: _t0.add(const Duration(seconds: 10)),
        fin: _t0.add(const Duration(seconds: 40)),
      ),
      PausaCarrera(inicio: _t0.add(const Duration(seconds: 90))),
    ];
    expect(
      tiempoTranscurridoS(_t0, _t0.add(const Duration(seconds: 100)), pausas),
      60,
    );
  });

  test('sin puntos devuelve ceros', () {
    final r = calcularCarrera([], []);
    expect(r.distanciaM, 0);
    expect(r.tiempoMovimientoS, 0);
    expect(r.parcialesS, isEmpty);
  });

  test('calcular 6000 puntos (90 min) tarda poco para recalcular en vivo', () {
    final filtro = FiltroGps();
    final puntos = [
      for (var s = 0; s < 6000; s++) filtro.clasificar(_punto(3.0 * s, s)),
    ];
    final pausas = [
      PausaCarrera(
        inicio: _t0.add(const Duration(minutes: 20)),
        fin: _t0.add(const Duration(minutes: 21)),
      ),
    ];
    calcularCarrera(puntos, pausas); // calienta el JIT
    final reloj = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      calcularCarrera(puntos, pausas);
    }
    final msPorCalculo = reloj.elapsedMicroseconds / 10 / 1000;
    // ignore: avoid_print
    print(
      'calcularCarrera(6000 puntos): ${msPorCalculo.toStringAsFixed(2)} ms',
    );
    expect(msPorCalculo, lessThan(20));
  });

  group('línea dibujada en trozos', () {
    PausaCarrera pausa(int ini, [int? fin]) => PausaCarrera(
      inicio: _t0.add(Duration(seconds: ini)),
      fin: fin == null ? null : _t0.add(Duration(seconds: fin)),
    );
    final crudos = [for (var s = 0; s <= 30; s++) _punto(s * 3.0, s)];

    test('sin pausas es un solo trozo', () {
      final trozos = rutaVisual(crudos, TipoActividad.correr, const []);
      expect(trozos.length, 1);
      expect(trozos.single.length, 31);
    });

    test('se corta en cada pausa y no dibuja lo recibido durante ella', () {
      final trozos = rutaVisual(crudos, TipoActividad.correr, [pausa(10, 20)]);
      expect(trozos.length, 2);
      expect(trozos.first.last.instante, _t0.add(const Duration(seconds: 9)));
      expect(trozos.last.first.instante, _t0.add(const Duration(seconds: 20)));
      expect(trozos.fold<int>(0, (n, t) => n + t.length), 10 + 11);
    });

    test(
      'dos pausas dan tres trozos y una pausa abierta no deja uno vacío',
      () {
        final tres = rutaVisual(crudos, TipoActividad.correr, [
          pausa(8, 12),
          pausa(20, 24),
        ]);
        expect(tres.length, 3);
        final abierta = rutaVisual(crudos, TipoActividad.correr, [pausa(15)]);
        expect(abierta.length, 1);
        expect(
          abierta.single.last.instante,
          _t0.add(const Duration(seconds: 14)),
        );
      },
    );

    test('una pausa sin puntos dentro también corta la línea', () {
      final salteados = [
        crudos[0],
        crudos[1],
        crudos[2],
        crudos[20],
        crudos[21],
      ];
      final trozos = rutaVisual(salteados, TipoActividad.correr, [
        pausa(5, 15),
      ]);
      expect(trozos.length, 2);
    });

    test('la pausa descanso se trata igual que la manual', () {
      final descanso = PausaCarrera(
        inicio: _t0.add(const Duration(seconds: 10)),
        fin: _t0.add(const Duration(seconds: 20)),
        descanso: true,
      );
      expect(rutaVisual(crudos, TipoActividad.correr, [descanso]).length, 2);
    });
  });
}
