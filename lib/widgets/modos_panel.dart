import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/formato.dart';
import '../models/modo_actividad.dart';
import '../providers/modo_provider.dart';
import '../theme/app_colors.dart';

/// Contenido del contenedor MODOS: selector Libre / Intervalos / Meta, la
/// línea de configuración y el acceso a editarla.
class ModosPanel extends ConsumerWidget {
  const ModosPanel({super.key, required this.habilitado});

  /// false mientras se inicia la actividad.
  final bool habilitado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final sel = ref.watch(seleccionModoProvider);
    final notifier = ref.read(seleccionModoProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'MODOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textoPrincipal,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final tipo in TipoModo.values) ...[
              if (tipo != TipoModo.libre) const SizedBox(width: 6),
              Expanded(
                child: _Pildora(
                  texto: tipo.etiqueta,
                  activa: sel.tipo == tipo,
                  onTap: habilitado ? () => notifier.elegir(tipo) : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sel.modo.resumen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sel.tipo != TipoModo.libre)
                TextButton(
                  onPressed: habilitado
                      ? () => editarModo(context, sel.tipo)
                      : null,
                  child: const Text(
                    'EDITAR ›',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hoja inferior para configurar los intervalos o la meta.
Future<void> editarModo(BuildContext context, TipoModo tipo) {
  final c = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.superficie,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .75,
    ),
    builder: (_) => _HojaModo(tipo),
  );
}

/// Cada ajuste es una fila; al tocarla se despliega su rueda y se cierra la
/// que estuviera abierta.
class _HojaModo extends ConsumerStatefulWidget {
  const _HojaModo(this.tipo);

  final TipoModo tipo;

  @override
  ConsumerState<_HojaModo> createState() => _HojaModoState();
}

class _HojaModoState extends ConsumerState<_HojaModo> {
  String? _abierta;

  void _alternar(String fila) =>
      setState(() => _abierta = _abierta == fila ? null : fila);

  Widget _fila(String id, String valor, Widget editor) => _Fila(
    titulo: id,
    valor: valor,
    abierta: _abierta == id,
    onTap: () => _alternar(id),
    child: editor,
  );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sel = ref.watch(seleccionModoProvider);
    final notifier = ref.read(seleccionModoProvider.notifier);
    final i = sel.intervalos;
    final m = sel.meta;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tipo.etiqueta.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.tipo == TipoModo.intervalos) ...[
              _fila(
                'Correr',
                _valorMedida(i.tramoMedida, i.tramo),
                _EditorMedida(
                  opciones: const [Medida.distancia, Medida.tiempo],
                  medida: i.tramoMedida,
                  valor: i.tramo,
                  porDefecto: const {Medida.distancia: 400, Medida.tiempo: 120},
                  onCambio: (medida, valor) => notifier.guardarIntervalos(
                    i.copyWith(tramoMedida: medida, tramo: valor),
                  ),
                ),
              ),
              _fila(
                'Descanso',
                _valorMedida(i.descansoMedida, i.descanso),
                _EditorMedida(
                  opciones: const [Medida.tiempo, Medida.distancia],
                  medida: i.descansoMedida,
                  valor: i.descanso,
                  porDefecto: const {Medida.distancia: 100, Medida.tiempo: 90},
                  onCambio: (medida, valor) => notifier.guardarIntervalos(
                    i.copyWith(descansoMedida: medida, descanso: valor),
                  ),
                ),
              ),
              _fila(
                'Repeticiones',
                i.repeticiones?.toString() ?? '∞',
                _RuedaRepeticiones(
                  valor: i.repeticiones,
                  onCambio: (n) =>
                      notifier.guardarIntervalos(i.conRepeticiones(n)),
                ),
              ),
              _fila(
                'Al terminar',
                i.alTerminar.etiqueta,
                SegmentosHey<AlTerminarIntervalos>(
                  opciones: [
                    for (final a in AlTerminarIntervalos.values)
                      (a, a.etiqueta),
                  ],
                  actual: i.alTerminar,
                  onCambio: (a) =>
                      notifier.guardarIntervalos(i.copyWith(alTerminar: a)),
                ),
              ),
            ] else ...[
              _fila(
                'Objetivo',
                m.medida == Medida.tiempo
                    ? formatearHorasMin(m.valor)
                    : formatearDistanciaCorta(m.valor),
                _EditorMedida(
                  opciones: const [Medida.distancia, Medida.tiempo],
                  medida: m.medida,
                  valor: m.valor,
                  porDefecto: const {
                    Medida.distancia: 5000,
                    Medida.tiempo: 1800,
                  },
                  horas: true,
                  onCambio: (medida, valor) => notifier.guardarMeta(
                    m.copyWith(medida: medida, valor: valor),
                  ),
                ),
              ),
              if (m.medida == Medida.tiempo)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'El tiempo cuenta solo en movimiento, sin las pausas.',
                    style: TextStyle(color: c.textoTenue, fontSize: 13),
                  ),
                ),
              _fila(
                'Al llegar',
                m.alLlegar.etiqueta,
                SegmentosHey<AlLlegarMeta>(
                  opciones: [
                    for (final a in AlLlegarMeta.values) (a, a.etiqueta),
                  ],
                  actual: m.alLlegar,
                  onCambio: (a) =>
                      notifier.guardarMeta(m.copyWith(alLlegar: a)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
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
    );
  }
}

/// "400 m", "1,5 km" o "1:30".
String _valorMedida(Medida medida, int valor) => medida == Medida.distancia
    ? formatearDistanciaCorta(valor)
    : formatearMinSeg(valor);

/// "ETIQUETA ......... valor ›"; abierta, muestra [child] debajo.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.titulo,
    required this.valor,
    required this.abierta,
    required this.onTap,
    required this.child,
  });

  final String titulo;
  final String valor;
  final bool abierta;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: c.divisor, height: 1),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      color: c.textoTenue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    color: abierta ? c.primario : c.textoPrincipal,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: abierta ? .25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: c.textoTenue,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: abierta
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Selector de una línea con todas las opciones juntas.
class SegmentosHey<T> extends StatelessWidget {
  const SegmentosHey({
    super.key,
    required this.opciones,
    required this.actual,
    required this.onCambio,
  });

  final List<(T, String)> opciones;
  final T actual;
  final ValueChanged<T> onCambio;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.fondo,
        shape: StadiumBorder(side: BorderSide(color: c.borde)),
      ),
      child: Row(
        children: [
          for (final (valor, texto) in opciones)
            Expanded(
              child: Material(
                color: valor == actual ? c.primarioSuave : Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: valor == actual ? c.primario : Colors.transparent,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onCambio(valor),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 11,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          texto.toUpperCase(),
                          style: TextStyle(
                            color: valor == actual
                                ? c.textoPrincipal
                                : c.textoSecundario,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selector [Distancia | Tiempo] y, debajo, la rueda de la medida elegida.
/// Al cambiar de medida se parte de [porDefecto]. [horas]: el tiempo se elige
/// en horas y minutos (la meta) en vez de minutos y segundos.
class _EditorMedida extends StatelessWidget {
  const _EditorMedida({
    required this.opciones,
    required this.medida,
    required this.valor,
    required this.porDefecto,
    required this.onCambio,
    this.horas = false,
  });

  final List<Medida> opciones;
  final Medida medida;
  final int valor;
  final Map<Medida, int> porDefecto;
  final bool horas;
  final void Function(Medida medida, int valor) onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentosHey<Medida>(
          opciones: [
            for (final o in opciones)
              (o, o == Medida.distancia ? 'Distancia' : 'Tiempo'),
          ],
          actual: medida,
          onCambio: (m) {
            if (m != medida) onCambio(m, porDefecto[m]!);
          },
        ),
        const SizedBox(height: 8),
        if (medida == Medida.distancia)
          _RuedaDoble(
            key: const ValueKey('distancia'),
            pesoA: 1000,
            cantidadA: 43,
            unidadA: 'km',
            pesoB: 50,
            cantidadB: 20,
            unidadB: 'm',
            minimo: 50,
            valor: valor,
            onCambio: (v) => onCambio(medida, v),
          )
        else if (horas)
          _RuedaDoble(
            key: const ValueKey('horas'),
            pesoA: 3600,
            cantidadA: 25,
            unidadA: 'h',
            pesoB: 60,
            cantidadB: 60,
            unidadB: 'min',
            paso: 1,
            minimo: 60,
            maximo: 86400,
            valor: valor,
            onCambio: (v) => onCambio(medida, v),
          )
        else
          _RuedaDoble(
            key: const ValueKey('tiempo'),
            pesoA: 60,
            cantidadA: 60,
            unidadA: 'min',
            pesoB: 5,
            cantidadB: 12,
            unidadB: 's',
            minimo: 5,
            valor: valor,
            onCambio: (v) => onCambio(medida, v),
          ),
      ],
    );
  }
}

const _altoItem = 38.0;

Widget _picker(
  BuildContext context, {
  required FixedExtentScrollController controlador,
  required List<String> textos,
  required ValueChanged<int> onCambio,
  String? unidad,
}) {
  final c = AppColors.of(context);
  return Expanded(
    child: SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: CupertinoPicker(
              scrollController: controlador,
              itemExtent: _altoItem,
              onSelectedItemChanged: onCambio,
              selectionOverlay: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primarioSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              children: [
                for (final t in textos)
                  Center(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: c.textoPrincipal,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (unidad != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: Text(
                unidad,
                style: TextStyle(
                  color: c.textoSecundario,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Dos columnas: la A pesa [pesoA] unidades del valor por paso y la B,
/// [pesoB] (km y m, min y s, h y min). El valor guardado se redondea al paso
/// de B y nunca baja de [minimo].
class _RuedaDoble extends StatefulWidget {
  const _RuedaDoble({
    super.key,
    required this.pesoA,
    required this.cantidadA,
    required this.unidadA,
    required this.pesoB,
    required this.cantidadB,
    required this.unidadB,
    required this.minimo,
    required this.valor,
    required this.onCambio,
    this.paso,
    this.maximo,
  });

  final int pesoA;
  final int cantidadA;
  final String unidadA;
  final int pesoB;
  final int cantidadB;
  final String unidadB;
  final int minimo;
  final int valor;
  final ValueChanged<int> onCambio;

  /// Lo que sube el número mostrado en B por elemento; por defecto [pesoB]
  /// (m y s). En minutos de una hora es 1.
  final int? paso;

  /// Tope del valor; por defecto el de las dos columnas al máximo.
  final int? maximo;

  @override
  State<_RuedaDoble> createState() => _RuedaDobleState();
}

class _RuedaDobleState extends State<_RuedaDoble> {
  late int _a;
  late int _b;
  late final int _maximo =
      widget.maximo ??
      (widget.cantidadA - 1) * widget.pesoA +
          (widget.cantidadB - 1) * widget.pesoB;
  late final FixedExtentScrollController _ca;
  late final FixedExtentScrollController _cb;

  @override
  void initState() {
    super.initState();
    final w = widget;
    final total = ((w.valor / w.pesoB).round() * w.pesoB).clamp(
      w.minimo,
      _maximo,
    );
    _a = total ~/ w.pesoA;
    _b = total % w.pesoA ~/ w.pesoB;
    _ca = FixedExtentScrollController(initialItem: _a);
    _cb = FixedExtentScrollController(initialItem: _b);
  }

  @override
  void dispose() {
    _ca.dispose();
    _cb.dispose();
    super.dispose();
  }

  void _cambio({int? a, int? b}) {
    final w = widget;
    _a = a ?? _a;
    _b = b ?? _b;
    final total = _a * w.pesoA + _b * w.pesoB;
    final fijo = total.clamp(w.minimo, _maximo);
    if (fijo != total) {
      // Ni 0 ni más del tope (24 h con 0 min): la rueda vuelve al límite.
      _a = fijo ~/ w.pesoA;
      _b = fijo % w.pesoA ~/ w.pesoB;
      _ca.animateToItem(
        _a,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      _cb.animateToItem(
        _b,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      w.onCambio(fijo);
      return;
    }
    w.onCambio(total);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Row(
      children: [
        _picker(
          context,
          controlador: _ca,
          textos: [for (var i = 0; i < w.cantidadA; i++) '$i'],
          unidad: w.unidadA,
          onCambio: (i) => _cambio(a: i),
        ),
        _picker(
          context,
          controlador: _cb,
          textos: [
            for (var i = 0; i < w.cantidadB; i++) '${i * (w.paso ?? w.pesoB)}',
          ],
          unidad: w.unidadB,
          onCambio: (i) => _cambio(b: i),
        ),
      ],
    );
  }
}

/// 1 a 50 y, al final, ∞ (sin límite).
class _RuedaRepeticiones extends StatefulWidget {
  const _RuedaRepeticiones({required this.valor, required this.onCambio});

  final int? valor;
  final ValueChanged<int?> onCambio;

  @override
  State<_RuedaRepeticiones> createState() => _RuedaRepeticionesState();
}

class _RuedaRepeticionesState extends State<_RuedaRepeticiones> {
  static const _max = 50;
  late final _c = FixedExtentScrollController(
    initialItem: widget.valor == null ? _max : widget.valor!.clamp(1, _max) - 1,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _picker(
        context,
        controlador: _c,
        textos: [for (var i = 1; i <= _max; i++) '$i', '∞'],
        onCambio: (i) => widget.onCambio(i == _max ? null : i + 1),
      ),
    ],
  );
}

/// Opción en píldora; la activa lleva el tinte del primario.
class _Pildora extends StatelessWidget {
  const _Pildora({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: activa ? c.primarioSuave : c.fondo,
      shape: StadiumBorder(
        side: BorderSide(color: activa ? c.primario : c.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                texto.toUpperCase(),
                style: TextStyle(
                  color: onTap == null
                      ? c.textoDeshabilitado
                      : activa
                      ? c.textoPrincipal
                      : c.textoSecundario,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
