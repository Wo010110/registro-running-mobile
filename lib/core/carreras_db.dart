import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/tipo_actividad.dart';
import 'carrera_calculos.dart';

enum EstadoCarrera { grabando, pausada, terminada }

const origenApp = 'app';
const origenPrueba = 'prueba';

class CarreraLocal {
  const CarreraLocal({
    required this.id,
    required this.tipo,
    required this.origen,
    required this.estado,
    required this.inicioUtc,
    required this.finUtc,
    required this.distanciaM,
    required this.tiempoMovimientoS,
    required this.sincronizada,
    required this.creadoUtc,
  });

  factory CarreraLocal.desdeFila(Map<String, Object?> f) => CarreraLocal(
    id: f['id']! as String,
    tipo: TipoActividad.desdeValor(f['tipo']! as String),
    origen: f['origen']! as String,
    estado: EstadoCarrera.values.byName(f['estado']! as String),
    inicioUtc: DateTime.parse(f['inicio_utc']! as String),
    finUtc: f['fin_utc'] == null
        ? null
        : DateTime.parse(f['fin_utc']! as String),
    distanciaM: (f['distancia_m']! as num).toDouble(),
    tiempoMovimientoS: f['tiempo_movimiento_s']! as int,
    sincronizada: f['sincronizada'] == 1,
    creadoUtc: DateTime.parse(f['creado_utc']! as String),
  );

  final String id;
  final TipoActividad tipo;

  /// [origenApp] o [origenPrueba].
  final String origen;
  final EstadoCarrera estado;
  final DateTime inicioUtc;
  final DateTime? finUtc;
  final double distanciaM;
  final int tiempoMovimientoS;
  final bool sincronizada;
  final DateTime creadoUtc;
}

/// Base local de carreras. Cada punto se escribe al llegar: si el sistema
/// mata o congela la app, lo grabado hasta ese instante ya está en disco.
class CarrerasDb {
  CarrerasDb._(this._db);

  static const _version = 2;

  final Database _db;

  /// [ruta] solo se pasa en pruebas (p. ej. `inMemoryDatabasePath`).
  static Future<CarrerasDb> abrir({String? ruta}) async {
    final db = await openDatabase(
      ruta ?? p.join(await getDatabasesPath(), 'heyrun.db'),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
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
        await db.execute(
          'CREATE INDEX idx_puntos_carrera ON puntos(carrera_id)',
        );
        await db.execute(
          'CREATE INDEX idx_pausas_carrera ON pausas(carrera_id)',
        );
      },
      // Una rama `if (viejo < N)` por versión.
      onUpgrade: (db, viejo, nuevo) async {
        if (viejo < 2) {
          await db.execute(
            "ALTER TABLE carreras ADD COLUMN origen TEXT NOT NULL DEFAULT 'app'",
          );
          // Todo lo de la v1 lo grabó la pantalla de prueba.
          await db.execute("UPDATE carreras SET origen = 'prueba'");
        }
      },
    );
    return CarrerasDb._(db);
  }

  Future<void> cerrar() => _db.close();

  Future<CarreraLocal> crearCarrera(
    TipoActividad tipo, {
    DateTime? inicio,
    String origen = origenApp,
  }) async {
    final ahora = (inicio ?? DateTime.now()).toUtc().toIso8601String();
    final fila = <String, Object?>{
      'id': const Uuid().v4(),
      'tipo': tipo.valor,
      'origen': origen,
      'estado': EstadoCarrera.grabando.name,
      'inicio_utc': ahora,
      'creado_utc': DateTime.now().toUtc().toIso8601String(),
    };
    await _db.insert('carreras', fila);
    return (await carrera(fila['id']! as String))!;
  }

  /// Escritura inmediata de un punto (aceptado o crudo).
  Future<void> insertarPunto(String carreraId, PuntoGps punto) => _db.rawInsert(
    '''INSERT INTO puntos (carrera_id, lat, lng, altitud, precision_m,
             velocidad, instante_utc, aceptado, indice)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?,
             (SELECT COALESCE(MAX(indice), -1) + 1 FROM puntos
              WHERE carrera_id = ?))''',
    [
      carreraId,
      punto.lat,
      punto.lng,
      punto.altitud,
      punto.precisionM,
      punto.velocidad,
      punto.instante.toIso8601String(),
      punto.aceptado ? 1 : 0,
      carreraId,
    ],
  );

  Future<void> pausar(String carreraId, {DateTime? ahora}) =>
      _db.transaction((tx) async {
        await tx.insert('pausas', {
          'carrera_id': carreraId,
          'inicio_utc': (ahora ?? DateTime.now()).toUtc().toIso8601String(),
        });
        await _estado(tx, carreraId, EstadoCarrera.pausada);
      });

  Future<void> reanudar(String carreraId, {DateTime? ahora}) =>
      _db.transaction((tx) async {
        await tx.update(
          'pausas',
          {'fin_utc': (ahora ?? DateTime.now()).toUtc().toIso8601String()},
          where: 'carrera_id = ? AND fin_utc IS NULL',
          whereArgs: [carreraId],
        );
        await _estado(tx, carreraId, EstadoCarrera.grabando);
      });

  /// Cierra la carrera (y la pausa abierta, si la hay) con los totales finales.
  Future<void> terminar(
    String carreraId, {
    required double distanciaM,
    required int tiempoMovimientoS,
    DateTime? fin,
  }) => _db.transaction((tx) async {
    final finIso = (fin ?? DateTime.now()).toUtc().toIso8601String();
    await tx.update(
      'pausas',
      {'fin_utc': finIso},
      where: 'carrera_id = ? AND fin_utc IS NULL',
      whereArgs: [carreraId],
    );
    await tx.update(
      'carreras',
      {
        'estado': EstadoCarrera.terminada.name,
        'fin_utc': finIso,
        'distancia_m': distanciaM,
        'tiempo_movimiento_s': tiempoMovimientoS,
      },
      where: 'id = ?',
      whereArgs: [carreraId],
    );
  });

  Future<void> _estado(
    DatabaseExecutor tx,
    String carreraId,
    EstadoCarrera estado,
  ) => tx.update(
    'carreras',
    {'estado': estado.name},
    where: 'id = ?',
    whereArgs: [carreraId],
  );

  Future<CarreraLocal?> carrera(String id) async {
    final filas = await _db.query('carreras', where: 'id = ?', whereArgs: [id]);
    return filas.isEmpty ? null : CarreraLocal.desdeFila(filas.first);
  }

  Future<List<PuntoGps>> puntos(String carreraId) async {
    final filas = await _db.query(
      'puntos',
      where: 'carrera_id = ?',
      whereArgs: [carreraId],
      orderBy: 'indice',
    );
    return [
      for (final f in filas)
        PuntoGps(
          lat: f['lat']! as double,
          lng: f['lng']! as double,
          altitud: f['altitud'] as double?,
          precisionM: f['precision_m']! as double,
          velocidad: f['velocidad'] as double?,
          instante: DateTime.parse(f['instante_utc']! as String),
          aceptado: f['aceptado'] == 1,
        ),
    ];
  }

  Future<List<PausaCarrera>> pausas(String carreraId) async {
    final filas = await _db.query(
      'pausas',
      where: 'carrera_id = ?',
      whereArgs: [carreraId],
      orderBy: 'inicio_utc',
    );
    return [
      for (final f in filas)
        PausaCarrera(
          inicio: DateTime.parse(f['inicio_utc']! as String),
          fin: f['fin_utc'] == null
              ? null
              : DateTime.parse(f['fin_utc']! as String),
        ),
    ];
  }

  /// Carrera de [origen] que quedó grabando o en pausa (la app se cerró): se
  /// ofrece recuperarla al reabrir.
  Future<CarreraLocal?> carreraSinTerminar({String origen = origenApp}) async {
    final filas = await _db.query(
      'carreras',
      where: 'estado != ? AND origen = ?',
      whereArgs: [EstadoCarrera.terminada.name, origen],
      orderBy: 'creado_utc DESC',
      limit: 1,
    );
    return filas.isEmpty ? null : CarreraLocal.desdeFila(filas.first);
  }

  /// Actividades cerradas de [origen], de la más reciente a la más antigua.
  Future<List<CarreraLocal>> terminadas({String origen = origenApp}) async {
    final filas = await _db.query(
      'carreras',
      where: 'estado = ? AND origen = ?',
      whereArgs: [EstadoCarrera.terminada.name, origen],
      orderBy: 'inicio_utc DESC',
    );
    return [for (final f in filas) CarreraLocal.desdeFila(f)];
  }

  /// Borra la carrera con sus puntos y pausas.
  Future<void> descartar(String carreraId) =>
      _db.delete('carreras', where: 'id = ?', whereArgs: [carreraId]);
}
