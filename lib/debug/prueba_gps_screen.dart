import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/carrera_calculos.dart';
import '../core/carreras_db.dart';
import '../models/tipo_actividad.dart';
import '../theme/app_colors.dart';
import 'informe_gps.dart';

/// Pantalla temporal para comprobar que la grabación sobrevive con la
/// pantalla apagada. Se elimina cuando la grabación real esté probada.
class PruebaGpsScreen extends StatefulWidget {
  const PruebaGpsScreen({super.key});

  @override
  State<PruebaGpsScreen> createState() => _PruebaGpsScreenState();
}

class _PruebaGpsScreenState extends State<PruebaGpsScreen> {
  final _hora = DateFormat('HH:mm:ss');
  CarrerasDb? _db;
  String? _carreraId;
  StreamSubscription<Position>? _sub;
  Timer? _reloj;
  DateTime? _inicio;
  DateTime? _ultimo;
  int _guardados = 0;
  String _permiso = 'Sin comprobar';
  String? _error;
  InformeGps? _informe;
  TipoActividad _tipo = TipoActividad.correr;

  bool get _grabando => _sub != null;

  @override
  void initState() {
    super.initState();
    _recuperarPendiente();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reloj?.cancel();
    // No cierra la base: sqflite comparte la conexión con la grabación real.
    super.dispose();
  }

  /// Si la app murió a media prueba, muestra lo que alcanzó a guardar.
  Future<void> _recuperarPendiente() async {
    final db = _db = await CarrerasDb.abrir();
    final pendiente = await db.carreraSinTerminar(origen: origenPrueba);
    if (pendiente == null) return;
    final puntos = await db.puntos(pendiente.id);
    await db.terminar(
      pendiente.id,
      distanciaM: 0,
      tiempoMovimientoS: 0,
      fin: puntos.isEmpty ? null : puntos.last.instante,
    );
    if (!mounted) return;
    setState(() {
      _carreraId = pendiente.id;
      _guardados = puntos.length;
      _inicio = pendiente.inicioUtc;
      _ultimo = puntos.isEmpty ? null : puntos.last.instante;
      _tipo = pendiente.tipo;
      _informe = construirInforme(pendiente.tipo, puntos);
      _error = 'La prueba anterior se cerró sin detenerla; este es su reporte.';
    });
  }

  Future<bool> _pedirPermisos() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _permiso = 'GPS apagado');
      return false;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    setState(
      () => _permiso = switch (permiso) {
        LocationPermission.whileInUse => 'Concedido (mientras se usa)',
        LocationPermission.always => 'Concedido (siempre)',
        LocationPermission.deniedForever => 'Denegado para siempre',
        _ => 'Denegado',
      },
    );
    if (permiso != LocationPermission.whileInUse &&
        permiso != LocationPermission.always) {
      return false;
    }
    // Sin este permiso (Android 13+) el aviso del servicio no se ve.
    await Permission.notification.request();
    return true;
  }

  Future<void> _iniciar() async {
    if (!await _pedirPermisos()) return;
    final db = _db ??= await CarrerasDb.abrir();
    final carrera = await db.crearCarrera(_tipo, origen: origenPrueba);
    setState(() {
      _carreraId = carrera.id;
      _inicio = DateTime.now().toUtc();
      _ultimo = null;
      _guardados = 0;
      _error = null;
      _informe = null;
    });
    // shortcut: solo configura Android; la prueba es solo para el KM7.
    _sub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Grabando carrera',
              notificationText: 'Hey, run! está registrando tu recorrido',
              enableWakeLock: true,
            ),
          ),
        ).listen(
          (pos) => _guardar(db, carrera.id, pos),
          onError: (Object e) => setState(() => _error = '$e'),
        );
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _guardar(CarrerasDb db, String carreraId, Position pos) async {
    final punto = PuntoGps(
      lat: pos.latitude,
      lng: pos.longitude,
      altitud: pos.altitude,
      precisionM: pos.accuracy,
      velocidad: pos.speed,
      instante: pos.timestamp,
    );
    try {
      await db.insertarPunto(carreraId, punto);
      if (!mounted) return;
      setState(() {
        _guardados++;
        _ultimo = punto.instante;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al guardar: $e');
    }
  }

  Future<void> _detener() async {
    await _sub?.cancel();
    _reloj?.cancel();
    final db = _db!;
    final id = _carreraId!;
    final puntos = await db.puntos(id);
    await db.terminar(id, distanciaM: 0, tiempoMovimientoS: 0);
    if (!mounted) return;
    setState(() {
      _sub = null;
      _reloj = null;
      _informe = construirInforme(_tipo, puntos);
    });
  }

  String _transcurrido() {
    final inicio = _inicio;
    if (inicio == null) return '--:--:--';
    final fin = _grabando ? DateTime.now().toUtc() : (_ultimo ?? inicio);
    final d = fin.difference(inicio);
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.inHours)}:${dos(d.inMinutes % 60)}:${dos(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final informe = _informe;
    final estilo = TextStyle(color: c.textoPrincipal, fontSize: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba GPS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Permiso: $_permiso', style: estilo),
          const SizedBox(height: 8),
          Text('Puntos guardados: $_guardados', style: estilo),
          Text('Tiempo: ${_transcurrido()}', style: estilo),
          Text(
            'Último punto: ${_ultimo == null ? '-' : _hora.format(_ultimo!.toLocal())}',
            style: estilo,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: c.errorTexto)),
          ],
          const SizedBox(height: 16),
          SegmentedButton<TipoActividad>(
            segments: [
              for (final t in TipoActividad.values)
                ButtonSegment(value: t, label: Text(t.etiqueta)),
            ],
            selected: {_tipo},
            onSelectionChanged: _grabando
                ? null
                : (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _grabando ? _detener : _iniciar,
            child: Text(_grabando ? 'Detener' : 'Iniciar'),
          ),
          if (informe != null) ...[
            const SizedBox(height: 24),
            Text(
              'Reporte',
              style: estilo.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(informe.comoTexto(), style: estilo),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: informe.comoTexto()),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reporte copiado')),
                  );
                }
              },
              child: const Text('Copiar reporte'),
            ),
          ],
        ],
      ),
    );
  }
}
