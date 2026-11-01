import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/core/formato.dart';
import 'package:heyrun_mobile/core/historial.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CarreraLocal _carrera(DateTime local, double distanciaM, {int s = 600}) =>
    CarreraLocal(
      id: local.toIso8601String(),
      tipo: TipoActividad.correr,
      origen: origenApp,
      estado: EstadoCarrera.terminada,
      inicioUtc: local.toUtc(),
      finUtc: local.toUtc().add(Duration(seconds: s)),
      distanciaM: distanciaM,
      tiempoMovimientoS: s,
      sincronizada: false,
      creadoUtc: local.toUtc(),
    );

PuntoGps _punto(double lat, double lng, {bool aceptado = true}) => PuntoGps(
  lat: lat,
  lng: lng,
  precisionM: 5,
  instante: DateTime.utc(2026, 1, 1),
  aceptado: aceptado,
);

void main() {
  // Miércoles 28 de octubre de 2026.
  final ahora = DateTime(2026, 10, 28, 12);

  test('km por día: semana de lunes a domingo, hora local', () {
    final km = kmPorDiaSemana([
      _carrera(DateTime(2026, 10, 26, 6), 5000), // lunes
      _carrera(DateTime(2026, 10, 26, 19), 2500), // lunes
      _carrera(DateTime(2026, 10, 28, 7), 10000), // miércoles
      _carrera(DateTime(2026, 10, 25, 7), 8000), // domingo anterior: fuera
      _carrera(DateTime(2026, 11, 2, 7), 3000), // lunes siguiente: fuera
    ], ahora);
    expect(km, [7.5, 0, 10, 0, 0, 0, 0]);
  });

  test('km por día: domingo cuenta en la semana que termina', () {
    final km = kmPorDiaSemana([
      _carrera(DateTime(2026, 11, 1, 7), 4000),
    ], DateTime(2026, 11, 1, 20));
    expect(km, [0, 0, 0, 0, 0, 0, 4]);
  });

  test('título según tipo y franja del día', () {
    expect(
      tituloActividad(TipoActividad.correr, DateTime(2026, 1, 1, 6).toUtc()),
      'Carrera de la mañana',
    );
    expect(
      tituloActividad(TipoActividad.caminar, DateTime(2026, 1, 1, 18).toUtc()),
      'Caminata de la tarde',
    );
    expect(
      tituloActividad(TipoActividad.correr, DateTime(2026, 1, 1, 21).toUtc()),
      'Carrera de la noche',
    );
    expect(
      tituloActividad(TipoActividad.correr, DateTime(2026, 1, 1, 4).toUtc()),
      'Carrera de la madrugada',
    );
  });

  test('ritmo medio: s/km y sin dato si hay menos de 100 m', () {
    expect(ritmoMedioSKm(_carrera(ahora, 5000, s: 1500)), 300);
    expect(ritmoMedioSKm(_carrera(ahora, 50)), isNull);
  });

  test('fecha: hoy, ayer, otro día y otro año', () {
    String f(DateTime d) => formatearFechaActividad(d.toUtc(), ahora);
    expect(f(DateTime(2026, 10, 28, 6, 12)), 'Hoy · 6:12');
    expect(f(DateTime(2026, 10, 27, 18, 30)), 'Ayer · 18:30');
    expect(f(DateTime(2026, 10, 25, 7)), 'Dom 25 oct · 7:00');
    expect(f(DateTime(2025, 12, 31, 23, 5)), 'Mié 31 dic 2025 · 23:05');
  });

  test('km con un decimal y coma', () {
    expect(formatearKmUno(0), '0,0');
    expect(formatearKmUno(23.74), '23,7');
  });

  group('trazo normalizado', () {
    test('sin puntos suficientes o sin movimiento no dibuja', () {
      expect(trazoNormalizado([]), isEmpty);
      expect(trazoNormalizado([_punto(4, -74)]), isEmpty);
      expect(trazoNormalizado([_punto(4, -74), _punto(4, -74)]), isEmpty);
    });

    test('ignora los puntos no aceptados', () {
      final t = trazoNormalizado([
        _punto(4, -74),
        _punto(9, -70, aceptado: false),
        _punto(4.001, -74),
      ]);
      expect(t, hasLength(2));
    });

    test('queda dentro de 0 a 1 y conserva el orden', () {
      final t = trazoNormalizado([
        for (var i = 0; i < 100; i++) _punto(4 + i / 10000, -74 + i / 10000),
      ]);
      expect(t.length, lessThanOrEqualTo(61));
      for (final (x, y) in t) {
        expect(x, inInclusiveRange(0, 1));
        expect(y, inInclusiveRange(0, 1));
      }
      // Hacia el norte (lat sube) y el este: la Y baja y la X sube.
      expect(t.last.$1, greaterThan(t.first.$1));
      expect(t.last.$2, lessThan(t.first.$2));
    });

    test('una ruta vertical se centra y no se estira a lo ancho', () {
      final t = trazoNormalizado([_punto(4, -74), _punto(4.01, -74)]);
      expect(t.first.$1, closeTo(.5, 1e-9));
      expect(t.last.$1, closeTo(.5, 1e-9));
      expect(t.first.$2, closeTo(1, 1e-9));
      expect(t.last.$2, closeTo(0, 1e-9));
    });
  });

  group('CarrerasDb.terminadas', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late CarrerasDb db;
    setUp(() async => db = await CarrerasDb.abrir(ruta: inMemoryDatabasePath));
    tearDown(() => db.cerrar());

    test('solo cerradas y de la app, la más reciente primero', () async {
      final vieja = await db.crearCarrera(
        TipoActividad.correr,
        inicio: DateTime.utc(2026, 10, 20, 8),
      );
      final nueva = await db.crearCarrera(
        TipoActividad.caminar,
        inicio: DateTime.utc(2026, 10, 27, 8),
      );
      final abierta = await db.crearCarrera(
        TipoActividad.correr,
        inicio: DateTime.utc(2026, 10, 28, 8),
      );
      final prueba = await db.crearCarrera(
        TipoActividad.correr,
        inicio: DateTime.utc(2026, 10, 29, 8),
        origen: origenPrueba,
      );
      for (final c in [vieja, nueva, prueba]) {
        await db.terminar(c.id, distanciaM: 1000, tiempoMovimientoS: 300);
      }

      final lista = await db.terminadas();
      expect(lista.map((c) => c.id), [nueva.id, vieja.id]);
      expect(lista.any((c) => c.id == abierta.id), isFalse);
      expect(
        (await db.terminadas(origen: origenPrueba)).map((c) => c.id),
        [prueba.id],
      );
    });

    test('vacía si no hay actividades', () async {
      expect(await db.terminadas(), isEmpty);
    });
  });
}
