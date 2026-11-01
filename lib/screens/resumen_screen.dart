import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../core/carreras_db.dart';
import '../core/formato.dart';
import '../core/historial.dart';
import '../models/intensidad.dart';
import '../models/modo_actividad.dart';
import '../models/tipo_actividad.dart';
import '../providers/grabacion_provider.dart';
import '../providers/historial_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/actividad_paneles.dart';
import '../widgets/dato_actividad.dart';
import '../widgets/dialogo_hey.dart';
import '../widgets/mapa_recorrido.dart';
import '../widgets/modos_panel.dart';

const _maxDescripcion = 500;
const _maxFotos = 5;

/// Resumen al terminar una actividad (GUARDAR / DESCARTAR) y, con [carrera],
/// edición de una ya guardada (GUARDAR / CANCELAR). Se pueden corregir el
/// tipo, el título, la descripción y cómo se sintió.
class ResumenScreen extends ConsumerStatefulWidget {
  const ResumenScreen({super.key, this.carrera});

  /// null: resumen de la actividad recién terminada.
  final CarreraLocal? carrera;

  @override
  ConsumerState<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends ConsumerState<ResumenScreen> {
  late TipoActividad _tipo;
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  int? _intensidad;
  var _guardando = false;
  String? _error;

  bool get _edicion => widget.carrera != null;

  DateTime? get _inicio =>
      widget.carrera?.inicioUtc ?? ref.read(grabacionProvider).inicioUtc;

  String get _propuesto {
    final inicio = _inicio;
    return inicio == null ? '' : tituloActividad(_tipo, inicio);
  }

  @override
  void initState() {
    super.initState();
    final c = widget.carrera;
    _tipo = c?.tipo ?? ref.read(grabacionProvider).tipo;
    _titulo = TextEditingController(text: c?.titulo ?? _propuesto);
    _descripcion = TextEditingController(text: c?.descripcion ?? '');
    _intensidad = c?.intensidad;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// Solo cambia la etiqueta; el título propuesto sigue al tipo mientras no
  /// se haya escrito otro.
  void _cambiarTipo(TipoActividad tipo) {
    setState(() {
      if (_titulo.text.trim() == _propuesto) {
        final inicio = _inicio;
        if (inicio != null) _titulo.text = tituloActividad(tipo, inicio);
      }
      _tipo = tipo;
    });
  }

  /// null si está vacío o es el propuesto: la tarjeta usa el propuesto.
  String? get _tituloAGuardar {
    final t = _titulo.text.trim();
    return t.isEmpty || t == _propuesto ? null : t;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final id = widget.carrera?.id ?? ref.read(grabacionProvider).carreraId;
      final descripcion = _descripcion.text.trim();
      await ref
          .read(carrerasDbProvider)
          .actualizarDetalles(
            id!,
            titulo: _tituloAGuardar,
            descripcion: descripcion.isEmpty ? null : descripcion,
            intensidad: _intensidad,
            tipo: _tipo,
          );
      if (_edicion) {
        ref.invalidate(historialProvider);
      } else {
        await ref.read(grabacionProvider.notifier).cerrar();
      }
      if (!mounted) return;
      if (_edicion) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _descartar() async {
    final confirmado = await confirmarHey(
      context,
      titulo: '¿Descartar la actividad?',
      mensaje: 'Se borrará del teléfono y no se podrá recuperar.',
      confirmar: 'Descartar',
      cancelar: 'Cancelar',
      destructivo: true,
    );
    if (!confirmado || !mounted) return;
    await ref.read(grabacionProvider.notifier).descartar();
    if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final g = ref.watch(grabacionProvider);
    final carrera = widget.carrera;
    final inicio = carrera?.inicioUtc ?? g.inicioUtc;
    final r = g.resumen;
    if (inicio == null || (!_edicion && r == null)) return const Scaffold();

    final modo = carrera != null ? carrera.modo : g.modo;
    final distanciaM = carrera?.distanciaM ?? r!.distanciaM;
    final tiempoS = carrera?.tiempoMovimientoS ?? g.tiempoTotalS;
    final movimientoS = carrera?.tiempoMovimientoS ?? r!.tiempoMovimientoS;
    final ritmo = carrera != null ? ritmoMedioSKm(carrera) : r!.ritmoMedioSKm;
    final recorrido = carrera == null
        ? null
        : ref.watch(recorridoProvider(carrera.id)).value;
    final ruta = carrera == null ? g.ruta : (recorrido?.ruta ?? const []);
    final parciales = carrera == null
        ? r!.parcialesS
        : (recorrido?.parciales ?? const <int>[]);
    final fecha = DateFormat(
      "d 'de' MMMM y, HH:mm",
      'es',
    ).format(inicio.toLocal());
    final ocupado = _guardando || (!_edicion && g.ocupado);

    return PopScope(
      // En el resumen, volver atrás guarda: así no se pierde la actividad.
      canPop: _edicion,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _guardar();
      },
      child: Scaffold(
        backgroundColor: c.superficie,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: c.fondo,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Volver',
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowLeft01,
                                color: c.textoPrincipal,
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _edicion ? 'EDITAR ACTIVIDAD' : 'RESUMEN',
                                style: TextStyle(
                                  color: c.textoPrincipal,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_tipo.etiqueta} · $fecha',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textoSecundario,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 180,
                            child: MapaRecorrido(
                              ruta: ruta,
                              interactivo: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          DatoActividad(
                            'Distancia',
                            formatearKm(distanciaM),
                            unidad: 'km',
                          ),
                          DatoActividad('Tiempo', formatearTiempo(tiempoS)),
                          DatoActividad(
                            // Los descansos son pausas: el ritmo es solo el
                            // de los tramos de carrera.
                            modo is ModoIntervalos ? 'Ritmo tramos' : 'Ritmo',
                            formatearRitmo(ritmo),
                            unidad: '/km',
                          ),
                        ],
                      ),
                      if ((tiempoS - movimientoS).abs() > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'En movimiento · ${formatearTiempo(movimientoS)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textoTenue, fontSize: 14),
                          ),
                        ),
                      const SizedBox(height: 20),
                      SegmentosHey<TipoActividad>(
                        opciones: [
                          for (final t in TipoActividad.values) (t, t.etiqueta),
                        ],
                        actual: _tipo,
                        onCambio: _cambiarTipo,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _titulo,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: 'Título',
                          hintText: _propuesto,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descripcion,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: _maxDescripcion,
                        // El contador "0/500" lo pinta el campo.
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _Seccion('¿Cómo te sentiste?'),
                      const SizedBox(height: 10),
                      _SelectorIntensidad(
                        actual: Intensidad.desdeNivel(_intensidad),
                        onCambio: (i) => setState(
                          // Tocar la elegida de nuevo la desmarca.
                          () => _intensidad = i?.nivel,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: _Seccion('Fotos')),
                          Text(
                            '0/$_maxFotos',
                            style: TextStyle(
                              color: c.textoTenue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _FilaFotos(),
                      const SizedBox(height: 24),
                      const _Seccion('Medalla y dorsal'),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Expanded(
                            child: _HuecoFoto(
                              icono: HugeIcons.strokeRoundedMedal01,
                              texto: 'Foto de tu medalla',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _HuecoFoto(
                              icono: HugeIcons.strokeRoundedTag01,
                              texto: 'Foto de tu dorsal',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Luego la IA los redibujará para tu actividad',
                        style: TextStyle(color: c.textoTenue, fontSize: 13),
                      ),
                      if (parciales.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'PARCIALES',
                          style: TextStyle(
                            color: c.textoPrincipal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        for (var i = 0; i < parciales.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Km ${i + 1}',
                                  style: TextStyle(
                                    color: c.textoSecundario,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  '${formatearRitmo(parciales[i].toDouble())} /km',
                                  style: TextStyle(
                                    color: c.textoPrincipal,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.errorTexto),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: BotonFlotante(
                            principal: true,
                            texto: 'GUARDAR',
                            icono: HugeIcons.strokeRoundedCheckmarkCircle02,
                            onTap: ocupado ? null : _guardar,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _edicion
                              ? BotonFlotante(
                                  texto: 'CANCELAR',
                                  icono: HugeIcons.strokeRoundedCancel01,
                                  onTap: _guardando
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                )
                              : BotonFlotante(
                                  destructivo: true,
                                  texto: 'DESCARTAR',
                                  icono: HugeIcons.strokeRoundedDelete02,
                                  onTap: ocupado ? null : _descartar,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      texto,
      style: TextStyle(
        color: c.textoPrincipal,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Color de cada nivel, de verde a rojo.
Color _colorIntensidad(AppColors c, Intensidad i) => switch (i) {
  Intensidad.muySuave => c.exito,
  Intensidad.suave => c.intensidadSuave,
  Intensidad.moderada => c.advertencia,
  Intensidad.dura => c.intensidadDura,
  Intensidad.maxima => c.error,
};

/// Cinco niveles en fila envolvente; al elegir uno sale su explicación.
class _SelectorIntensidad extends StatelessWidget {
  const _SelectorIntensidad({required this.actual, required this.onCambio});

  final Intensidad? actual;
  final ValueChanged<Intensidad?> onCambio;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in Intensidad.values)
              _OpcionIntensidad(
                intensidad: i,
                color: _colorIntensidad(c, i),
                elegida: i == actual,
                onTap: () => onCambio(i == actual ? null : i),
              ),
          ],
        ),
        if (actual != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              actual!.explicacion,
              style: TextStyle(color: c.textoSecundario, fontSize: 15),
            ),
          ),
      ],
    );
  }
}

class _OpcionIntensidad extends StatelessWidget {
  const _OpcionIntensidad({
    required this.intensidad,
    required this.color,
    required this.elegida,
    required this.onTap,
  });

  final Intensidad intensidad;
  final Color color;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: elegida ? color.withValues(alpha: .18) : c.fondo,
      shape: StadiumBorder(
        side: BorderSide(color: elegida ? color : c.borde, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox(width: 10, height: 10),
              ),
              const SizedBox(width: 8),
              Text(
                intensidad.nombre,
                style: TextStyle(
                  color: elegida ? c.textoPrincipal : c.textoSecundario,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _pronto(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Pronto podrás subir fotos')));
}

// shortcut: las fotos (de la actividad, medalla y dorsal) son solo esqueleto
// visual: no se elige ni se guarda nada. Falta decidir el almacenamiento (p.
// ej. Cloudflare R2); hacerlo junto con la sincronización con la nube.
class _FilaFotos extends StatelessWidget {
  const _FilaFotos();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _maxFotos,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          key: i == 0 ? const ValueKey('foto-mas') : null,
          width: 72,
          child: Material(
            color: c.fondo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.borde),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: i == 0 ? () => _pronto(context) : null,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  color: i == 0 ? c.primario : c.textoDeshabilitado,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HuecoFoto extends StatelessWidget {
  const _HuecoFoto({required this.icono, required this.texto});

  final List<List<dynamic>> icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pronto(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              HugeIcon(icon: icono, color: c.primario, size: 28),
              const SizedBox(height: 8),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textoSecundario,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
