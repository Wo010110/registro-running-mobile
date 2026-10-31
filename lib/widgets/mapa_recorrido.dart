import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_config.dart';
import '../core/carrera_calculos.dart';
import '../theme/app_colors.dart';

const double _zoomMax = 20;
const double _zoomGrabando = 17;

/// Zoom al empezar la actividad: lo más cerca que permiten los mosaicos.
const double _zoomCerca = 19;
const double _grosorLinea = 7;

/// Mapa con la línea del recorrido. [enVivo]: sigue la posición hasta que el
/// usuario mueve el mapa y ofrece recentrar; si no, encuadra todo el recorrido.
class MapaRecorrido extends StatefulWidget {
  const MapaRecorrido({
    super.key,
    required this.ruta,
    this.posicion,
    this.enVivo = false,
    this.atribucionArriba = false,
    this.acercar = false,
  });

  final List<PuntoGps> ruta;
  final PuntoGps? posicion;
  final bool enVivo;

  /// Sube el botón "i" y el de recentrar a la esquina superior derecha, para
  /// cuando hay paneles flotantes abajo.
  final bool atribucionArriba;

  /// Acerca el mapa al punto GPS con una animación de zoom; se activa al
  /// empezar la actividad.
  final bool acercar;

  @override
  State<MapaRecorrido> createState() => _MapaRecorridoState();
}

class _MapaRecorridoState extends State<MapaRecorrido>
    with SingleTickerProviderStateMixin {
  final _mapa = MapController();
  late final AnimationController _zoomAnim;
  var _zoomDesde = _zoomGrabando;
  var _acercarPendiente = false;
  LatLng? _ultimaPos;
  var _listo = false;
  var _seguir = true;
  var _centrado = false;
  var _linea = <LatLng>[];

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addListener(_pasoZoom);
    _actualizarLinea();
  }

  @override
  void didUpdateWidget(MapaRecorrido anterior) {
    super.didUpdateWidget(anterior);
    _actualizarLinea();
    _ultimaPos = _actual ?? _ultimaPos;
    if (widget.acercar && !anterior.acercar) _acercarPendiente = true;
    if (_acercarPendiente) _acercar();
    if (widget.enVivo && _seguir && !_zoomAnim.isAnimating) _centrar();
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _mapa.dispose();
    super.dispose();
  }

  /// Zoom suave hasta [_zoomCerca], siguiendo el punto GPS. Al iniciar la
  /// actividad la posición queda vacía hasta el primer punto del servicio:
  /// se usa la última conocida y, si no hay ninguna, se reintenta en cada
  /// actualización.
  void _acercar() {
    final centro = _actual ?? _ultimaPos;
    if (!_listo || centro == null) return;
    _acercarPendiente = false;
    _zoomDesde = _mapa.camera.zoom;
    _seguir = true;
    _zoomAnim.forward(from: 0);
  }

  void _pasoZoom() {
    final centro = _actual ?? _ultimaPos;
    if (!_listo || centro == null) return;
    final t = Curves.easeInOutCubic.transform(_zoomAnim.value);
    _mapa.move(centro, _zoomDesde + (_zoomCerca - _zoomDesde) * t);
  }

  // shortcut: reconvierte toda la ruta cuando crece; con ~5400 puntos es
  // barato, mejorar solo si se graban actividades de varias horas.
  void _actualizarLinea() {
    if (_linea.length == widget.ruta.length) return;
    _linea = [for (final p in widget.ruta) LatLng(p.lat, p.lng)];
  }

  LatLng? get _actual {
    final p = widget.posicion;
    return p == null ? null : LatLng(p.lat, p.lng);
  }

  /// Del último punto aceptado a la posición actual, para que la línea llegue
  /// al marcador aunque el filtro haya descartado los últimos movimientos.
  /// Solo visual: no entra en la distancia ni en la base.
  List<LatLng>? get _tramoVivo {
    final p = widget.posicion;
    if (!widget.enVivo || p == null || _linea.isEmpty) return null;
    if (p.precisionM > precisionMaxM) return null;
    return [_linea.last, LatLng(p.lat, p.lng)];
  }

  // Único sitio donde se define el mapa base. Con MAPTILER_KEY: MapTiler
  // claro/oscuro según el tema (CARTO ya exige llave). Sin llave: OSM.
  // shortcut: OSM sin llave solo sirve para desarrollo (política de uso de
  // OSM); antes de publicar, la llave de MapTiler es obligatoria.
  TileLayer _capaTiles(BuildContext context) {
    if (mapTilerKey.isEmpty) {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.heyrun.mobile',
        maxNativeZoom: 19,
      );
    }
    return TileLayer(
      urlTemplate:
          'https://api.maptiler.com/maps/{style}/256/{z}/{x}/{y}{r}.png?key={key}',
      additionalOptions: {
        // dataviz-dark se veía gris lavado; streets-v2-dark es más negro.
        'style': Theme.of(context).brightness == Brightness.dark
            ? 'streets-v2-dark'
            : 'dataviz-light',
        'key': mapTilerKey,
      },
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'com.heyrun.mobile',
      maxNativeZoom: _zoomMax.toInt(),
    );
  }

  void _centrar() {
    final actual = _actual;
    if (!_listo || actual == null) return;
    _mapa.move(
      actual,
      _centrado
          ? _mapa.camera.zoom
          : (widget.acercar ? _zoomCerca : _zoomGrabando),
    );
    _centrado = true;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fija = !widget.enVivo && _linea.length >= 2;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter:
                _actual ?? (_linea.isEmpty ? const LatLng(0, 0) : _linea.last),
            initialZoom: _actual == null && _linea.isEmpty
                ? 2
                : (widget.acercar ? _zoomCerca : _zoomGrabando),
            maxZoom: _zoomMax,
            initialCameraFit: fija
                ? CameraFit.coordinates(
                    coordinates: _linea,
                    padding: const EdgeInsets.all(32),
                    maxZoom: 18,
                  )
                : null,
            backgroundColor: c.superficie,
            // Grabando (acercar) el mapa queda fijo al punto: solo se permite
            // el zoom con los dedos, así un arrastre sin querer no lo suelta.
            interactionOptions: InteractionOptions(
              flags: widget.acercar
                  ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                  : InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _listo = true;
              if (widget.enVivo) _centrar();
            },
            onPositionChanged: (camara, porGesto) {
              if (porGesto && _seguir && widget.enVivo && !widget.acercar) {
                setState(() => _seguir = false);
              }
            },
          ),
          children: [
            _capaTiles(context),
            PolylineLayer(
              polylines: [
                // flutter_map falla con una línea vacía (LatLngBounds).
                if (_linea.length >= 2)
                  Polyline(
                    points: _linea,
                    strokeWidth: _grosorLinea,
                    color: c.accion,
                    borderStrokeWidth: 1.5,
                    borderColor: c.sobreAccion,
                  ),
                if (_tramoVivo != null)
                  Polyline(
                    points: _tramoVivo!,
                    strokeWidth: _grosorLinea,
                    color: c.accion.withValues(alpha: 0.6),
                  ),
              ],
            ),
            if (widget.enVivo && _actual != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _actual!,
                    width: 22,
                    height: 22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.accion,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.sobreAccion, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            // Inicio y fin del recorrido terminado.
            if (!widget.enVivo && _linea.length >= 2)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _linea.first,
                    width: 18,
                    height: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.exito,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.sobreAccion, width: 3),
                      ),
                    ),
                  ),
                  Marker(
                    point: _linea.last,
                    width: 28,
                    height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.superficie,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.textoPrincipal, width: 2),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedFlag02,
                          color: c.textoPrincipal,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        // La atribución es obligatoria (licencias de OSM y MapTiler); queda
        // en un botón "i" que abre la lista de fuentes, como hace Strava.
        Positioned(
          left: widget.atribucionArriba ? null : 8,
          right: widget.atribucionArriba ? 12 : null,
          top: widget.atribucionArriba
              ? MediaQuery.paddingOf(context).top + 12
              : null,
          bottom: widget.atribucionArriba ? null : 8,
          child: Material(
            color: c.superficie,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _mostrarFuentes(context),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  color: c.textoSecundario,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (widget.enVivo && !_seguir)
          Positioned(
            right: 12,
            top: widget.atribucionArriba
                ? MediaQuery.paddingOf(context).top + 60
                : null,
            bottom: widget.atribucionArriba ? null : 12,
            child: FloatingActionButton.small(
              tooltip: 'Recentrar',
              backgroundColor: c.accion,
              onPressed: () {
                setState(() => _seguir = true);
                _centrar();
              },
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                color: c.sobreAccion,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  void _mostrarFuentes(BuildContext context) {
    final c = AppColors.of(context);
    final fuentes = [
      if (mapTilerKey.isNotEmpty) '© MapTiler',
      '© OpenStreetMap contributors',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.superficie,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Fuentes de datos del mapa',
                style: TextStyle(
                  color: c.textoPrincipal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(color: c.divisor, height: 1),
            for (final f in fuentes)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(f, style: TextStyle(color: c.textoPrincipal)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
