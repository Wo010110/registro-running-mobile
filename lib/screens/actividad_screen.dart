import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/carrera_calculos.dart';
import '../core/formato.dart';
import '../core/permisos_gps.dart';
import '../models/tipo_actividad.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/actividad_paneles.dart';
import '../widgets/ayuda_bateria.dart';
import '../widgets/dato_actividad.dart';
import '../widgets/dialogo_hey.dart';
import '../widgets/mapa_recorrido.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final g = ref.read(grabacionProvider);
    if (g.enCurso) {
      // Se vuelve a una actividad que ya está grabando.
      _tipo = g.tipo;
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
                  valor == 0 ? 'SIN TEMPORIZADOR' : '$valor SEGUNDOS',
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
    await ref.read(grabacionProvider.notifier).iniciar();
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

  /// También reintenta cuando terminar falló al guardar.
  Future<void> _cerrar() async {
    await ref.read(grabacionProvider.notifier).terminar();
    if (!mounted) return;
    if (ref.read(grabacionProvider).fase != FaseGrabacion.terminada) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ResumenScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final g = ref.watch(grabacionProvider);
    final enCurso = g.enCurso;
    final arriba = MediaQuery.paddingOf(context).top;
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
            MapaRecorrido(
              ruta: g.ruta,
              posicion: g.posicion,
              enVivo: true,
              atribucionArriba: true,
              acercar: enCurso,
            ),
            // El difuminado se quita de golpe al iniciar.
            if (!enCurso)
              Positioned.fill(
                child: AbsorbPointer(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: ColoredBox(color: c.fondo.withValues(alpha: .12)),
                  ),
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
                        g: g,
                        onFinalizar: _finalizar,
                        onReintentarCierre: _cerrar,
                      )
                    : _VistaPreparar(
                        key: const ValueKey('preparar'),
                        g: g,
                        permiso: _permiso,
                        notificaciones: _notificaciones,
                        tipo: _tipo,
                        temporizadorS: _temporizadorS,
                        cuenta: _cuenta,
                        iniciando: _iniciando,
                        onTipo: _iniciando ? null : _alternarTipo,
                        onTemporizador: _iniciando ? null : _elegirTemporizador,
                        onIniciar: _alPulsarIniciar,
                        onCancelarCuenta: _cancelarCuenta,
                        onReintentarPermiso: _comprobar,
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
    super.key,
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
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              // En la cuenta atrás el contenedor se desvanece y queda solo el
              // mapa difuminado detrás.
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: c.superficie.withValues(alpha: cuenta != null ? 0 : 1),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: c.borde.withValues(alpha: cuenta != null ? 0 : 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cuenta != null
                          ? c.sombra.withValues(alpha: 0)
                          : c.sombra,
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                                    child: ChipTipo(tipo: tipo, onTap: onTipo),
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

/// Tiempo y datos en un contenedor; debajo, Pausar y Finalizar flotando.
class _VistaGrabando extends ConsumerWidget {
  const _VistaGrabando({
    super.key,
    required this.g,
    required this.onFinalizar,
    required this.onReintentarCierre,
  });

  final GrabacionState g;
  final VoidCallback onFinalizar;
  final VoidCallback onReintentarCierre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final notifier = ref.read(grabacionProvider.notifier);
    final pausada = g.fase == FaseGrabacion.pausada;
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(
                            formatearTiempo(g.tiempoTotalS),
                            style: TextStyle(
                              color: pausada ? c.textoTenue : c.textoPrincipal,
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        // Línea de estado con altura fija: pausar o perder la
                        // señal no cambia el tamaño del contenedor.
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
                                        style: TextStyle(
                                          color: c.errorTexto,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    pausada ? 'En pausa' : '',
                                    style: TextStyle(
                                      color: c.textoTenue,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            DatoActividad(
                              'Kilómetros',
                              formatearKm(g.distanciaM),
                            ),
                            DatoActividad(
                              'Ritmo actual',
                              '${formatearRitmo(g.ritmoActualSKm)} /km',
                            ),
                            DatoActividad(
                              'Ritmo medio',
                              '${formatearRitmo(g.ritmoMedioSKm)} /km',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: EntradaPop(
                      retardo: const Duration(milliseconds: 650),
                      child: BotonFlotante(
                        principal: true,
                        texto: pausada ? 'REANUDAR' : 'PAUSAR',
                        icono: pausada
                            ? HugeIcons.strokeRoundedPlay
                            : HugeIcons.strokeRoundedPause,
                        onTap: g.ocupado || g.falloCierre
                            ? null
                            : pausada
                            ? notifier.reanudar
                            : notifier.pausar,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EntradaPop(
                      retardo: const Duration(milliseconds: 800),
                      child: BotonFlotante(
                        texto: 'FINALIZAR',
                        icono: HugeIcons.strokeRoundedStop,
                        onTap: g.ocupado ? null : onFinalizar,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
