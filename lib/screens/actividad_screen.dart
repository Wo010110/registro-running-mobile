import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/carrera_calculos.dart';
import '../core/formato.dart';
import '../core/motor_modos.dart';
import '../core/permisos_gps.dart';
import '../models/modo_actividad.dart';
import '../models/tipo_actividad.dart';
import '../providers/grabacion_provider.dart';
import '../providers/modo_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/actividad_paneles.dart';
import '../widgets/ayuda_bateria.dart';
import '../widgets/dato_actividad.dart';
import '../widgets/dialogo_hey.dart';
import '../widgets/mapa_recorrido.dart';
import '../widgets/modos_panel.dart';
import 'resumen_screen.dart';

const _duracionTransicion = Duration(milliseconds: 900);

/// Nueva actividad y grabación en una sola pantalla: con el mapa difuminado
/// se prepara (GPS, tipo, temporizador); al iniciar el panel se desvanece, el
/// mapa se ve nítido y aparecen el tiempo, los datos y los botones.
class ActividadScreen extends ConsumerStatefulWidget {
  const ActividadScreen({super.key});

  @override
  ConsumerState<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends ConsumerState<ActividadScreen>
    with WidgetsBindingObserver {
  var _tipo = TipoActividad.correr;
  PermisoUbicacion? _permiso;
  var _notificaciones = true;
  var _iniciando = false;
  var _temporizadorS = 0;
  int? _cuenta;
  Timer? _reloj;
  var _enResumen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final g = ref.read(grabacionProvider);
    if (g.enCurso) {
      // Se vuelve a una actividad que ya está grabando.
      _tipo = g.tipo;
    } else if (g.fase == FaseGrabacion.terminada) {
      // Terminó sola (intervalos o meta) mientras no se estaba en esta pantalla.
      WidgetsBinding.instance.addPostFrameCallback((_) => _irAlResumen());
    } else {
      _comprobar();
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema se vuelve a comprobar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed &&
        !ref.read(grabacionProvider).enCurso &&
        _permiso != PermisoUbicacion.concedido) {
      _comprobar();
    }
  }

  Future<void> _comprobar() async {
    final permiso = await pedirUbicacion();
    final notificaciones = permiso == PermisoUbicacion.concedido
        ? await pedirNotificaciones()
        : _notificaciones;
    if (!mounted) return;
    setState(() {
      _permiso = permiso;
      _notificaciones = notificaciones;
    });
    if (permiso == PermisoUbicacion.concedido) {
      await ref.read(grabacionProvider.notifier).preparar(_tipo);
    }
  }

  void _alternarTipo() {
    setState(() {
      _tipo = _tipo == TipoActividad.correr
          ? TipoActividad.caminar
          : TipoActividad.correr;
    });
    ref.read(grabacionProvider.notifier).cambiarTipo(_tipo);
  }

  Future<void> _elegirTemporizador() async {
    final c = AppColors.of(context);
    var valor = _temporizadorS;
    final elegido = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.superficie,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setHoja) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TEMPORIZADOR DE SALIDA',
                  style: TextStyle(
                    color: c.textoPrincipal,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  valor == 0 ? 'Sin temporizador' : '$valor segundos',
                  style: TextStyle(
                    color: c.primario,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Slider(
                  value: valor.toDouble(),
                  max: 30,
                  divisions: 30,
                  label: valor == 0 ? 'Sin' : '$valor s',
                  onChanged: (v) => setHoja(() => valor = v.round()),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(valor),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  child: const Text('LISTO'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (elegido != null && mounted) setState(() => _temporizadorS = elegido);
  }

  Future<void> _alPulsarIniciar() async {
    if (_iniciando) return;
    setState(() => _iniciando = true);
    await mostrarAyudaBateriaSiToca(context, ref);
    if (!mounted) return;
    if (_temporizadorS == 0) {
      await _arrancar();
      return;
    }
    setState(() => _cuenta = _temporizadorS);
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      final restante = (_cuenta ?? 1) - 1;
      if (restante <= 0) {
        t.cancel();
        _arrancar();
      } else if (mounted) {
        setState(() => _cuenta = restante);
      }
    });
  }

  void _cancelarCuenta() {
    _reloj?.cancel();
    setState(() {
      _cuenta = null;
      _iniciando = false;
    });
  }

  Future<void> _arrancar() async {
    final notifier = ref.read(grabacionProvider.notifier);
    notifier.cambiarModo(ref.read(seleccionModoProvider).modo);
    await notifier.iniciar();
    if (!mounted) return;
    setState(() {
      _cuenta = null;
      _iniciando = false;
    });
  }

  /// Atrás no detiene la grabación: solo ofrece seguir en segundo plano.
  Future<void> _salir() async {
    final seguir = await confirmarHey(
      context,
      titulo: 'La actividad sigue grabando',
      mensaje:
          'Puedes seguir en segundo plano y volver desde el inicio con el '
          'botón central.',
      confirmar: 'Seguir en segundo plano',
      cancelar: 'Quedarme aquí',
    );
    if (seguir && mounted) Navigator.of(context).pop();
  }

  Future<void> _finalizar() async {
    final confirmado = await confirmarHey(
      context,
      titulo: '¿Finalizar la actividad?',
      confirmar: 'Finalizar',
      cancelar: 'Seguir',
    );
    if (!confirmado || !mounted) return;
    await _cerrar();
  }

  /// También reintenta cuando terminar falló al guardar; al quedar terminada
  /// la pantalla pasa sola al resumen.
  Future<void> _cerrar() => ref.read(grabacionProvider.notifier).terminar();

  /// También se llega aquí cuando la actividad termina sola (modos).
  Future<void> _irAlResumen() async {
    if (_enResumen || !mounted) return;
    _enResumen = true;
    // Si hay un diálogo abierto, se cierra para dejar esta pantalla encima.
    final ruta = ModalRoute.of(context)!;
    Navigator.of(context).popUntil((r) => r == ruta);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ResumenScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Solo si hay actividad en curso: el tick del cronómetro no reconstruye
    // la pantalla.
    final enCurso = ref.watch(grabacionProvider.select((g) => g.enCurso));
    final arriba = MediaQuery.paddingOf(context).top;
    ref.listen(grabacionProvider.select((g) => g.fase), (_, fase) {
      if (fase == FaseGrabacion.terminada) _irAlResumen();
    });
    return PopScope(
      canPop: !enCurso,
      onPopInvokedWithResult: (salio, _) {
        if (salio) {
          ref.read(grabacionProvider.notifier).cancelarPreparacion();
        } else {
          _salir();
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _MapaEnVivo(),
            // El difuminado baja a pasos de 2 al iniciar (el filtro solo se
            // recalcula en cada paso, no en cada fotograma) y, sin él, la capa
            // se quita para que no cueste nada con el mapa en movimiento.
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: enCurso ? 0 : 6),
                duration: _duracionTransicion,
                builder: (_, valor, _) {
                  final sigma = (valor / 2).round() * 2.0;
                  return sigma == 0
                      ? const SizedBox.shrink()
                      : AbsorbPointer(
                          absorbing: !enCurso,
                          child: RepaintBoundary(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: sigma,
                                sigmaY: sigma,
                              ),
                              child: ColoredBox(
                                color: c.fondo.withValues(alpha: .12),
                              ),
                            ),
                          ),
                        );
                },
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: _duracionTransicion,
                switchOutCurve: Curves.easeInOut,
                // El panel se desvanece encogiéndose un poco; la vista de
                // grabación entra sola, con el pop de cada pieza.
                transitionBuilder: (hijo, anim) =>
                    hijo.key == const ValueKey('grabando')
                    ? hijo
                    : FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.88,
                            end: 1,
                          ).animate(anim),
                          child: hijo,
                        ),
                      ),
                layoutBuilder: (actual, anteriores) => Stack(
                  fit: StackFit.expand,
                  children: [...anteriores, ?actual],
                ),
                child: enCurso
                    ? _VistaGrabando(
                        key: const ValueKey('grabando'),
                        onFinalizar: _finalizar,
                        onReintentarCierre: _cerrar,
                      )
                    : Consumer(
                        key: const ValueKey('preparar'),
                        builder: (_, ref, _) => _VistaPreparar(
                          g: ref.watch(grabacionProvider),
                          permiso: _permiso,
                          notificaciones: _notificaciones,
                          tipo: _tipo,
                          temporizadorS: _temporizadorS,
                          cuenta: _cuenta,
                          iniciando: _iniciando,
                          onTipo: _iniciando ? null : _alternarTipo,
                          onTemporizador: _iniciando
                              ? null
                              : _elegirTemporizador,
                          onIniciar: _alPulsarIniciar,
                          onCancelarCuenta: _cancelarCuenta,
                          onReintentarPermiso: _comprobar,
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 12,
              top: arriba + 12,
              child: Material(
                color: c.superficie,
                elevation: 8,
                shadowColor: c.sombra,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: enCurso ? 'Seguir en segundo plano' : 'Volver',
                  icon: HugeIcon(
                    icon: enCurso
                        ? HugeIcons.strokeRoundedArrowDown01
                        : HugeIcons.strokeRoundedArrowLeft01,
                    color: c.textoPrincipal,
                  ),
                  onPressed: enCurso
                      ? _salir
                      : () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título, panel centrado con GPS, tipo, temporizador e Iniciar.
class _VistaPreparar extends StatelessWidget {
  const _VistaPreparar({
    required this.g,
    required this.permiso,
    required this.notificaciones,
    required this.tipo,
    required this.temporizadorS,
    required this.cuenta,
    required this.iniciando,
    required this.onTipo,
    required this.onTemporizador,
    required this.onIniciar,
    required this.onCancelarCuenta,
    required this.onReintentarPermiso,
  });

  final GrabacionState g;
  final PermisoUbicacion? permiso;
  final bool notificaciones;
  final TipoActividad tipo;
  final int temporizadorS;
  final int? cuenta;
  final bool iniciando;
  final VoidCallback? onTipo;
  final VoidCallback? onTemporizador;
  final VoidCallback onIniciar;
  final VoidCallback onCancelarCuenta;
  final VoidCallback onReintentarPermiso;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final precision = g.posicion?.precisionM;
    final concedido = permiso == PermisoUbicacion.concedido;
    final listo = precision != null && precision <= precisionMaxM;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: MediaQuery.paddingOf(context).top + 24,
          right: 20,
          child: Text(
            'NUEVA ACTIVIDAD',
            style: TextStyle(
              color: c.textoPrincipal,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: c.sombra,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
        // Los dos contenedores van agrupados en el centro: MODOS encima de
        // Nueva actividad.
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelPreparar(
                    oculto: cuenta != null,
                    colapsa: true,
                    child: cuenta != null
                        ? const SizedBox(width: double.infinity)
                        : ModosPanel(habilitado: !iniciando),
                  ),
                  _PanelPreparar(
                    oculto: cuenta != null,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: cuenta != null
                          ? _CuentaAtras(
                              segundos: cuenta!,
                              onCancelar: onCancelarCuenta,
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CabeceraGps(
                                  precisionM: concedido ? precision : null,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChipTipo(
                                        tipo: tipo,
                                        onTap: onTipo,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ChipTemporizador(
                                      segundos: temporizadorS,
                                      onTap: onTemporizador,
                                    ),
                                  ],
                                ),
                                if (g.error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    g.error!,
                                    style: TextStyle(color: c.errorTexto),
                                  ),
                                ],
                                ..._avisosPermisos(c),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: listo && !iniciando
                                      ? onIniciar
                                      : null,
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedPlay,
                                    color: listo && !iniciando
                                        ? c.sobreAccion
                                        : c.textoDeshabilitado,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'INICIAR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                                // Siempre ocupa su sitio para que el panel no
                                // cambie de tamaño al variar la señal.
                                Visibility(
                                  visible: !listo,
                                  maintainSize: true,
                                  maintainAnimation: true,
                                  maintainState: true,
                                  child: TextButton(
                                    onPressed: concedido && !iniciando
                                        ? onIniciar
                                        : null,
                                    child: const Text('INICIAR DE TODOS MODOS'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _avisosPermisos(AppColors c) {
    Widget aviso(String texto, String boton, VoidCallback alPulsar) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: TextStyle(color: c.errorTexto)),
          TextButton(onPressed: alPulsar, child: Text(boton)),
        ],
      ),
    );
    return [
      switch (permiso) {
        PermisoUbicacion.gpsApagado => aviso(
          'La ubicación del teléfono está apagada. Actívala para grabar.',
          'Abrir ajustes de ubicación',
          Geolocator.openLocationSettings,
        ),
        PermisoUbicacion.denegado => aviso(
          'Hey, run! necesita la ubicación mientras se usa para grabar tu recorrido.',
          'Volver a pedir permiso',
          onReintentarPermiso,
        ),
        PermisoUbicacion.denegadoParaSiempre => aviso(
          'El permiso de ubicación está bloqueado. Actívalo en los ajustes de la app.',
          'Abrir ajustes',
          openAppSettings,
        ),
        _ => const SizedBox.shrink(),
      },
      if (permiso == PermisoUbicacion.concedido && !notificaciones)
        aviso(
          'Sin el permiso de notificaciones no verás el aviso de que la actividad sigue grabando. Puedes grabar igual.',
          'Abrir ajustes',
          openAppSettings,
        ),
    ];
  }
}

class _CuentaAtras extends StatelessWidget {
  const _CuentaAtras({required this.segundos, required this.onCancelar});

  final int segundos;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Sin contenedor: el texto va directo sobre el mapa, con sombra para
    // que contraste.
    final sombra = [
      Shadow(color: c.fondo, blurRadius: 6),
      Shadow(color: c.fondo, blurRadius: 16),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'EMPECEMOS EN',
          style: TextStyle(
            color: c.textoPrincipal,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            shadows: sombra,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Text(
            '$segundos',
            key: ValueKey(segundos),
            style: TextStyle(
              color: c.primario,
              fontSize: 150,
              height: 1.05,
              fontWeight: FontWeight.w800,
              shadows: sombra,
            ),
          ),
        ),
        TextButton(
          onPressed: onCancelar,
          child: Text(
            'CANCELAR',
            style: TextStyle(
              color: c.errorTexto,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              shadows: sombra,
            ),
          ),
        ),
      ],
    );
  }
}

/// Contenedor de la vista de preparar. [oculto]: en la cuenta atrás se
/// desvanece y queda solo el mapa difuminado detrás; [colapsa] además lo
/// encoge hasta desaparecer.
class _PanelPreparar extends StatelessWidget {
  const _PanelPreparar({
    required this.oculto,
    required this.child,
    this.colapsa = false,
  });

  final bool oculto;
  final bool colapsa;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final alfa = oculto ? 0.0 : 1.0;
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: colapsa && !oculto ? 12 : 0),
        padding: colapsa && oculto ? EdgeInsets.zero : const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.superficie.withValues(alpha: alfa),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.borde.withValues(alpha: alfa)),
          boxShadow: [
            BoxShadow(
              color: oculto ? c.sombra.withValues(alpha: 0) : c.sombra,
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: colapsa
            ? AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: child,
              )
            : child,
      ),
    );
  }
}

/// El mapa solo se reconstruye cuando cambian la ruta o la posición, no con
/// el tick del cronómetro.
class _MapaEnVivo extends ConsumerWidget {
  const _MapaEnVivo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (ruta, posicion, enCurso) = ref.watch(
      grabacionProvider.select((g) => (g.ruta, g.posicion, g.enCurso)),
    );
    // Aislado: sus repintados (mosaicos, zoom) no arrastran a los paneles.
    return RepaintBoundary(
      child: MapaRecorrido(
        ruta: ruta,
        posicion: posicion,
        enVivo: true,
        atribucionArriba: true,
        acercar: enCurso,
        // Espera a que terminen las entradas de los paneles.
        retardoAcercar: const Duration(milliseconds: 800),
      ),
    );
  }
}

/// "245 / 400 m", "3,20 / 10 km" o "12:30 / 30:00".
String _textoProgreso(Medida medida, double progreso, double objetivo) {
  if (medida == Medida.tiempo) {
    return '${formatearMinSeg(progreso.floor())} / '
        '${formatearMinSeg(objetivo.round())}';
  }
  return objetivo < 1000
      ? '${progreso.floor()} / ${objetivo.round()} m'
      : '${formatearKm(progreso)} / '
            '${formatearDistanciaCorta(objetivo.round())}';
}

/// Tiempo y datos en un contenedor; debajo, Pausar y Finalizar flotando.
/// El marco no depende del estado: el cronómetro, los datos y los botones son
/// widgets aparte que se actualizan solos, así el tick de 1 s no reconstruye
/// el contenedor entero.
class _VistaGrabando extends StatelessWidget {
  const _VistaGrabando({
    super.key,
    required this.onFinalizar,
    required this.onReintentarCierre,
  });

  final VoidCallback onFinalizar;
  final VoidCallback onReintentarCierre;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EntradaPop(
                retardo: const Duration(milliseconds: 450),
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.superficie,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: c.borde),
                      boxShadow: [
                        BoxShadow(
                          color: c.sombra,
                          blurRadius: 22,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Cronometro(onReintentarCierre: onReintentarCierre),
                          const SizedBox(height: 14),
                          const _Datos(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Botones(onFinalizar: onFinalizar),
            ],
          ),
        ),
      ),
    );
  }
}

/// Repetición, cronómetro, estado, barra de progreso y avisos. Con un modo
/// activo el cronómetro es el del tramo o la cuenta atrás del descanso.
class _Cronometro extends ConsumerWidget {
  const _Cronometro({required this.onReintentarCierre});

  final VoidCallback onReintentarCierre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final g = ref.watch(grabacionProvider);
    final pausada = g.fase == FaseGrabacion.pausada;
    final e = g.estadoModo;
    final intervalos = g.modo is ModoIntervalos
        ? g.modo as ModoIntervalos
        : null;
    final meta = g.modo is ModoMeta ? g.modo as ModoMeta : null;
    final descansando = e?.fase == FaseModo.descansando;
    // Terminadas las repeticiones se sigue como en libre.
    final tramo =
        intervalos != null && e != null && e.fase != FaseModo.terminado;
    final pausaManual = pausada && !descansando;

    final String cronometro;
    if (descansando) {
      cronometro = intervalos!.descansoMedida == Medida.tiempo
          ? formatearTiempo(e!.restanteDescanso.ceil())
          : '${e!.restanteDescanso.ceil()} m';
    } else if (tramo) {
      cronometro = formatearTiempo(e.tiempoTramoS);
    } else {
      cronometro = formatearTiempo(g.tiempoTotalS);
    }

    // Barra: del tramo, del descanso o hacia la meta.
    double? barra;
    String? textoBarra;
    if (descansando) {
      barra = 1 - e!.restanteDescanso / intervalos!.descanso;
      textoBarra =
          'de ${intervalos.descansoMedida == Medida.tiempo ? formatearDuracionCorta(intervalos.descanso) : formatearDistanciaCorta(intervalos.descanso)}';
    } else if (tramo) {
      barra = e.progreso / e.objetivo;
      textoBarra = _textoProgreso(
        intervalos.tramoMedida,
        e.progreso,
        e.objetivo,
      );
    } else if (meta != null && e != null) {
      barra = e.progreso / e.objetivo;
      textoBarra = _textoProgreso(meta.medida, e.progreso, e.objetivo);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (intervalos != null && e != null)
          Text(
            e.fase == FaseModo.terminado
                ? 'Intervalos completados'
                : intervalos.repeticiones == null
                ? 'Repetición ${e.repeticion}'
                : 'Repetición ${e.repeticion} de ${intervalos.repeticiones}',
            style: TextStyle(
              color: c.textoSecundario,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        FittedBox(
          child: Text(
            cronometro,
            style: TextStyle(
              color: descansando
                  ? c.primario
                  : pausaManual
                  ? c.textoTenue
                  : c.textoPrincipal,
              fontSize: 52,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        // Línea de estado con altura fija: pausar o perder la señal no cambia
        // el tamaño del contenedor.
        SizedBox(
          height: 24,
          child: Center(
            child: g.sinSenal
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        color: c.errorTexto,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sin señal GPS. Reintentando…',
                        style: TextStyle(color: c.errorTexto, fontSize: 14),
                      ),
                    ],
                  )
                : descansando
                ? Text(
                    'Descanso',
                    style: TextStyle(
                      color: c.primario,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  )
                : Text(
                    pausaManual ? 'En pausa' : '',
                    style: TextStyle(color: c.textoTenue, fontSize: 15),
                  ),
          ),
        ),
        if (barra != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barra.clamp(0.0, 1.0),
              minHeight: 8,
              color: descansando ? c.primario : c.accion,
              backgroundColor: c.primarioSuave,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            textoBarra!,
            style: TextStyle(
              color: c.textoSecundario,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (g.error != null)
          Text(
            g.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.errorTexto, fontSize: 13),
          ),
        if (g.falloCierre) ...[
          Text(
            'No se pudo guardar. Tus puntos siguen en el teléfono.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.errorTexto, fontSize: 13),
          ),
          TextButton(
            onPressed: g.ocupado ? null : onReintentarCierre,
            child: const Text('Reintentar'),
          ),
        ],
      ],
    );
  }
}

/// Kilómetros y los dos ritmos; solo cambian con cada punto del GPS.
class _Datos extends ConsumerWidget {
  const _Datos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (km, ritmoActual, ritmoMedio, ritmoTramo) = ref.watch(
      grabacionProvider.select(
        (g) => (
          g.distanciaM,
          g.ritmoActualSKm,
          g.ritmoMedioSKm,
          // null fuera de los intervalos o cuando ya terminaron.
          g.modo is ModoIntervalos && g.estadoModo?.fase != FaseModo.terminado
              ? (g.estadoModo?.ritmoTramoSKm ?? -1)
              : null,
        ),
      ),
    );
    return Row(
      children: [
        DatoActividad('Kilómetros', formatearKm(km)),
        DatoActividad(
          'Ritmo actual',
          formatearRitmo(ritmoActual),
          unidad: '/km',
        ),
        if (ritmoTramo != null)
          DatoActividad(
            'Ritmo del tramo',
            formatearRitmo(ritmoTramo < 0 ? null : ritmoTramo),
            unidad: '/km',
          )
        else
          DatoActividad(
            'Ritmo medio',
            formatearRitmo(ritmoMedio),
            unidad: '/km',
          ),
      ],
    );
  }
}

/// Pausar / Reanudar / Saltar descanso y Finalizar.
class _Botones extends ConsumerWidget {
  const _Botones({required this.onFinalizar});

  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(grabacionProvider.notifier);
    final (pausada, descansando, ocupado, falloCierre) = ref.watch(
      grabacionProvider.select(
        (g) => (
          g.fase == FaseGrabacion.pausada,
          g.estadoModo?.fase == FaseModo.descansando,
          g.ocupado,
          g.falloCierre,
        ),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: EntradaPop(
            retardo: const Duration(milliseconds: 650),
            child: RepaintBoundary(
              child: descansando
                  ? BotonFlotante(
                      principal: true,
                      texto: 'SALTAR DESCANSO',
                      icono: HugeIcons.strokeRoundedNext,
                      onTap: ocupado ? null : notifier.saltarDescanso,
                    )
                  : BotonFlotante(
                      principal: true,
                      texto: pausada ? 'REANUDAR' : 'PAUSAR',
                      icono: pausada
                          ? HugeIcons.strokeRoundedPlay
                          : HugeIcons.strokeRoundedPause,
                      onTap: ocupado || falloCierre
                          ? null
                          : pausada
                          ? notifier.reanudar
                          : notifier.pausar,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EntradaPop(
            retardo: const Duration(milliseconds: 800),
            child: RepaintBoundary(
              child: BotonFlotante(
                texto: 'FINALIZAR',
                icono: HugeIcons.strokeRoundedStop,
                onTap: ocupado ? null : onFinalizar,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
