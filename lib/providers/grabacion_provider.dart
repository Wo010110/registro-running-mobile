import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/avisos.dart';
import '../core/carrera_calculos.dart';
import '../core/carreras_db.dart';
import '../core/fuente_posiciones.dart';
import '../core/motor_modos.dart';
import '../models/modo_actividad.dart';
import '../models/tipo_actividad.dart';

/// Se sobrescribe en `main` con la base ya abierta.
final carrerasDbProvider = Provider<CarrerasDb>(
  (ref) => throw UnimplementedError('carrerasDbProvider sin sobrescribir'),
);

final fuentePosicionesProvider = Provider<FuentePosiciones>(
  (ref) => const FuenteGeolocator(),
);

final avisadorProvider = Provider<Avisador>((ref) => AvisadorSonoro());

/// Reloj de la grabación; las pruebas lo sustituyen.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Estado del ciclo de vida de la app; las pruebas lo sustituyen.
class CicloVida extends Notifier<AppLifecycleState>
    with WidgetsBindingObserver {
  @override
  AppLifecycleState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      this.state = state;
}

final cicloVidaProvider = NotifierProvider<CicloVida, AppLifecycleState>(
  CicloVida.new,
);

enum FaseGrabacion { inactivo, preparando, grabando, pausada, terminada }

class GrabacionState {
  const GrabacionState({
    required this.fase,
    required this.tipo,
    this.carreraId,
    this.inicioUtc,
    this.posicion,
    this.ruta = const [],
    this.modo = const ModoLibre(),
    this.estadoModo,
    this.distanciaM = 0,
    this.tiempoMovimientoS = 0,
    this.tiempoTotalS = 0,
    this.ritmoActualSKm,
    this.ritmoMedioSKm,
    this.resumen,
    this.error,
    this.sinSenal = false,
    this.falloCierre = false,
    this.ocupado = false,
  });

  final FaseGrabacion fase;
  final TipoActividad tipo;
  final String? carreraId;
  final DateTime? inicioUtc;

  /// Última posición recibida, aceptada o no.
  final PuntoGps? posicion;

  /// Trozos de la línea dibujada ([FiltroVisual]), cortada en cada pausa; la
  /// distancia no sale de aquí. Puede terminar en un trozo vacío.
  final List<List<PuntoGps>> ruta;

  final ModoActividad modo;

  /// null en modo libre.
  final EstadoModo? estadoModo;
  final double distanciaM;
  final int tiempoMovimientoS;

  /// Transcurrido menos las pausas manuales; corre también sin señal.
  final int tiempoTotalS;
  final double? ritmoActualSKm;
  final double? ritmoMedioSKm;

  /// Solo en [FaseGrabacion.terminada].
  final ResumenCarrera? resumen;
  final String? error;

  /// Grabando o pausada pero el GPS no entrega puntos; se está reintentando.
  final bool sinSenal;

  /// Terminar falló al guardar en disco; se puede reintentar.
  final bool falloCierre;

  /// Terminando o descartando: las acciones no se pueden repetir.
  final bool ocupado;

  bool get enCurso =>
      fase == FaseGrabacion.grabando || fase == FaseGrabacion.pausada;
}

class GrabacionNotifier extends Notifier<GrabacionState> {
  FaseGrabacion _fase = FaseGrabacion.inactivo;
  TipoActividad _tipo = TipoActividad.correr;
  CarreraLocal? _carrera;
  List<PuntoGps> _puntos = [];
  List<List<PuntoGps>> _ruta = [];
  List<PausaCarrera> _pausas = [];
  ModoActividad _modo = const ModoLibre();
  EstadoModo? _estadoModo;
  bool _finDisparado = false;
  bool _metaDisparada = false;
  double? _ritmoCongelado;
  FiltroGps _filtro = FiltroGps();
  FiltroVisual _filtroVisual = FiltroVisual();
  PuntoGps? _posicion;
  ResumenCarrera? _calculo;
  String? _error;
  StreamSubscription<PuntoGps>? _sub;
  StreamSubscription<bool>? _servicio;
  Timer? _timer;
  Timer? _reintento;
  Future<void> _escrituras = Future.value();
  bool _cerrando = false;
  bool _sinSenal = false;
  bool _falloCierre = false;
  int _intentos = 0;
  DateTime _ultimoPuntoEn = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _finSolicitado;
  int _totalS = 0;

  CarrerasDb get _db => ref.read(carrerasDbProvider);
  FuentePosiciones get _fuente => ref.read(fuentePosicionesProvider);
  DateTime _ahora() => ref.read(relojProvider)();

  @override
  GrabacionState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _servicio?.cancel();
      _timer?.cancel();
      _reintento?.cancel();
    });
    ref.listen(cicloVidaProvider, (_, estado) => _alCambiarCicloVida(estado));
    return _estado();
  }

  /// Escucha el GPS sin servicio para mostrar la precisión antes de empezar.
  Future<void> preparar(TipoActividad tipo) async {
    if (_fase != FaseGrabacion.inactivo && _fase != FaseGrabacion.preparando) {
      return;
    }
    _tipo = tipo;
    _fase = FaseGrabacion.preparando;
    // Con la pantalla de preparar abierta, el audio ya queda listo.
    unawaited(ref.read(avisadorProvider).precalentar());
    _posicion = null;
    _error = null;
    await _sub?.cancel();
    _sub = _fuente.escuchar(conServicio: false).listen((p) {
      _posicion = p;
      _error = null;
      _publicar();
    }, onError: _alFallar);
    _publicar();
  }

  void cambiarTipo(TipoActividad tipo) {
    if (_fase != FaseGrabacion.preparando) return;
    _tipo = tipo;
    _publicar();
  }

  void cambiarModo(ModoActividad modo) {
    if (_fase != FaseGrabacion.preparando) return;
    _modo = modo;
    _publicar();
  }

  Future<void> cancelarPreparacion() async {
    if (_fase != FaseGrabacion.preparando) return;
    await _reiniciar();
  }

  Future<void> iniciar() async {
    if (_fase != FaseGrabacion.preparando) return;
    _fase = FaseGrabacion.grabando;
    await _sub?.cancel();
    try {
      final carrera = await _db.crearCarrera(
        _tipo,
        inicio: _ahora(),
        modo: _modo,
      );
      _arrancar(carrera, [], [], FaseGrabacion.grabando);
    } catch (_) {
      _fase = FaseGrabacion.inactivo;
      _error = 'No se pudo crear la actividad.';
      _publicar();
    }
  }

  Future<void> pausar() async {
    final c = _carrera;
    if (c == null || _fase != FaseGrabacion.grabando) return;
    final ahora = _ahora();
    _pausas.add(PausaCarrera(inicio: ahora));
    _fase = FaseGrabacion.pausada;
    _cortarRuta();
    _recalcular();
    await _db.pausar(c.id, ahora: ahora);
  }

  /// Durante el descanso de los intervalos solo reanuda [saltarDescanso].
  Future<void> reanudar() async {
    final c = _carrera;
    if (c == null || _fase != FaseGrabacion.pausada) return;
    if (_estadoModo?.fase == FaseModo.descansando) return;
    final ahora = _ahora();
    _pausas[_pausas.length - 1] = PausaCarrera(
      inicio: _pausas.last.inicio,
      fin: ahora,
    );
    _fase = FaseGrabacion.grabando;
    _recalcular();
    await _db.reanudar(c.id, ahora: ahora);
  }

  /// Termina el descanso de los intervalos antes de tiempo.
  void saltarDescanso() {
    if (_estadoModo?.fase != FaseModo.descansando || _cerrando) return;
    _terminarDescanso();
    _recalcular();
  }

  /// Detiene el GPS y calcula el resumen final desde lo guardado en disco.
  /// El GPS se detiene antes de cerrar: el usuario ya decidió terminar y los
  /// puntos recibidos están en disco. Si cerrar falla la actividad sigue
  /// abierta en disco (se recupera al reabrir) y se puede reintentar.
  Future<void> terminar() async {
    final c = _carrera;
    if (c == null || !state.enCurso || _cerrando) return;
    _cerrando = true;
    _falloCierre = false;
    _publicar();
    await _parar();
    await _escrituras;
    try {
      await _cerrar(c, _finSolicitado ??= _ahora());
      _finSolicitado = null;
    } catch (_) {
      _falloCierre = true;
      _publicar();
    }
  }

  /// Borra la actividad y vuelve a inactivo.
  Future<void> descartar() async {
    final c = _carrera;
    if (c == null || _cerrando) return;
    _cerrando = true;
    _publicar();
    try {
      await _parar();
      await _escrituras;
      await _db.descartar(c.id);
      await _reiniciar();
    } finally {
      _cerrando = false;
      _publicar();
    }
  }

  /// Sale del resumen: la actividad ya está guardada en disco.
  Future<void> cerrar() async {
    if (_fase != FaseGrabacion.terminada || _cerrando) return;
    _cerrando = true;
    _publicar();
    try {
      await _reiniciar();
    } finally {
      _cerrando = false;
      _publicar();
    }
  }

  Future<CarreraLocal?> carreraPendiente() async =>
      _fase == FaseGrabacion.inactivo ? _db.carreraSinTerminar() : null;

  /// Reanuda una actividad que la app dejó abierta; el tiempo sin señal queda
  /// como hueco y no suma.
  Future<void> continuar(CarreraLocal carrera) async {
    if (_fase != FaseGrabacion.inactivo) return;
    final puntos = await _db.puntos(carrera.id);
    final pausas = await _db.pausas(carrera.id);
    _arrancar(
      carrera,
      puntos,
      pausas,
      carrera.estado == EstadoCarrera.pausada
          ? FaseGrabacion.pausada
          : FaseGrabacion.grabando,
    );
  }

  /// Cierra con lo guardado una actividad que la app dejó abierta.
  Future<void> terminarPendiente(CarreraLocal carrera) async {
    if (_fase != FaseGrabacion.inactivo || _cerrando) return;
    _cerrando = true;
    final puntos = await _db.puntos(carrera.id);
    final pausas = await _db.pausas(carrera.id);
    var fin = puntos.isEmpty ? carrera.inicioUtc : puntos.last.instante;
    if (pausas.isNotEmpty && pausas.last.inicio.isAfter(fin)) {
      fin = pausas.last.inicio;
    }
    await _cerrar(carrera, fin);
  }

  Future<void> descartarPendiente(CarreraLocal carrera) =>
      _db.descartar(carrera.id);

  void _arrancar(
    CarreraLocal carrera,
    List<PuntoGps> puntos,
    List<PausaCarrera> pausas,
    FaseGrabacion fase,
  ) {
    final aceptados = puntos.where((p) => p.aceptado).toList();
    _carrera = carrera;
    _tipo = carrera.tipo;
    _fase = fase;
    _puntos = puntos;
    _modo = carrera.modo ?? const ModoLibre();
    _pausas = pausas;
    _filtroVisual = FiltroVisual(tipo: carrera.tipo);
    _ruta = rutaVisual(puntos, carrera.tipo, pausas);
    // La línea sigue en un trozo nuevo: lo que pasó con la app cerrada no se
    // une con una recta.
    _cortarRuta();
    _filtro = FiltroGps(
      ultimoAceptado: aceptados.isEmpty ? null : aceptados.last,
      tipo: carrera.tipo,
    );
    _posicion = puntos.isEmpty ? null : puntos.last;
    _error = null;
    _sinSenal = false;
    _falloCierre = false;
    _intentos = 0;
    // Lo que ya se cumplió antes de cerrar la app no vuelve a avisar.
    final modo = _evaluar();
    _finDisparado = modo?.fase == FaseModo.terminado;
    _metaDisparada = modo?.evento == EventoModo.metaAlcanzada;
    _escuchar();
    _servicio = _fuente.servicioHabilitado().listen(_alCambiarServicio);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _vigilar();
      _recalcular();
    });
    _recalcular();
  }

  /// Cancela la suscripción anterior y crea la nueva en el mismo instante.
  /// En geolocator_android cancelar la última suscripción detiene el servicio
  /// en primer plano (notificación y wake lock) y la nueva lo vuelve a
  /// arrancar: el corte dura lo que tardan dos mensajes del canal. La nueva
  /// debe crearse tras cancelar: antes, geolocator devuelve el mismo stream
  /// en caché y no recrea nada.
  void _escuchar() {
    _sub?.cancel();
    _sub = _fuente
        .escuchar(conServicio: true)
        .listen(_alLlegar, onError: _perderSenal, onDone: _perderSenal);
    _ultimoPuntoEn = _ahora();
  }

  /// Fuera de primer plano nunca se recrea la suscripción: quitaría el
  /// servicio en primer plano y Android 12+ puede no dejarlo volver. Solo se
  /// marca sinSenal y se recrea al volver a primer plano.
  bool get _enPrimerPlano =>
      ref.read(cicloVidaProvider) == AppLifecycleState.resumed;

  void _perderSenal([Object? _]) {
    if (!state.enCurso) return;
    _sinSenal = true;
    if (_reintento == null && _enPrimerPlano) _programarReintento();
    _publicar();
  }

  /// Esperas de 2, 5 y 10 s; después cada 15 s, sin límite.
  void _programarReintento() {
    const esperas = [2, 5, 10, 15];
    final s = esperas[_intentos < esperas.length ? _intentos : 3];
    _intentos++;
    _reintento = Timer(Duration(seconds: s), _reconectar);
  }

  void _reconectar() {
    _reintento?.cancel();
    _reintento = null;
    if (!state.enCurso || !_enPrimerPlano) return;
    _escuchar();
    if (_sinSenal) _programarReintento();
  }

  void _alCambiarServicio(bool habilitado) {
    if (!state.enCurso) return;
    if (!habilitado) {
      _sinSenal = true;
      _publicar();
    } else if (_sinSenal) {
      _reconectar();
    }
  }

  /// Si en 20 s no llega ningún punto, el stream está congelado: se recrea.
  void _vigilar() {
    if (_sinSenal || !state.enCurso) return;
    if (_ahora().difference(_ultimoPuntoEn).inSeconds >= 20) {
      _sinSenal = true;
      _reconectar();
      _publicar();
    }
  }

  void _alCambiarCicloVida(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed && state.enCurso && _sinSenal) {
      _reconectar();
    }
  }

  void _alLlegar(PuntoGps crudo) {
    final c = _carrera;
    if (c == null) return;
    final punto = _filtro.clasificar(crudo);
    _puntos.add(punto);
    // Durante una pausa (manual o descanso) la línea no se dibuja.
    if (_fase == FaseGrabacion.grabando && _filtroVisual.admite(punto)) {
      if (_ruta.isEmpty) _ruta.add([]);
      _ruta.last.add(punto);
    }
    _posicion = crudo;
    _error = null;
    _sinSenal = false;
    _intentos = 0;
    _reintento?.cancel();
    _reintento = null;
    _ultimoPuntoEn = _ahora();
    _escrituras = _escrituras
        .then((_) => _db.insertarPunto(c.id, punto))
        .catchError((Object _) {
          if (!ref.mounted) return;
          _error = 'No se pudo guardar un punto en el teléfono.';
          _publicar();
        });
    _recalcular();
  }

  void _alFallar(Object _) {
    _error = 'Se perdió la señal del GPS. Revisa que la ubicación esté activa.';
    _publicar();
  }

  Future<void> _parar() async {
    _reintento?.cancel();
    _reintento = null;
    _timer?.cancel();
    _timer = null;
    _sinSenal = false;
    await _servicio?.cancel();
    _servicio = null;
    await _sub?.cancel();
    _sub = null;
  }

  /// Calcula el resumen final desde lo guardado en disco y cierra la carrera.
  Future<void> _cerrar(CarreraLocal c, DateTime fin) async {
    try {
      final puntos = await _db.puntos(c.id);
      final pausas = await _db.pausas(c.id);
      final r = calcularCarrera(puntos, pausas);
      await _db.terminar(
        c.id,
        distanciaM: r.distanciaM,
        tiempoMovimientoS: r.tiempoMovimientoS,
        fin: fin,
      );
      _carrera = c;
      _tipo = c.tipo;
      _puntos = puntos;
      _ruta = rutaVisual(puntos, c.tipo, pausas);
      _pausas = pausas;
      _posicion = puntos.isEmpty ? null : puntos.last;
      _calculo = r;
      _totalS = tiempoTranscurridoS(c.inicioUtc, fin, pausas);
      _fase = FaseGrabacion.terminada;
      _cerrando = false;
      _publicar();
    } finally {
      _cerrando = false;
    }
  }

  Future<void> _reiniciar() async {
    await _parar();
    _fase = FaseGrabacion.inactivo;
    _carrera = null;
    _puntos = [];
    _ruta = [];
    _pausas = [];
    _modo = const ModoLibre();
    _estadoModo = null;
    _ritmoCongelado = null;
    _posicion = null;
    _calculo = null;
    _totalS = 0;
    _error = null;
    _falloCierre = false;
    _finSolicitado = null;
    _publicar();
  }

  /// Recalcula todo con [calcularCarrera]: con 6000 puntos tarda ~3 ms.
  void _recalcular() {
    if (_fase == FaseGrabacion.grabando || _fase == FaseGrabacion.pausada) {
      _calculo = calcularCarrera(_puntos, _pausas, ahora: _ahora());
      _evaluarModo();
    }
    _publicar();
  }

  /// Corta la línea dibujada: el siguiente punto abre un trozo nuevo.
  void _cortarRuta() {
    if (_ruta.isNotEmpty && _ruta.last.isNotEmpty) _ruta.add([]);
    _filtroVisual = FiltroVisual(tipo: _tipo);
  }

  EstadoModo? _evaluar() {
    final c = _carrera;
    if (c == null || _modo is ModoLibre) return null;
    return evaluarModo(
      modo: _modo,
      inicio: c.inicioUtc,
      puntos: _puntos,
      pausas: _pausas,
      ahora: _ahora(),
      distanciaTotalM: _calculo?.distanciaM,
    );
  }

  /// Ejecuta lo que toque según el modo. Cada acción cambia el estado en el
  /// acto, así que no se repite en la siguiente evaluación.
  // shortcut: el cambio de tramo se detecta al llegar un punto o en el tick de
  // 1 s, así que un tramo puede pasarse hasta ~1 s; mejorar si hace falta
  // exactitud al segundo.
  void _evaluarModo() {
    if (_cerrando) return;
    final e = _estadoModo = _evaluar();
    switch (e?.evento) {
      case EventoModo.empezarDescanso:
        // Con pausa manual el tramo está congelado y no debería completarse.
        if (_fase != FaseGrabacion.grabando) return;
        _empezarDescanso();
        _estadoModo = _evaluar();
      case EventoModo.empezarTramo:
        _terminarDescanso();
        _estadoModo = _evaluar();
      case EventoModo.finIntervalos:
        if (_finDisparado) return;
        _finDisparado = true;
        _aviso(Aviso.meta);
        switch ((_modo as ModoIntervalos).alTerminar) {
          case AlTerminarIntervalos.finalizar:
            unawaited(terminar());
          case AlTerminarIntervalos.pausar:
            unawaited(pausar());
          case AlTerminarIntervalos.libre:
        }
      case EventoModo.metaAlcanzada:
        if (_metaDisparada) return;
        _metaDisparada = true;
        _aviso(Aviso.meta);
        switch ((_modo as ModoMeta).alLlegar) {
          case AlLlegarMeta.pausar:
            unawaited(pausar());
          case AlLlegarMeta.finalizar:
            unawaited(terminar());
          case AlLlegarMeta.avisar:
        }
      case null:
    }
  }

  /// El descanso es una pausa automática: los puntos siguen llegando (para
  /// medir los metros caminados) pero no suman ni se dibujan.
  void _empezarDescanso() {
    final c = _carrera!;
    final ahora = _ahora();
    _ritmoCongelado = _calculo?.ritmoActualSKm;
    _pausas.add(PausaCarrera(inicio: ahora, descanso: true));
    _fase = FaseGrabacion.pausada;
    _cortarRuta();
    _escribir(() => _db.pausar(c.id, ahora: ahora, descanso: true));
    _aviso(Aviso.descanso);
  }

  void _terminarDescanso() {
    final c = _carrera!;
    final ahora = _ahora();
    _pausas[_pausas.length - 1] = PausaCarrera(
      inicio: _pausas.last.inicio,
      fin: ahora,
      descanso: true,
    );
    _fase = FaseGrabacion.grabando;
    _escribir(() => _db.reanudar(c.id, ahora: ahora));
    _aviso(Aviso.correr);
  }

  void _escribir(Future<void> Function() operacion) {
    _escrituras = _escrituras.then((_) => operacion()).catchError((Object _) {
      if (!ref.mounted) return;
      _error = 'No se pudo guardar el descanso en el teléfono.';
      _publicar();
    });
  }

  void _aviso(Aviso aviso) =>
      unawaited(ref.read(avisadorProvider).avisar(aviso));

  /// Segundos desde el último punto que aún cuentan como tiempo en
  /// movimiento: el reloj avanza entre puntos sin depender de los ticks.
  int _segundosEnCurso() {
    if (_fase != FaseGrabacion.grabando || _puntos.isEmpty) return 0;
    var desde = _puntos.last.instante;
    final fin = _pausas.isEmpty ? null : _pausas.last.fin;
    if (fin != null && fin.isAfter(desde)) desde = fin;
    final s = _ahora().toUtc().difference(desde).inSeconds;
    return s > 0 && s <= huecoMinS ? s : 0;
  }

  int _tiempoTotalS() {
    final c = _carrera;
    if (c == null ||
        (_fase != FaseGrabacion.grabando && _fase != FaseGrabacion.pausada)) {
      return _totalS;
    }
    return tiempoTranscurridoS(
      c.inicioUtc,
      _finSolicitado ?? _ahora(),
      _pausas,
    );
  }

  GrabacionState _estado() {
    final r = _calculo;
    return GrabacionState(
      fase: _fase,
      tipo: _tipo,
      carreraId: _carrera?.id,
      inicioUtc: _carrera?.inicioUtc,
      posicion: _posicion,
      ruta: _ruta,
      modo: _modo,
      estadoModo: _estadoModo,
      distanciaM: r?.distanciaM ?? 0,
      tiempoMovimientoS: (r?.tiempoMovimientoS ?? 0) + _segundosEnCurso(),
      tiempoTotalS: _tiempoTotalS(),
      ritmoActualSKm: _estadoModo?.fase == FaseModo.descansando
          ? _ritmoCongelado
          : r?.ritmoActualSKm,
      ritmoMedioSKm: r?.ritmoMedioSKm,
      resumen: _fase == FaseGrabacion.terminada ? r : null,
      error: _error,
      sinSenal: _sinSenal,
      falloCierre: _falloCierre,
      ocupado: _cerrando,
    );
  }

  void _publicar() => state = _estado();
}

final grabacionProvider = NotifierProvider<GrabacionNotifier, GrabacionState>(
  GrabacionNotifier.new,
);
