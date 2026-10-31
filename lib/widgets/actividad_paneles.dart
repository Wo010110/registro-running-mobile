import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/tipo_actividad.dart';
import '../theme/app_colors.dart';

/// Punto azul con un anillo que se expande y se desvanece.
class PulsoGps extends StatefulWidget {
  const PulsoGps({super.key, this.tam = 22});

  final double tam;

  @override
  State<PulsoGps> createState() => _PulsoGpsState();
}

class _PulsoGpsState extends State<PulsoGps>
    with SingleTickerProviderStateMixin {
  Timer? _espera;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _espera?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: widget.tam,
      height: widget.tam,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1 - _anim.value,
              child: Container(
                width: widget.tam * (.35 + .65 * _anim.value),
                height: widget.tam * (.35 + .65 * _anim.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.primario.withValues(alpha: .35),
                ),
              ),
            ),
            Container(
              width: widget.tam * .38,
              height: widget.tam * .38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera del panel: pulso azul, "GPS" y barras de señal de color.
class CabeceraGps extends StatelessWidget {
  const CabeceraGps({super.key, required this.precisionM});

  /// null = todavía sin señal.
  final double? precisionM;

  /// Barras encendidas (0 a 4) y color según la precisión: menos metros,
  /// más señal.
  (int, Color) _nivel(AppColors c) {
    final p = precisionM;
    if (p == null) return (0, c.textoDeshabilitado);
    if (p <= 5) return (4, c.exito);
    if (p <= 10) return (3, c.exito);
    if (p <= 20) return (2, c.advertencia);
    return (1, c.error);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (barras, color) = _nivel(c);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const PulsoGps(),
        const SizedBox(width: 10),
        Text(
          'GPS',
          style: TextStyle(
            color: c.textoPrincipal,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 14),
        for (var i = 1; i <= 4; i++)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 5,
              height: 6.0 + i * 4,
              decoration: BoxDecoration(
                color: i <= barras ? color : c.divisor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ficha que alterna entre correr y caminar al tocarla.
class ChipTipo extends StatelessWidget {
  const ChipTipo({super.key, required this.tipo, required this.onTap});

  final TipoActividad tipo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final correr = tipo == TipoActividad.correr;
    return Material(
      color: c.primarioSuave,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              HugeIcon(
                icon: correr
                    ? HugeIcons.strokeRoundedRunningShoes
                    : HugeIcons.strokeRoundedFootprints,
                color: c.primario,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    correr ? 'INICIAR CARRERA' : 'INICIAR CAMINATA',
                    key: ValueKey(tipo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
                color: c.textoTenue,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ficha del temporizador de salida (0 = sin temporizador).
class ChipTemporizador extends StatelessWidget {
  const ChipTemporizador({
    super.key,
    required this.segundos,
    required this.onTap,
  });

  final int segundos;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final activo = segundos > 0;
    return Material(
      color: activo ? c.primarioSuave : c.fondo,
      shape: StadiumBorder(
        side: BorderSide(color: activo ? c.primario : c.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTimer02,
                color: activo ? c.primario : c.textoTenue,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                activo ? '$segundos S' : 'SIN',
                style: TextStyle(
                  color: activo ? c.textoPrincipal : c.textoSecundario,
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

/// Botón flotante con forma de píldora, para la vista de grabación.
class BotonFlotante extends StatelessWidget {
  const BotonFlotante({
    super.key,
    required this.texto,
    required this.icono,
    required this.onTap,
    this.principal = false,
    this.destructivo = false,
  });

  final String texto;
  final List<List<dynamic>> icono;
  final VoidCallback? onTap;
  final bool principal;

  /// Texto e ícono en rojo (acciones que borran).
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final habilitado = onTap != null;
    final fondo = principal ? c.accion : c.superficie;
    final color = !habilitado
        ? c.textoDeshabilitado
        : principal
        ? c.sobreAccion
        : destructivo
        ? c.errorTexto
        : c.textoPrincipal;
    return Material(
      color: habilitado || !principal ? fondo : c.borde,
      elevation: 9,
      shadowColor: c.sombra,
      shape: StadiumBorder(
        side: principal ? BorderSide.none : BorderSide(color: c.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(icon: icono, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada con efecto "pop": aparece creciendo con un pequeño rebote, tras
/// una espera opcional.
class EntradaPop extends StatefulWidget {
  const EntradaPop({
    super.key,
    required this.child,
    this.retardo = Duration.zero,
  });

  final Widget child;
  final Duration retardo;

  @override
  State<EntradaPop> createState() => _EntradaPopState();
}

class _EntradaPopState extends State<EntradaPop>
    with SingleTickerProviderStateMixin {
  Timer? _espera;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    _espera = Timer(widget.retardo, () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (_, hijo) {
        final escala = Curves.easeOutBack.transform(_anim.value);
        final opacidad = Curves.easeOut.transform(
          (_anim.value * 2).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: opacidad,
          child: Transform.scale(
            scale: 0.5 + 0.5 * escala,
            alignment: Alignment.bottomCenter,
            child: hijo,
          ),
        );
      },
    );
  }
}
