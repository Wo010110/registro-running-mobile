import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/carrera_calculos.dart';
import '../core/permisos_gps.dart';
import '../models/tipo_actividad.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/ayuda_bateria.dart';
import 'grabando_screen.dart';

class PrepararScreen extends ConsumerStatefulWidget {
  const PrepararScreen({super.key});

  @override
  ConsumerState<PrepararScreen> createState() => _PrepararScreenState();
}

class _PrepararScreenState extends ConsumerState<PrepararScreen>
    with WidgetsBindingObserver {
  var _tipo = TipoActividad.correr;
  PermisoUbicacion? _permiso;
  var _notificaciones = true;
  var _iniciando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _comprobar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes del sistema se vuelve a comprobar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed &&
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

  Future<void> _iniciar() async {
    if (_iniciando) return;
    setState(() => _iniciando = true);
    await mostrarAyudaBateriaSiToca(context, ref);
    final notifier = ref.read(grabacionProvider.notifier);
    await notifier.iniciar();
    if (!mounted) return;
    if (ref.read(grabacionProvider).fase == FaseGrabacion.grabando) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const GrabandoScreen()),
      );
    } else {
      setState(() => _iniciando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final grabacion = ref.watch(grabacionProvider);
    final precision = grabacion.posicion?.precisionM;
    final listo = precision != null && precision <= precisionMaxM;
    final concedido = _permiso == PermisoUbicacion.concedido;
    return PopScope(
      onPopInvokedWithResult: (salio, _) {
        if (salio) ref.read(grabacionProvider.notifier).cancelarPreparacion();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nueva actividad')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<TipoActividad>(
              segments: [
                for (final t in TipoActividad.values)
                  ButtonSegment(value: t, label: Text(t.etiqueta)),
              ],
              selected: {_tipo},
              onSelectionChanged: _iniciando
                  ? null
                  : (s) {
                      setState(() => _tipo = s.first);
                      ref.read(grabacionProvider.notifier).cambiarTipo(_tipo);
                    },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  color: listo ? c.exito : c.textoTenue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _textoGps(precision),
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (grabacion.error != null) ...[
              const SizedBox(height: 12),
              Text(grabacion.error!, style: TextStyle(color: c.errorTexto)),
            ],
            ..._avisosPermisos(c),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: listo && !_iniciando ? _iniciar : null,
              child: const Text('Iniciar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: concedido && !_iniciando ? _iniciar : null,
              child: const Text('Iniciar de todos modos'),
            ),
          ],
        ),
      ),
    );
  }

  String _textoGps(double? precision) {
    if (_permiso == null) return 'Comprobando permisos…';
    if (_permiso != PermisoUbicacion.concedido) return 'GPS no disponible';
    if (precision == null) return 'Buscando señal…';
    final txt = 'GPS listo ±${precision.round()} m';
    return precision <= precisionMaxM
        ? txt
        : 'Buscando señal… ±${precision.round()} m';
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
      switch (_permiso) {
        PermisoUbicacion.gpsApagado => aviso(
          'La ubicación del teléfono está apagada. Actívala para grabar.',
          'Abrir ajustes de ubicación',
          Geolocator.openLocationSettings,
        ),
        PermisoUbicacion.denegado => aviso(
          'Hey, run! necesita la ubicación mientras se usa para grabar tu recorrido.',
          'Volver a pedir permiso',
          _comprobar,
        ),
        PermisoUbicacion.denegadoParaSiempre => aviso(
          'El permiso de ubicación está bloqueado. Actívalo en los ajustes de la app.',
          'Abrir ajustes',
          openAppSettings,
        ),
        _ => const SizedBox.shrink(),
      },
      if (_permiso == PermisoUbicacion.concedido && !_notificaciones)
        aviso(
          'Sin el permiso de notificaciones no verás el aviso de que la actividad sigue grabando. Puedes grabar igual.',
          'Abrir ajustes',
          openAppSettings,
        ),
    ];
  }
}
