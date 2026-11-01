import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/avisos.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/core/fuente_posiciones.dart';
import 'package:heyrun_mobile/core/motor_modos.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _t0 = DateTime.utc(2026, 1, 1, 8);
const _mPorGrado = 111194.93;

/// Punto a 3 m/s hacia el norte en el segundo [s].
PuntoGps _punto(int s, {double precision = 2}) => PuntoGps(
  lat: 4 + 3.0 * s / _mPorGrado,
  lng: -74,
  precisionM: precision,
  instante: _t0.add(Duration(seconds: s)),
);

class _FuenteFalsa implements FuentePosiciones {
  final conServicio = <bool>[];
  final creados = <StreamController<PuntoGps>>[];
  // ignore: close_sinks
  final servicio = StreamController<bool>.broadcast(sync: true);
  // ignore: close_sinks
  StreamController<PuntoGps>? ultimo;

  /// Suscripciones vivas ahora mismo; nunca debe pasar de una.
  int get activas => creados.where((c) => !c.isClosed && c.hasListener).length;

  @override
  Stream<PuntoGps> escuchar({required bool conServicio}) {
    this.conServicio.add(conServicio);
    ultimo = StreamController<PuntoGps>(sync: true);
    creados.add(ultimo!);
    return ultimo!.stream;
  }

  @override
  Stream<bool> servicioHabilitado() => servicio.stream;

  void emitir(PuntoGps p) => ultimo!.add(p);
}

/// Anota los avisos en vez de sonar.
class _AvisadorFalso implements Avisador {
  final avisos = <Aviso>[];
  var precalentado = 0;

  @override
  Future<void> precalentar() async => precalentado++;

  @override
  Future<void> avisar(Aviso aviso) async => avisos.add(aviso);
}

class _CicloFalso extends CicloVida {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void poner(AppLifecycleState estado) => state = estado;
}

/// Base real que puede fallar al terminar y cuenta las terminaciones.
class _DbFalla implements CarrerasDb {
  _DbFalla(this.real);

  final CarrerasDb real;
  var fallosTerminar = 0;
  var terminaciones = 0;

  @override
  Future<void> terminar(
    String carreraId, {
    required double distanciaM,
    required int tiempoMovimientoS,
    DateTime? fin,
  }) async {
    terminaciones++;
    if (fallosTerminar > 0) {
      fallosTerminar--;
      throw Exception('disco');
    }
    return real.terminar(
      carreraId,
      distanciaM: distanciaM,
      tiempoMovimientoS: tiempoMovimientoS,
      fin: fin,
    );
  }

  @override
  Future<void> cerrar() => real.cerrar();
  @override
  Future<CarreraLocal> crearCarrera(
    TipoActividad tipo, {
    DateTime? inicio,
    String origen = origenApp,
    ModoActividad? modo,
  }) => real.crearCarrera(tipo, inicio: inicio, origen: origen, modo: modo);
  @override
  Future<void> insertarPunto(String carreraId, PuntoGps punto) =>
      real.insertarPunto(carreraId, punto);
  @override
  Future<void> pausar(
    String carreraId, {
    DateTime? ahora,
    bool descanso = false,
  }) => real.pausar(carreraId, ahora: ahora, descanso: descanso);
  @override
  Future<void> reanudar(String carreraId, {DateTime? ahora}) =>
      real.reanudar(carreraId, ahora: ahora);
  @override
  Future<void> actualizarDetalles(
    String carreraId, {
    String? titulo,
    String? descripcion,
    int? intensidad,
    required TipoActividad tipo,
  }) => real.actualizarDetalles(
    carreraId,
    titulo: titulo,
    descripcion: descripcion,
    intensidad: intensidad,
    tipo: tipo,
  );
  @override
  Future<CarreraLocal?> carrera(String id) => real.carrera(id);
  @override
  Future<List<PuntoGps>> puntos(String carreraId) => real.puntos(carreraId);
  @override
  Future<List<PausaCarrera>> pausas(String carreraId) => real.pausas(carreraId);
  @override
  Future<CarreraLocal?> carreraSinTerminar({String origen = origenApp}) =>
      real.carreraSinTerminar(origen: origen);
  @override
  Future<List<CarreraLocal>> terminadas({String origen = origenApp}) =>
      real.terminadas(origen: origen);
  @override
  Future<void> descartar(String carreraId) => real.descartar(carreraId);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late CarrerasDb db;
  late _DbFalla dbFalla;
  late _FuenteFalsa fuente;
  late _AvisadorFalso avisos;
  late DateTime reloj;
  late ProviderContainer c;

  setUp(() async {
    db = await CarrerasDb.abrir(ruta: inMemoryDatabasePath);
    dbFalla = _DbFalla(db);
    fuente = _FuenteFalsa();
    avisos = _AvisadorFalso();
    reloj = _t0;
    c = ProviderContainer(
      overrides: [
        carrerasDbProvider.overrideWithValue(dbFalla),
        fuentePosicionesProvider.overrideWithValue(fuente),
        avisadorProvider.overrideWithValue(avisos),
        relojProvider.overrideWithValue(() => reloj),
        cicloVidaProvider.overrideWith(_CicloFalso.new),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.cerrar();
  });

  GrabacionNotifier notifier() => c.read(grabacionProvider.notifier);
  GrabacionState estado() => c.read(grabacionProvider);
  int puntosRuta() => estado().ruta.fold(0, (n, t) => n + t.length);
  void ciclo(AppLifecycleState e) =>
      (c.read(cicloVidaProvider.notifier) as _CicloFalso).poner(e);

  /// Un punto por segundo de [desde] a [hasta], con el reloj en cada uno.
  void emitirTramo(int desde, int hasta) {
    for (var s = desde; s <= hasta; s++) {
      reloj = _t0.add(Duration(seconds: s));
      fuente.emitir(_punto(s));
    }
  }

  Future<void> iniciar([TipoActividad tipo = TipoActividad.correr]) async {
    await notifier().preparar(tipo);
    await notifier().iniciar();
  }

  test('preparar escucha sin servicio y muestra la precisión', () async {
    await notifier().preparar(TipoActividad.caminar);
    expect(avisos.precalentado, 1); // el audio queda listo antes de iniciar
    expect(estado().fase, FaseGrabacion.preparando);
    expect(fuente.conServicio, [false]);
    fuente.emitir(_punto(0, precision: 12));
    expect(estado().posicion!.precisionM, 12);
    await notifier().cancelarPreparacion();
    expect(estado().fase, FaseGrabacion.inactivo);
    expect(await db.carreraSinTerminar(), isNull);
  });

  test('grabar: guarda al llegar, suma distancia y tiempo', () async {
    await iniciar();
    expect(fuente.conServicio, [false, true]);
    expect(estado().fase, FaseGrabacion.grabando);
    emitirTramo(0, 100);
    expect(estado().distanciaM, closeTo(300, 3));
    expect(estado().tiempoMovimientoS, 100);
    expect(puntosRuta(), 101);
    expect(estado().ritmoActualSKm, closeTo(333.3, 5));
    expect(estado().ritmoMedioSKm, closeTo(333.3, 5));

    await notifier().terminar();
    final carrera = (await db.carrera(estado().carreraId!))!;
    expect(carrera.origen, origenApp);
    expect((await db.puntos(carrera.id)).length, 101);
  });

  test('un punto con mala precisión se guarda crudo y no cuenta', () async {
    await iniciar();
    emitirTramo(0, 10);
    reloj = _t0.add(const Duration(seconds: 11));
    fuente.emitir(_punto(11, precision: 80));
    expect(puntosRuta(), 11);
    await notifier().terminar();
    final puntos = await db.puntos(estado().carreraId!);
    expect(puntos.length, 12);
    expect(puntos.last.aceptado, isFalse);
  });

  test('el reloj avanza entre puntos sin depender de ellos', () async {
    await iniciar();
    emitirTramo(0, 10);
    reloj = _t0.add(const Duration(seconds: 13));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(estado().tiempoMovimientoS, 13);
  });

  test('pausar y reanudar no suman tiempo ni distancia', () async {
    await iniciar();
    emitirTramo(0, 20);
    reloj = _t0.add(const Duration(seconds: 20));
    await notifier().pausar();
    expect(estado().fase, FaseGrabacion.pausada);
    emitirTramo(21, 40); // el GPS sigue escuchando en pausa
    reloj = _t0.add(const Duration(seconds: 40));
    await notifier().reanudar();
    expect(estado().fase, FaseGrabacion.grabando);
    emitirTramo(41, 60);

    expect(estado().tiempoMovimientoS, 40);
    expect(estado().distanciaM, closeTo(120, 4));
    await notifier().terminar();
    expect(estado().resumen!.tiempoMovimientoS, 40);
    expect(estado().resumen!.distanciaM, closeTo(120, 4));
    expect((await db.pausas(estado().carreraId!)).single.fin, isNotNull);
  });

  test('terminar deja el resumen y la carrera cerrada en disco', () async {
    await iniciar(TipoActividad.caminar);
    emitirTramo(0, 60);
    reloj = _t0.add(const Duration(seconds: 61));
    await notifier().terminar();
    expect(estado().fase, FaseGrabacion.terminada);
    expect(estado().resumen!.distanciaM, closeTo(180, 2));
    final carrera = (await db.carrera(estado().carreraId!))!;
    expect(carrera.estado, EstadoCarrera.terminada);
    expect(carrera.tipo, TipoActividad.caminar);
    expect(carrera.distanciaM, closeTo(180, 2));
    expect(await db.carreraSinTerminar(), isNull);
    expect(fuente.ultimo!.hasListener, isFalse);

    await notifier().cerrar();
    expect(estado().fase, FaseGrabacion.inactivo);
  });

  test('descartar borra la actividad', () async {
    await iniciar();
    emitirTramo(0, 10);
    await notifier().terminar();
    final id = estado().carreraId!;
    await notifier().descartar();
    expect(estado().fase, FaseGrabacion.inactivo);
    expect(await db.carrera(id), isNull);
    expect(await db.puntos(id), isEmpty);
  });

  Future<void> esperar(double segundos) =>
      Future<void>.delayed(Duration(milliseconds: (segundos * 1000).round()));

  group('reconexión del GPS', () {
    test('un error marca sin señal, reintenta y vuelve a recibir', () async {
      await iniciar();
      emitirTramo(0, 10);
      fuente.ultimo!.addError(Exception('ubicación apagada'));
      expect(estado().sinSenal, isTrue);
      expect(estado().fase, FaseGrabacion.grabando);
      expect(fuente.creados.length, 2);

      await esperar(2.2);
      expect(fuente.creados.length, 3);
      expect(fuente.activas, 1);
      emitirTramo(11, 12);
      expect(estado().sinSenal, isFalse);
      expect(puntosRuta(), 13);
      await esperar(3); // el reintento pendiente se canceló al llegar
      expect(fuente.creados.length, 3);
    });

    test('las esperas crecen: 2 s, 5 s', () async {
      await iniciar();
      fuente.ultimo!.addError(Exception('x'));
      await esperar(2.2);
      expect(fuente.creados.length, 3);
      await esperar(2.5);
      expect(fuente.creados.length, 3);
      await esperar(3);
      expect(fuente.creados.length, 4);
      expect(fuente.activas, 1);
    });

    test('si el stream se cierra también reintenta', () async {
      await iniciar();
      emitirTramo(0, 5);
      await fuente.ultimo!.close();
      expect(estado().sinSenal, isTrue);
      expect(fuente.activas, 0);

      await esperar(2.2);
      expect(fuente.activas, 1);
      emitirTramo(6, 7);
      expect(estado().sinSenal, isFalse);
    });

    test('al volver el servicio de ubicación reintenta de inmediato', () async {
      await iniciar();
      fuente.servicio.add(false);
      expect(estado().sinSenal, isTrue);
      final antes = fuente.creados.length;
      fuente.servicio.add(true);
      expect(fuente.creados.length, antes + 1);
      expect(fuente.activas, 1);
      emitirTramo(0, 1);
      expect(estado().sinSenal, isFalse);
    });

    test('sin puntos en 20 s el vigilante recrea la suscripción', () async {
      await iniciar();
      emitirTramo(0, 5);
      reloj = _t0.add(const Duration(seconds: 15));
      await esperar(1.1);
      expect(fuente.creados.length, 2);
      reloj = _t0.add(const Duration(seconds: 26));
      await esperar(1.1);
      expect(fuente.creados.length, 3);
      expect(estado().sinSenal, isTrue);
      expect(fuente.activas, 1);
    });

    test(
      'en segundo plano el vigilante y onDone no recrean; al volver sí',
      () async {
        await iniciar();
        emitirTramo(0, 5);
        ciclo(AppLifecycleState.paused);
        reloj = _t0.add(const Duration(seconds: 30));
        await esperar(1.1);
        expect(estado().sinSenal, isTrue);
        expect(fuente.creados.length, 2);
        fuente.servicio.add(true);
        expect(fuente.creados.length, 2);

        await fuente.ultimo!.close();
        await esperar(2.5);
        expect(fuente.creados.length, 2);

        ciclo(AppLifecycleState.resumed);
        expect(fuente.creados.length, 3);
        expect(fuente.activas, 1);
        emitirTramo(31, 32);
        expect(estado().sinSenal, isFalse);
      },
    );

    test(
      'un error en segundo plano deja el stream vivo hasta volver',
      () async {
        await iniciar();
        ciclo(AppLifecycleState.paused);
        fuente.ultimo!.addError(Exception('x'));
        await esperar(2.5);
        expect(estado().sinSenal, isTrue);
        expect(fuente.creados.length, 2);
        expect(fuente.activas, 1);
        ciclo(AppLifecycleState.resumed);
        expect(fuente.creados.length, 3);
      },
    );

    test('el cronómetro corre sin señal y solo descuenta las pausas', () async {
      await iniciar();
      emitirTramo(0, 10);
      reloj = _t0.add(const Duration(seconds: 10));
      await notifier().pausar();
      reloj = _t0.add(const Duration(seconds: 40));
      await notifier().reanudar();
      fuente.ultimo!.addError(Exception('x'));
      reloj = _t0.add(const Duration(seconds: 100));
      await esperar(1.1);
      expect(estado().tiempoTotalS, 70);
      expect(estado().tiempoMovimientoS, lessThan(70));
      await notifier().terminar();
      expect(estado().tiempoTotalS, 70);
    });

    test('el tramo sin señal no suma distancia', () async {
      await iniciar();
      emitirTramo(0, 10);
      fuente.ultimo!.addError(Exception('x'));
      reloj = _t0.add(const Duration(seconds: 70));
      fuente.servicio.add(true);
      emitirTramo(70, 80);
      expect(estado().distanciaM, closeTo(60, 2));
      await notifier().terminar();
      expect(estado().resumen!.huecos.length, 1);
      expect(estado().resumen!.distanciaM, closeTo(60, 3));
    });

    test('terminar cancela reintentos, vigilante y listeners', () async {
      await iniciar();
      fuente.ultimo!.addError(Exception('x'));
      await notifier().terminar();
      expect(estado().sinSenal, isFalse);
      expect(fuente.activas, 0);
      expect(fuente.servicio.hasListener, isFalse);
      final creados = fuente.creados.length;
      reloj = _t0.add(const Duration(seconds: 60));
      await esperar(2.5);
      expect(fuente.creados.length, creados);
    });
  });

  group('acciones repetidas y fallo al terminar', () {
    test('dos iniciar seguidos crean una sola actividad', () async {
      await notifier().preparar(TipoActividad.correr);
      await Future.wait([notifier().iniciar(), notifier().iniciar()]);
      expect(fuente.conServicio, [false, true]);
      expect(estado().fase, FaseGrabacion.grabando);
    });

    test('dos terminar seguidos cierran una sola vez', () async {
      await iniciar();
      emitirTramo(0, 10);
      await Future.wait([notifier().terminar(), notifier().terminar()]);
      expect(dbFalla.terminaciones, 1);
      expect(estado().fase, FaseGrabacion.terminada);
      expect(estado().ocupado, isFalse);
    });

    test('dos descartar seguidos borran una sola vez', () async {
      await iniciar();
      emitirTramo(0, 10);
      await notifier().terminar();
      final id = estado().carreraId!;
      await Future.wait([notifier().descartar(), notifier().descartar()]);
      expect(estado().fase, FaseGrabacion.inactivo);
      expect(await db.carrera(id), isNull);
    });

    test(
      'si la base falla al terminar no pasa a resumen y se reintenta',
      () async {
        await iniciar();
        emitirTramo(0, 30);
        dbFalla.fallosTerminar = 1;
        await notifier().terminar();
        expect(estado().falloCierre, isTrue);
        expect(estado().ocupado, isFalse);
        expect(estado().fase, FaseGrabacion.grabando);
        final id = estado().carreraId!;
        expect((await db.puntos(id)).length, 31);
        expect((await db.carrera(id))!.estado, isNot(EstadoCarrera.terminada));

        await notifier().terminar();
        expect(estado().falloCierre, isFalse);
        expect(estado().fase, FaseGrabacion.terminada);
        expect(estado().resumen!.distanciaM, closeTo(90, 2));
        expect((await db.carrera(id))!.estado, EstadoCarrera.terminada);
      },
    );
  });

  group('recuperación', () {
    Future<CarreraLocal> carreraAbierta({String origen = origenApp}) async {
      final carrera = await db.crearCarrera(
        TipoActividad.correr,
        inicio: _t0,
        origen: origen,
      );
      for (var s = 0; s <= 60; s++) {
        await db.insertarPunto(carrera.id, _punto(s));
      }
      return carrera;
    }

    test('ignora las carreras de la prueba', () async {
      await carreraAbierta(origen: origenPrueba);
      expect(await notifier().carreraPendiente(), isNull);
      expect(await db.carreraSinTerminar(origen: origenPrueba), isNotNull);
    });

    test('Continuar reanuda y el hueco no suma', () async {
      final carrera = await carreraAbierta();
      final pendiente = await notifier().carreraPendiente();
      expect(pendiente!.id, carrera.id);

      reloj = _t0.add(const Duration(seconds: 300));
      await notifier().continuar(pendiente);
      expect(estado().fase, FaseGrabacion.grabando);
      expect(fuente.conServicio.last, isTrue);
      expect(puntosRuta(), 61);

      // La app estuvo cerrada de 60 s a 300 s: ese tramo no suma.
      emitirTramo(300, 330);
      expect(estado().distanciaM, closeTo(270, 3));
      expect(estado().tiempoMovimientoS, 60 + 30);
      await notifier().terminar();
      expect(estado().resumen!.huecos.length, 1);
      expect((await db.puntos(carrera.id)).length, 61 + 31);
    });

    test('Terminar y guardar cierra con lo guardado', () async {
      final carrera = await carreraAbierta();
      await notifier().terminarPendiente(carrera);
      expect(estado().fase, FaseGrabacion.terminada);
      expect(estado().resumen!.distanciaM, closeTo(180, 2));
      expect(estado().resumen!.tiempoMovimientoS, 60);
      expect((await db.carrera(carrera.id))!.estado, EstadoCarrera.terminada);
      expect(await db.carreraSinTerminar(), isNull);
    });

    test('Descartar borra la pendiente', () async {
      final carrera = await carreraAbierta();
      await notifier().descartarPendiente(carrera);
      expect(await db.carrera(carrera.id), isNull);
    });

    test('con una actividad en curso no hay pendiente que ofrecer', () async {
      await iniciar();
      expect(await notifier().carreraPendiente(), isNull);
    });
  });

  group('modos', () {
    Future<void> iniciarModo(ModoActividad modo) async {
      await notifier().preparar(TipoActividad.correr);
      notifier().cambiarModo(modo);
      await notifier().iniciar();
    }

    Future<void> esperarFase(FaseGrabacion fase) async {
      for (var i = 0; i < 60 && estado().fase != fase; i++) {
        await esperar(0.05);
      }
      expect(estado().fase, fase);
    }

    test('libre no avisa ni evalúa nada', () async {
      await iniciar();
      emitirTramo(0, 60);
      expect(avisos.avisos, isEmpty);
      expect(estado().estadoModo, isNull);
      expect(estado().modo, isA<ModoLibre>());
    });

    test(
      'intervalos por distancia: descanso, vuelta y fin con avisos',
      () async {
        await iniciarModo(
          const ModoIntervalos(tramo: 100, descanso: 10, repeticiones: 2),
        );
        final id = estado().carreraId!;
        expect((await db.carrera(id))!.modo, isA<ModoIntervalos>());

        emitirTramo(0, 33); // 99 m
        expect(estado().estadoModo!.fase, FaseModo.corriendo);
        expect(avisos.avisos, isEmpty);

        emitirTramo(34, 34); // 102 m: empieza el descanso
        expect(estado().fase, FaseGrabacion.pausada);
        expect(estado().estadoModo!.fase, FaseModo.descansando);
        expect(estado().estadoModo!.repeticion, 1);
        expect(avisos.avisos, [Aviso.descanso]);
        expect(estado().ritmoActualSKm, closeTo(333, 10));

        // El GPS sigue: no suma distancia ni se dibuja.
        emitirTramo(35, 43);
        expect(estado().estadoModo!.fase, FaseModo.descansando);
        expect(estado().distanciaM, closeTo(102, 3));
        expect(puntosRuta(), 35);
        await notifier().reanudar(); // el descanso no se reanuda a mano
        expect(estado().fase, FaseGrabacion.pausada);

        emitirTramo(44, 44); // acaba el descanso
        expect(estado().fase, FaseGrabacion.grabando);
        expect(estado().estadoModo!.repeticion, 2);
        expect(avisos.avisos, [Aviso.descanso, Aviso.correr]);

        emitirTramo(45, 78); // segundo tramo: la última repetición termina
        await esperarFase(FaseGrabacion.terminada);
        expect(avisos.avisos, [Aviso.descanso, Aviso.correr, Aviso.meta]);

        // El descanso son pausas: solo cuentan los tramos de carrera.
        final r = estado().resumen!;
        expect(r.distanciaM, closeTo(204, 5));
        expect(r.tiempoMovimientoS, 68);
        expect(r.ritmoMedioSKm, closeTo(333.3, 5));
        final pausa = (await db.pausas(id)).single;
        expect(pausa.descanso, isTrue);
        expect(pausa.fin, isNotNull);
        // La línea del mapa quedó en dos trozos, sin unir el descanso.
        expect(estado().ruta.length, 2);
      },
    );

    test(
      'tramo por tiempo, descanso por metros, saltar y sin límite',
      () async {
        await iniciarModo(
          const ModoIntervalos(
            tramoMedida: Medida.tiempo,
            tramo: 20,
            descansoMedida: Medida.distancia,
            descanso: 50,
            repeticiones: null,
          ),
        );
        emitirTramo(0, 19);
        expect(avisos.avisos, isEmpty);
        emitirTramo(20, 20);
        expect(estado().estadoModo!.fase, FaseModo.descansando);
        expect(avisos.avisos, [Aviso.descanso]);

        emitirTramo(21, 30); // 30 m caminados
        expect(estado().estadoModo!.restanteDescanso, closeTo(20, 2));
        expect(estado().estadoModo!.fase, FaseModo.descansando);

        notifier().saltarDescanso();
        expect(estado().fase, FaseGrabacion.grabando);
        expect(avisos.avisos, [Aviso.descanso, Aviso.correr]);
        await esperar(0.2);
        final pausa = (await db.pausas(estado().carreraId!)).single;
        expect(pausa.descanso, isTrue);
        expect(pausa.fin, isNotNull);

        emitirTramo(31, 50); // otro tramo de 20 s
        expect(estado().estadoModo!.repeticion, 2);
        expect(estado().estadoModo!.fase, FaseModo.descansando);
        expect(avisos.avisos.last, Aviso.descanso);
        emitirTramo(51, 150); // más descansos: sin límite no termina nunca
        expect(estado().fase, isNot(FaseGrabacion.terminada));
      },
    );

    test('la pausa manual congela el tramo', () async {
      await iniciarModo(
        const ModoIntervalos(
          tramoMedida: Medida.tiempo,
          tramo: 30,
          descanso: 10,
          repeticiones: 3,
        ),
      );
      emitirTramo(0, 9);
      reloj = _t0.add(const Duration(seconds: 10));
      await notifier().pausar();
      emitirTramo(11, 39);
      expect(estado().estadoModo!.tiempoTramoS, 10);
      expect(avisos.avisos, isEmpty);
      reloj = _t0.add(const Duration(seconds: 40));
      await notifier().reanudar();
      emitirTramo(41, 59); // 10 s + 19 s de tramo
      expect(avisos.avisos, isEmpty);
      emitirTramo(60, 60);
      expect(avisos.avisos, [Aviso.descanso]);
    });

    test(
      'al terminar las repeticiones: pausar, avisando una sola vez',
      () async {
        await iniciarModo(
          const ModoIntervalos(
            tramoMedida: Medida.tiempo,
            tramo: 10,
            repeticiones: 1,
            alTerminar: AlTerminarIntervalos.pausar,
          ),
        );
        emitirTramo(0, 10);
        expect(estado().fase, FaseGrabacion.pausada);
        expect(avisos.avisos, [Aviso.meta]);
        emitirTramo(11, 15);
        await esperar(0.2);
        expect((await db.pausas(estado().carreraId!)).single.descanso, isFalse);
        await notifier().reanudar();
        emitirTramo(16, 30);
        expect(estado().fase, FaseGrabacion.grabando);
        expect(estado().estadoModo!.fase, FaseModo.terminado);
        expect(avisos.avisos, [Aviso.meta]);
      },
    );

    test('al terminar las repeticiones: seguir en libre', () async {
      await iniciarModo(
        const ModoIntervalos(
          tramoMedida: Medida.tiempo,
          tramo: 10,
          repeticiones: 1,
          alTerminar: AlTerminarIntervalos.libre,
        ),
      );
      emitirTramo(0, 30);
      expect(estado().fase, FaseGrabacion.grabando);
      expect(estado().estadoModo!.fase, FaseModo.terminado);
      expect(avisos.avisos, [Aviso.meta]);
    });

    test('meta por distancia: finalizar', () async {
      await iniciarModo(
        const ModoMeta(valor: 58, alLlegar: AlLlegarMeta.finalizar),
      );
      emitirTramo(0, 19);
      expect(estado().fase, FaseGrabacion.grabando);
      emitirTramo(20, 20);
      await esperarFase(FaseGrabacion.terminada);
      expect(avisos.avisos, [Aviso.meta]);
      expect(estado().resumen!.distanciaM, closeTo(60, 3));
    });

    test('meta por tiempo: solo avisar y seguir, una sola vez', () async {
      await iniciarModo(const ModoMeta(medida: Medida.tiempo, valor: 10));
      emitirTramo(0, 9);
      expect(avisos.avisos, isEmpty);
      emitirTramo(10, 40);
      expect(avisos.avisos, [Aviso.meta]);
      expect(estado().fase, FaseGrabacion.grabando);
      expect(estado().estadoModo!.progreso, greaterThanOrEqualTo(10));
    });

    test('meta: pausar al llegar, sin volver a disparar al reanudar', () async {
      await iniciarModo(
        const ModoMeta(
          medida: Medida.tiempo,
          valor: 10,
          alLlegar: AlLlegarMeta.pausar,
        ),
      );
      emitirTramo(0, 10);
      expect(estado().fase, FaseGrabacion.pausada);
      await notifier().reanudar();
      emitirTramo(11, 30);
      expect(estado().fase, FaseGrabacion.grabando);
      expect(avisos.avisos, [Aviso.meta]);
    });

    test('finalizar en pleno descanso cierra sin contar el descanso', () async {
      await iniciarModo(
        const ModoIntervalos(
          tramoMedida: Medida.tiempo,
          tramo: 10,
          descanso: 60,
          repeticiones: 3,
        ),
      );
      emitirTramo(0, 10);
      emitirTramo(11, 25);
      reloj = _t0.add(const Duration(seconds: 25));
      await notifier().terminar();
      expect(estado().fase, FaseGrabacion.terminada);
      expect(estado().tiempoTotalS, 10);
      expect(estado().resumen!.distanciaM, closeTo(30, 2));
    });

    group('recuperar una actividad abierta', () {
      Future<CarreraLocal> abierta(ModoActividad modo, int hasta) async {
        final carrera = await db.crearCarrera(
          TipoActividad.correr,
          inicio: _t0,
          modo: modo,
        );
        for (var s = 0; s <= hasta; s++) {
          await db.insertarPunto(carrera.id, _punto(s));
        }
        return carrera;
      }

      test('en pleno descanso sigue descansando y no avisa de nuevo', () async {
        const modo = ModoIntervalos(
          tramoMedida: Medida.tiempo,
          tramo: 20,
          descanso: 60,
          repeticiones: 4,
        );
        final carrera = await abierta(modo, 20);
        await db.pausar(
          carrera.id,
          ahora: _t0.add(const Duration(seconds: 20)),
          descanso: true,
        );

        reloj = _t0.add(const Duration(seconds: 30));
        await notifier().continuar((await notifier().carreraPendiente())!);
        expect(estado().fase, FaseGrabacion.pausada);
        expect(estado().estadoModo!.fase, FaseModo.descansando);
        expect(estado().estadoModo!.restanteDescanso, closeTo(50, 0.5));
        expect(avisos.avisos, isEmpty);

        reloj = _t0.add(const Duration(seconds: 81));
        fuente.emitir(_punto(81));
        expect(estado().fase, FaseGrabacion.grabando);
        expect(estado().estadoModo!.repeticion, 2);
        expect(avisos.avisos, [Aviso.correr]);
      });

      test(
        'si los intervalos ya habían terminado, no vuelve a avisar',
        () async {
          const modo = ModoIntervalos(
            tramoMedida: Medida.tiempo,
            tramo: 10,
            repeticiones: 1,
          );
          final carrera = await abierta(modo, 30);
          reloj = _t0.add(const Duration(seconds: 30));
          await notifier().continuar(carrera);
          expect(estado().estadoModo!.fase, FaseModo.terminado);
          fuente.emitir(_punto(31));
          await esperar(0.2);
          expect(estado().fase, FaseGrabacion.grabando);
          expect(avisos.avisos, isEmpty);
        },
      );

      test('el modo de la actividad se restaura', () async {
        final carrera = await abierta(const ModoMeta(valor: 10000), 10);
        reloj = _t0.add(const Duration(seconds: 10));
        await notifier().continuar(carrera);
        expect(estado().modo, isA<ModoMeta>());
        expect(estado().estadoModo!.objetivo, 10000);
      });
    });
  });
}
