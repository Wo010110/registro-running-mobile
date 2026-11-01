import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/modo_actividad.dart';
import '../models/tipo_actividad.dart';
import 'carrera_calculos.dart';

enum EstadoCarrera { grabando, pausada, terminada }

const origenApp = 'app';
const origenPrueba = 'prueba';

const motivoManual = 'manual';
const motivoDescanso = 'descanso';

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
    this.modo,
    this.titulo,
    this.descripcion,
    this.intensidad,
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
    modo: ModoActividad.desdeTexto(f['modo'] as String?),
    titulo: f['titulo'] as String?,
    descripcion: f['descripcion'] as String?,
    intensidad: f['intensidad'] as int?,
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

  /// null = libre.
  final ModoActividad? modo;

  /// null = el propuesto por [tituloActividad].
  final String? titulo;
  final String? descripcion;

  /// 1 a 5; null = sin marcar.
  final int? intensidad;
}

/// Mejor tiempo en una distancia y la actividad donde se hizo.
class RecordPersonal {
  const RecordPersonal({
    required this.objetivoM,
    required this.tiempoS,
    required this.carreraId,
    required this.inicioUtc,
  });

  final double objetivoM;
  final double tiempoS;
  final String carreraId;
  final DateTime inicioUtc;

  /// Ritmo medio del récord, en segundos por km.
  double get ritmoSKm => tiempoS / (objetivoM / 1000);
}

/// Base local de carreras. Cada punto se escribe al llegar: si el sistema
/// mata o congela la app, lo grabado hasta ese instante ya está en disco.
class CarrerasDb {
  CarrerasDb._(this._db);

  static const _version = 5;

  static const _crearTramos = '''
    CREATE TABLE tramos_carrera (
      carrera_id TEXT NOT NULL
        REFERENCES carreras(id) ON DELETE CASCADE,
      objetivo_m REAL NOT NULL,
      tiempo_s REAL NOT NULL,
      PRIMARY KEY (carrera_id, objetivo_m)
    )''';

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
            creado_utc TEXT NOT NULL,
            modo TEXT,
            titulo TEXT,
            descripcion TEXT,
            intensidad INTEGER,
            tramos_calculados INTEGER NOT NULL DEFAULT 0
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
        await db.execute(_crearTramos);
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
        if (viejo < 3) {
          // motivo: 'manual' o 'descanso' (pausa automática de los intervalos).
          await db.execute(
            "ALTER TABLE pausas ADD COLUMN motivo TEXT NOT NULL DEFAULT 'manual'",
          );
          await db.execute('ALTER TABLE carreras ADD COLUMN modo TEXT');
        }
        if (viejo < 4) {
          await db.execute('ALTER TABLE carreras ADD COLUMN titulo TEXT');
          await db.execute('ALTER TABLE carreras ADD COLUMN descripcion TEXT');
          await db.execute(
            'ALTER TABLE carreras ADD COLUMN intensidad INTEGER',
          );
        }
        if (viejo < 5) {
          // Mejores tiempos por distancia de cada actividad (récords); las
          // anteriores se calculan una vez, ver carrerasSinTramos.
          await db.execute(_crearTramos);
          await db.execute(
            'ALTER TABLE carreras ADD COLUMN tramos_calculados INTEGER NOT NULL DEFAULT 0',
          );
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
    ModoActividad? modo,
  }) async {
    final ahora = (inicio ?? DateTime.now()).toUtc().toIso8601String();
    final fila = <String, Object?>{
      'id': const Uuid().v4(),
      'tipo': tipo.valor,
      'origen': origen,
      'estado': EstadoCarrera.grabando.name,
      'inicio_utc': ahora,
      'creado_utc': DateTime.now().toUtc().toIso8601String(),
      'modo': modo?.aTexto(),
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

  /// [descanso]: pausa automática de los intervalos, no del usuario.
  Future<void> pausar(
    String carreraId, {
    DateTime? ahora,
    bool descanso = false,
  }) => _db.transaction((tx) async {
    await tx.insert('pausas', {
      'carrera_id': carreraId,
      'inicio_utc': (ahora ?? DateTime.now()).toUtc().toIso8601String(),
      'motivo': descanso ? motivoDescanso : motivoManual,
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

  /// Lo que el usuario edita de una actividad. Escribe todo junto; null en
  /// [titulo], [descripcion] o [intensidad] los deja sin valor. Cambiar el
  /// [tipo] solo cambia la etiqueta: no recalcula distancia ni tiempo.
  Future<void> actualizarDetalles(
    String carreraId, {
    String? titulo,
    String? descripcion,
    int? intensidad,
    required TipoActividad tipo,
  }) => _db.transaction((tx) async {
    await tx.update(
      'carreras',
      {
        'titulo': titulo,
        'descripcion': descripcion,
        'intensidad': intensidad,
        'tipo': tipo.valor,
      },
      where: 'id = ?',
      whereArgs: [carreraId],
    );
  });

  /// Guarda los mejores tramos de la carrera (reemplaza los anteriores) y la
  /// marca como calculada, aunque no haya ninguno.
  Future<void> guardarTramos(String carreraId, Map<double, double> tramos) =>
      _db.transaction((tx) async {
        await tx.delete(
          'tramos_carrera',
          where: 'carrera_id = ?',
          whereArgs: [carreraId],
        );
        for (final e in tramos.entries) {
          await tx.insert('tramos_carrera', {
            'carrera_id': carreraId,
            'objetivo_m': e.key,
            'tiempo_s': e.value,
          });
        }
        await tx.update(
          'carreras',
          {'tramos_calculados': 1},
          where: 'id = ?',
          whereArgs: [carreraId],
        );
      });

  /// Actividades terminadas de la app a las que aún no se les calcularon los
  /// tramos (las grabadas antes de existir los récords).
  Future<List<CarreraLocal>> carrerasSinTramos() async {
    final filas = await _db.query(
      'carreras',
      where: 'estado = ? AND origen = ? AND tramos_calculados = 0',
      whereArgs: [EstadoCarrera.terminada.name, origenApp],
      orderBy: 'inicio_utc',
    );
    return [for (final f in filas) CarreraLocal.desdeFila(f)];
  }

  /// El mejor tiempo de cada distancia, solo de actividades de correr
  /// terminadas y grabadas con la app.
  Future<Map<double, RecordPersonal>> mejoresRecords() async {
    final filas = await _db.rawQuery('''
      SELECT t.objetivo_m, t.tiempo_s, c.id, c.inicio_utc
      FROM tramos_carrera t JOIN carreras c ON c.id = t.carrera_id
      WHERE c.tipo = 'correr' AND c.origen = 'app' AND c.estado = 'terminada'
      ORDER BY t.objetivo_m, t.tiempo_s, c.inicio_utc''');
    final mejores = <double, RecordPersonal>{};
    for (final f in filas) {
      final objetivo = (f['objetivo_m']! as num).toDouble();
      mejores.putIfAbsent(
        objetivo,
        () => RecordPersonal(
          objetivoM: objetivo,
          tiempoS: (f['tiempo_s']! as num).toDouble(),
          carreraId: f['id']! as String,
          inicioUtc: DateTime.parse(f['inicio_utc']! as String),
        ),
      );
    }
    return mejores;
  }

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
          descanso: f['motivo'] == motivoDescanso,
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
