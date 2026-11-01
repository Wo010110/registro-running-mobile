import 'dart:async';

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

/// Zoom largo: de la vista del mundo a la primera posición, y al empezar.
const _duracionZoom = Duration(milliseconds: 1600);

/// Desplazamiento de la cámara a cada posición nueva.
const _duracionPaso = Duration(milliseconds: 900);

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
    this.retardoAcercar = Duration.zero,
    this.interactivo = true,
  });

  /// Trozos de la línea (uno por tramo entre pausas).
  final List<List<PuntoGps>> ruta;
  final PuntoGps? posicion;
  final bool enVivo;

  /// Sube el botón "i" y el de recentrar a la esquina superior derecha, para
  /// cuando hay paneles flotantes abajo.
  final bool atribucionArriba;

  /// Acerca el mapa al punto GPS con una animación de zoom; se activa al
  /// empezar la actividad.
  final bool acercar;

  /// Espera antes de acercar, para que el zoom no compita con las entradas de
  /// los paneles.
  final Duration retardoAcercar;

  /// false: sin gestos (mapa pequeño de solo lectura).
  final bool interactivo;

  @override
  State<MapaRecorrido> createState() => _MapaRecorridoState();
}

class _MapaRecorridoState extends State<MapaRecorrido>
    with SingleTickerProviderStateMixin {
  final _mapa = MapController();
  late final AnimationController _anim;
  Timer? _espera;
  var _acercarPendiente = false;
  var _esperaTerminada = false;
  LatLng? _ultimaPos;
  var _listo = false;
  var _seguir = true;
  var _centrado = false;
  var _lineas = <List<LatLng>>[];
  var _puntosLinea = 0;

  // Movimiento de cámara en curso: se interpola del estado de salida al de
  // llegada con [_curva].
  var _centroDesde = const LatLng(0, 0);
  var _zoomDesde = _zoomGrabando;
  var _zoomHasta = _zoomGrabando;
  LatLng? _centroHasta;
  Curve _curva = Curves.easeOut;

  /// En un zoom largo el centro de llegada es la posición viva, que sigue
  /// llegando mientras dura.
  var _sigueVivo = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)..addListener(_pasoCamara);
    _actualizarLinea();
  }

  @override
  void didUpdateWidget(MapaRecorrido anterior) {
    super.didUpdateWidget(anterior);
    _actualizarLinea();
    _ultimaPos = _actual ?? _ultimaPos;
    if (widget.acercar && !anterior.acercar) {
      _acercarPendiente = true;
      _espera?.cancel();
      _esperaTerminada = widget.retardoAcercar == Duration.zero;
      if (!_esperaTerminada) {
        _espera = Timer(widget.retardoAcercar, () {
          _esperaTerminada = true;
          _acercar();
        });
      }
    }
    if (_acercarPendiente && _esperaTerminada) _acercar();
    if (widget.enVivo &&
        _seguir &&
        widget.posicion != anterior.posicion &&
        !(_anim.isAnimating && _sigueVivo)) {
      _centrar();
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _anim.dispose();
    _mapa.dispose();
    super.dispose();
  }

  /// Mueve la cámara hasta [zoom] y la posición actual con una animación. Una
  /// nueva cancela la anterior y parte de donde esté la cámara en ese momento.
  void _irA(double zoom, Duration duracion, Curve curva, {bool vivo = false}) {
    final destino = _actual ?? _ultimaPos;
    if (!_listo || destino == null) return;
    final camara = _mapa.camera;
    _centroDesde = camara.center;
    _zoomDesde = camara.zoom;
    _centroHasta = destino;
    _zoomHasta = zoom;
    _curva = curva;
    _sigueVivo = vivo && (zoom - camara.zoom).abs() > 0.01;
    _anim.duration = duracion;
    _anim.forward(from: 0);
  }

  void _pasoCamara() {
    final destino = _sigueVivo ? (_actual ?? _ultimaPos) : _centroHasta;
    if (!_listo || destino == null) return;
    final t = _curva.transform(_anim.value);
    double entre(double a, double b) => a + (b - a) * t;
    _mapa.move(
      LatLng(
        entre(_centroDesde.latitude, destino.latitude),
        entre(_centroDesde.longitude, destino.longitude),
      ),
      entre(_zoomDesde, _zoomHasta),
    );
  }

  /// Zoom suave hasta [_zoomCerca], siguiendo el punto GPS. Al iniciar la
  /// actividad la posición queda vacía hasta el primer punto del servicio:
  /// se usa la última conocida y, si no hay ninguna, se reintenta en cada
  /// actualización.
  void _acercar() {
    if (!_listo || (_actual ?? _ultimaPos) == null) return;
    _acercarPendiente = false;
    _seguir = true;
    _centrado = true;
    _irA(_zoomCerca, _duracionZoom, Curves.easeInOutCubic, vivo: true);
  }

  // shortcut: reconvierte todos los trozos cuando crece la ruta; con ~5400
  // puntos es barato, mejorar solo si se graban actividades de varias horas.
  void _actualizarLinea() {
    final total = widget.ruta.fold(0, (n, t) => n + t.length);
    if (total == _puntosLinea && widget.ruta.length == _lineas.length) return;
    _puntosLinea = total;
    _lineas = [
      for (final t in widget.ruta) [for (final p in t) LatLng(p.lat, p.lng)],
    ];
  }

  LatLng? get _actual {
    final p = widget.posicion;
    return p == null ? null : LatLng(p.lat, p.lng);
  }

  /// Del último punto aceptado a la posición actual, para que la línea llegue
  /// al marcador aunque el filtro haya descartado los últimos movimientos.
  /// Solo visual: no entra en la distancia ni en la base. Tras una pausa el
  /// trozo nuevo está vacío y no se dibuja hasta tener su primer punto.
  List<LatLng>? get _tramoVivo {
    final p = widget.posicion;
    if (!widget.enVivo || p == null || _lineas.isEmpty) return null;
    if (_lineas.last.isEmpty || p.precisionM > precisionMaxM) return null;
    return [_lineas.last.last, LatLng(p.lat, p.lng)];
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
    if (!_listo || _actual == null) return;
    if (_centrado) {
      _irA(_mapa.camera.zoom, _duracionPaso, Curves.easeOut);
      return;
    }
    // Primera posición: del zoom del mundo (si no había ninguna) al de
    // grabación.
    _centrado = true;
    final zoom = widget.acercar ? _zoomCerca : _zoomGrabando;
    final cambia = (zoom - _mapa.camera.zoom).abs() > 0.01;
    _irA(
      zoom,
      cambia ? _duracionZoom : _duracionPaso,
      cambia ? Curves.easeInOutCubic : Curves.easeOut,
      vivo: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fija = !widget.enVivo && _puntosLinea >= 2;
    final puntos = [for (final t in _lineas) ...t];
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter:
                _actual ?? (puntos.isEmpty ? const LatLng(0, 0) : puntos.last),
            initialZoom: _actual == null && puntos.isEmpty
                ? 2
                : (widget.acercar ? _zoomCerca : _zoomGrabando),
            maxZoom: _zoomMax,
            initialCameraFit: fija
                ? CameraFit.coordinates(
                    coordinates: puntos,
                    padding: const EdgeInsets.all(32),
                    maxZoom: 18,
                  )
                : null,
            backgroundColor: c.superficie,
            // Grabando (acercar) el mapa queda fijo al punto: solo se permite
            // el zoom con los dedos, así un arrastre sin querer no lo suelta.
            interactionOptions: InteractionOptions(
              flags: !widget.interactivo
                  ? InteractiveFlag.none
                  : widget.acercar
                  ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                  : InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _listo = true;
              if (widget.enVivo) _centrar();
            },
            onPositionChanged: (camara, porGesto) {
              if (porGesto && _anim.isAnimating) _anim.stop();
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
                for (final trozo in _lineas)
                  if (trozo.length >= 2)
                    Polyline(
                      points: trozo,
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
            if (fija)
              MarkerLayer(
                markers: [
                  Marker(
                    point: puntos.first,
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
                    point: puntos.last,
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
