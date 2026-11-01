import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PuntoGps _punto(int s, {bool aceptado = true}) => PuntoGps(
  lat: 4 + s / 100000,
  lng: -74,
  altitud: 2550,
  precisionM: 5,
  velocidad: 3,
  instante: DateTime.utc(2026, 1, 1, 8, 0, s),
  aceptado: aceptado,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late CarrerasDb db;
  setUp(() async => db = await CarrerasDb.abrir(ruta: inMemoryDatabasePath));
  tearDown(() => db.cerrar());

  test('crear carrera: grabando, sin fin y sin sincronizar', () async {
    final c = await db.crearCarrera(TipoActividad.correr);
    expect(c.tipo, TipoActividad.correr);
    expect(c.estado, EstadoCarrera.grabando);
    expect(c.finUtc, isNull);
    expect(c.sincronizada, isFalse);
    expect(c.inicioUtc.isUtc, isTrue);
    expect((await db.carrera(c.id))!.id, c.id);
    expect(await db.carrera('no-existe'), isNull);
  });

  test('el tipo caminar se guarda y se lee', () async {
    final c = await db.crearCarrera(TipoActividad.caminar);
    expect(c.tipo, TipoActividad.caminar);
    expect((await db.carrera(c.id))!.tipo, TipoActividad.caminar);
  });

  test('los puntos se leen en orden con sus campos y el aceptado', () async {
    final c = await db.crearCarrera(TipoActividad.correr);
    await db.insertarPunto(c.id, _punto(0));
    await db.insertarPunto(c.id, _punto(1, aceptado: false));
    await db.insertarPunto(c.id, _punto(2));
    final puntos = await db.puntos(c.id);
    expect(puntos.map((x) => x.aceptado), [true, false, true]);
    expect(puntos.last.instante, DateTime.utc(2026, 1, 1, 8, 0, 2));
    expect(puntos.first.altitud, 2550);
    expect(puntos.first.velocidad, 3);
  });

  test('pausar y reanudar guardan el intervalo y el estado', () async {
    final c = await db.crearCarrera(TipoActividad.correr);
    await db.pausar(c.id, ahora: DateTime.utc(2026, 1, 1, 8, 5));
    expect((await db.carrera(c.id))!.estado, EstadoCarrera.pausada);
    expect((await db.pausas(c.id)).single.fin, isNull);
    await db.reanudar(c.id, ahora: DateTime.utc(2026, 1, 1, 8, 6));
    expect((await db.carrera(c.id))!.estado, EstadoCarrera.grabando);
    final pausa = (await db.pausas(c.id)).single;
    expect(pausa.inicio, DateTime.utc(2026, 1, 1, 8, 5));
    expect(pausa.fin, DateTime.utc(2026, 1, 1, 8, 6));
  });

  test('terminar guarda totales, fin y cierra la pausa abierta', () async {
    final c = await db.crearCarrera(TipoActividad.correr);
    await db.pausar(c.id);
    await db.terminar(c.id, distanciaM: 5012.5, tiempoMovimientoS: 1500);
    final t = (await db.carrera(c.id))!;
    expect(t.estado, EstadoCarrera.terminada);
    expect(t.finUtc, isNotNull);
    expect(t.distanciaM, 5012.5);
    expect(t.tiempoMovimientoS, 1500);
    expect((await db.pausas(c.id)).single.fin, isNotNull);
    expect(await db.carreraSinTerminar(), isNull);
  });

  test('descartar borra la carrera con sus puntos y pausas', () async {
    final c = await db.crearCarrera(TipoActividad.correr);
    await db.insertarPunto(c.id, _punto(0));
    await db.pausar(c.id);
    await db.descartar(c.id);
    expect(await db.carrera(c.id), isNull);
    expect(await db.puntos(c.id), isEmpty);
    expect(await db.pausas(c.id), isEmpty);
  });

  test('tras un cierre simulado se recupera la carrera grabando', () async {
    final dir = await Directory.systemTemp.createTemp('heyrun_db');
    addTearDown(() => dir.delete(recursive: true));
    final ruta = p.join(dir.path, 'prueba.db');

    var abierta = await CarrerasDb.abrir(ruta: ruta);
    final c = await abierta.crearCarrera(TipoActividad.caminar);
    await abierta.insertarPunto(c.id, _punto(0));
    await abierta.insertarPunto(c.id, _punto(1));
    await abierta.cerrar(); // la app muere sin terminar

    abierta = await CarrerasDb.abrir(ruta: ruta);
    final pendiente = await abierta.carreraSinTerminar();
    expect(pendiente!.id, c.id);
    expect(pendiente.estado, EstadoCarrera.grabando);
    expect(pendiente.tipo, TipoActividad.caminar);
    expect((await abierta.puntos(c.id)).length, 2);
    await abierta.cerrar();
  });

  test('la recuperación solo mira las carreras de origen app', () async {
    final prueba = await db.crearCarrera(
      TipoActividad.correr,
      origen: origenPrueba,
    );
    expect(prueba.origen, origenPrueba);
    expect(await db.carreraSinTerminar(), isNull);
    expect((await db.carreraSinTerminar(origen: origenPrueba))!.id, prueba.id);
    final real = await db.crearCarrera(TipoActividad.correr);
    expect(real.origen, origenApp);
    expect((await db.carreraSinTerminar())!.id, real.id);
  });

  test('migra de la v1 a la v2 conservando los datos', () async {
    final dir = await Directory.systemTemp.createTemp('heyrun_v1');
    addTearDown(() => dir.delete(recursive: true));
    final ruta = p.join(dir.path, 'v1.db');

    // Esquema y datos tal como los dejó la v1 instalada en el teléfono.
    final v1 = await openDatabase(
      ruta,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE carreras (
            id TEXT PRIMARY KEY,
            tipo TEXT NOT NULL DEFAULT 'correr',
            estado TEXT NOT NULL,
            inicio_utc TEXT NOT NULL,
            fin_utc TEXT,
            distancia_m REAL NOT NULL DEFAULT 0,
            tiempo_movimiento_s INTEGER NOT NULL DEFAULT 0,
            sincronizada INTEGER NOT NULL DEFAULT 0,
            creado_utc TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE puntos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            carrera_id TEXT NOT NULL
              REFERENCES carreras(id) ON DELETE CASCADE,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            altitud REAL,
            precision_m REAL NOT NULL,
            velocidad REAL,
            instante_utc TEXT NOT NULL,
            aceptado INTEGER NOT NULL,
            indice INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE pausas (
            carrera_id TEXT NOT NULL
              REFERENCES carreras(id) ON DELETE CASCADE,
            inicio_utc TEXT NOT NULL,
            fin_utc TEXT
          )''');
      },
    );
    for (final (id, estado) in [('a', 'terminada'), ('b', 'grabando')]) {
      await v1.insert('carreras', {
        'id': id,
        'tipo': 'caminar',
        'estado': estado,
        'inicio_utc': '2026-01-01T08:00:00.000Z',
        'creado_utc': '2026-01-01T08:00:00.000Z',
      });
    }
    await v1.insert('puntos', {
      'carrera_id': 'a',
      'lat': 4.0,
      'lng': -74.0,
      'precision_m': 5.0,
      'instante_utc': '2026-01-01T08:00:00.000Z',
      'aceptado': 1,
      'indice': 0,
    });
    await v1.close();

    final migrada = await CarrerasDb.abrir(ruta: ruta);
    final a = (await migrada.carrera('a'))!;
    expect(a.tipo, TipoActividad.caminar);
    expect(a.estado, EstadoCarrera.terminada);
    expect((await migrada.puntos('a')).length, 1);
    // Lo de la v1 lo grabó la prueba: la recuperación de la app no lo ofrece.
    expect(a.origen, origenPrueba);
    expect(await migrada.carreraSinTerminar(), isNull);
    expect((await migrada.carreraSinTerminar(origen: origenPrueba))!.id, 'b');
    final nueva = await migrada.crearCarrera(TipoActividad.correr);
    expect(nueva.origen, origenApp);
    await migrada.cerrar();
  });

  test('guarda el modo al crear la carrera; null es libre', () async {
    final libre = await db.crearCarrera(TipoActividad.correr);
    expect(libre.modo, isNull);
    final c = await db.crearCarrera(
      TipoActividad.correr,
      modo: const ModoIntervalos(tramo: 800, repeticiones: null),
    );
    final leida = (await db.carrera(c.id))!.modo! as ModoIntervalos;
    expect(leida.tramo, 800);
    expect(leida.repeticiones, isNull);
    // Un modo libre explícito tampoco se guarda.
    final otra = await db.crearCarrera(
      TipoActividad.correr,
      modo: const ModoLibre(),
    );
    expect((await db.carrera(otra.id))!.modo, isNull);
  });

  test('la pausa recuerda si fue manual o un descanso', () async {
    final c = await db.crearCarrera(TipoActividad.correr);
    await db.pausar(c.id, ahora: DateTime.utc(2026, 1, 1, 8, 1));
    await db.reanudar(c.id, ahora: DateTime.utc(2026, 1, 1, 8, 2));
    await db.pausar(
      c.id,
      ahora: DateTime.utc(2026, 1, 1, 8, 3),
      descanso: true,
    );
    final pausas = await db.pausas(c.id);
    expect(pausas.map((p) => p.descanso), [false, true]);
    expect(pausas.last.fin, isNull);
  });

  test('migra de la v2 a la v3 conservando los datos', () async {
    final dir = await Directory.systemTemp.createTemp('heyrun_v2');
    addTearDown(() => dir.delete(recursive: true));
    final ruta = p.join(dir.path, 'v2.db');

    // Esquema y datos tal como los dejó la v2 instalada en el teléfono.
    final v2 = await openDatabase(
      ruta,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE carreras (
            id TEXT PRIMARY KEY,
            tipo TEXT NOT NULL DEFAULT 'correr',
            origen TEXT NOT NULL DEFAULT 'app',
            estado TEXT NOT NULL,
            inicio_utc TEXT NOT NULL,
            fin_utc TEXT,
            distancia_m REAL NOT NULL DEFAULT 0,
            tiempo_movimiento_s INTEGER NOT NULL DEFAULT 0,
            sincronizada INTEGER NOT NULL DEFAULT 0,
            creado_utc TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE puntos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            carrera_id TEXT NOT NULL
              REFERENCES carreras(id) ON DELETE CASCADE,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            altitud REAL,
            precision_m REAL NOT NULL,
            velocidad REAL,
            instante_utc TEXT NOT NULL,
            aceptado INTEGER NOT NULL,
            indice INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE pausas (
            carrera_id TEXT NOT NULL
              REFERENCES carreras(id) ON DELETE CASCADE,
            inicio_utc TEXT NOT NULL,
            fin_utc TEXT
          )''');
      },
    );
    await v2.insert('carreras', {
      'id': 'a',
      'tipo': 'correr',
      'origen': 'app',
      'estado': 'terminada',
      'inicio_utc': '2026-01-01T08:00:00.000Z',
      'distancia_m': 5000.0,
      'tiempo_movimiento_s': 1500,
      'creado_utc': '2026-01-01T08:00:00.000Z',
    });
    await v2.insert('puntos', {
      'carrera_id': 'a',
      'lat': 4.0,
      'lng': -74.0,
      'precision_m': 5.0,
      'instante_utc': '2026-01-01T08:00:00.000Z',
      'aceptado': 1,
      'indice': 0,
    });
    await v2.insert('pausas', {
      'carrera_id': 'a',
      'inicio_utc': '2026-01-01T08:10:00.000Z',
      'fin_utc': '2026-01-01T08:11:00.000Z',
    });
    await v2.close();

    final migrada = await CarrerasDb.abrir(ruta: ruta);
    final a = (await migrada.carrera('a'))!;
    expect(a.origen, origenApp);
    expect(a.distanciaM, 5000);
    expect(a.modo, isNull); // lo anterior era libre
    expect((await migrada.puntos('a')).length, 1);
    final pausa = (await migrada.pausas('a')).single;
    expect(pausa.fin, DateTime.utc(2026, 1, 1, 8, 11));
    expect(pausa.descanso, isFalse); // lo anterior eran pausas manuales

    // Con lo nuevo funcionando sobre la base migrada.
    final nueva = await migrada.crearCarrera(
      TipoActividad.correr,
      modo: const ModoMeta(valor: 10000),
    );
    expect((await migrada.carrera(nueva.id))!.modo, isA<ModoMeta>());
    await migrada.pausar(nueva.id, descanso: true);
    expect((await migrada.pausas(nueva.id)).single.descanso, isTrue);
    await migrada.cerrar();

    final cruda = await openDatabase(ruta);
    final columnas = [
      for (final t in ['carreras', 'pausas'])
        for (final f in await cruda.rawQuery('PRAGMA table_info($t)'))
          '$t.${f['name']}',
    ];
    expect(columnas, containsAll(['carreras.modo', 'pausas.motivo']));
    expect(await cruda.getVersion(), 4);
    await cruda.close();
  });

  test(
    'actualizarDetalles escribe todo y cambiar el tipo no toca los totales',
    () async {
      final c = await db.crearCarrera(TipoActividad.correr);
      await db.terminar(c.id, distanciaM: 5012.5, tiempoMovimientoS: 1500);
      await db.actualizarDetalles(
        c.id,
        titulo: 'Rodaje',
        descripcion: 'Piernas pesadas',
        intensidad: 4,
        tipo: TipoActividad.caminar,
      );
      final a = (await db.carrera(c.id))!;
      expect(a.titulo, 'Rodaje');
      expect(a.descripcion, 'Piernas pesadas');
      expect(a.intensidad, 4);
      expect(a.tipo, TipoActividad.caminar);
      expect(a.distanciaM, 5012.5);
      expect(a.tiempoMovimientoS, 1500);
      expect(a.estado, EstadoCarrera.terminada);

      // Null deja el campo sin valor (título propuesto, sin marcar).
      await db.actualizarDetalles(c.id, tipo: TipoActividad.correr);
      final b = (await db.carrera(c.id))!;
      expect(b.titulo, isNull);
      expect(b.descripcion, isNull);
      expect(b.intensidad, isNull);
      expect(b.tipo, TipoActividad.correr);
      expect(b.distanciaM, 5012.5);
    },
  );

  test('migra de la v3 a la v4 conservando los datos', () async {
    final dir = await Directory.systemTemp.createTemp('heyrun_v3');
    addTearDown(() => dir.delete(recursive: true));
    final ruta = p.join(dir.path, 'v3.db');

    // Esquema y datos tal como los dejó la v3 instalada en el teléfono.
    final v3 = await openDatabase(
      ruta,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE carreras (
            id TEXT PRIMARY KEY,
            tipo TEXT NOT NULL DEFAULT 'correr',
            origen TEXT NOT NULL DEFAULT 'app',
            estado TEXT NOT NULL,
            inicio_utc TEXT NOT NULL,
            fin_utc TEXT,
            distancia_m REAL NOT NULL DEFAULT 0,
            tiempo_movimiento_s INTEGER NOT NULL DEFAULT 0,
            sincronizada INTEGER NOT NULL DEFAULT 0,
            creado_utc TEXT NOT NULL,
            modo TEXT
          )''');
        await db.execute('''
          CREATE TABLE puntos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            carrera_id TEXT NOT NULL
              REFERENCES carreras(id) ON DELETE CASCADE,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            altitud REAL,
            precision_m REAL NOT NULL,
            velocidad REAL,
            instante_utc TEXT NOT NULL,
            aceptado INTEGER NOT NULL,
            indice INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE pausas (
            carrera_id TEXT NOT NULL
              REFERENCES carreras(id) ON DELETE CASCADE,
            inicio_utc TEXT NOT NULL,
            fin_utc TEXT,
            motivo TEXT NOT NULL DEFAULT 'manual'
          )''');
      },
    );
    await v3.insert('carreras', {
      'id': 'a',
      'tipo': 'caminar',
      'origen': 'app',
      'estado': 'terminada',
      'inicio_utc': '2026-01-01T08:00:00.000Z',
      'distancia_m': 5000.0,
      'tiempo_movimiento_s': 1500,
      'creado_utc': '2026-01-01T08:00:00.000Z',
      'modo':
          '{"modo":"meta","medida":"distancia","valor":5000,"alLlegar":"avisar"}',
    });
    await v3.insert('puntos', {
      'carrera_id': 'a',
      'lat': 4.0,
      'lng': -74.0,
      'precision_m': 5.0,
      'instante_utc': '2026-01-01T08:00:00.000Z',
      'aceptado': 1,
      'indice': 0,
    });
    await v3.insert('pausas', {
      'carrera_id': 'a',
      'inicio_utc': '2026-01-01T08:10:00.000Z',
      'fin_utc': '2026-01-01T08:11:00.000Z',
      'motivo': 'descanso',
    });
    await v3.close();

    final migrada = await CarrerasDb.abrir(ruta: ruta);
    final a = (await migrada.carrera('a'))!;
    expect(a.tipo, TipoActividad.caminar);
    expect(a.distanciaM, 5000);
    expect(a.modo, isA<ModoMeta>());
    expect(a.titulo, isNull);
    expect(a.descripcion, isNull);
    expect(a.intensidad, isNull);
    expect((await migrada.puntos('a')).length, 1);
    expect((await migrada.pausas('a')).single.descanso, isTrue);

    await migrada.actualizarDetalles(
      'a',
      titulo: 'Mi caminata',
      intensidad: 2,
      tipo: TipoActividad.caminar,
    );
    expect((await migrada.carrera('a'))!.titulo, 'Mi caminata');
    await migrada.cerrar();

    final cruda = await openDatabase(ruta);
    final columnas = [
      for (final f in await cruda.rawQuery('PRAGMA table_info(carreras)'))
        '${f['name']}',
    ];
    expect(columnas, containsAll(['titulo', 'descripcion', 'intensidad']));
    expect(await cruda.getVersion(), 4);
    // Sin tabla de fotos.
    final tablas = [
      for (final t in await cruda.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        '${t['name']}',
    ];
    expect(tablas, isNot(contains('fotos')));
    await cruda.close();
  });
}
