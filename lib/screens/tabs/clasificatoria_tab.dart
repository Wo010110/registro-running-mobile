import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clasificatoria_ejemplo.dart';
import '../../core/formato.dart';
import '../../core/historial.dart';
import '../../models/clasificatoria.dart';
import '../../providers/auth_provider.dart';
import '../../providers/historial_provider.dart';
import '../../providers/navegacion_provider.dart';
import '../../providers/perfil_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/modos_panel.dart';
import '../../widgets/tarjeta.dart';

/// Clasificación por kilómetros de un período, de tu ciudad o global.
class ClasificatoriaTab extends ConsumerStatefulWidget {
  const ClasificatoriaTab({super.key});

  @override
  ConsumerState<ClasificatoriaTab> createState() => _ClasificatoriaTabState();
}

class _ClasificatoriaTabState extends ConsumerState<ClasificatoriaTab> {
  var _alcance = AlcanceClasificatoria.ciudad;
  var _periodo = PeriodoClasificatoria.semana;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nombre = ref.watch(authProvider.select((a) => a.user?.displayName));
    final ciudad = ref.watch(perfilLocalProvider.select((p) => p.ciudad));
    final historial = ref.watch(historialProvider).value ?? const [];
    final sinCiudad =
        _alcance == AlcanceClasificatoria.ciudad && ciudad.isEmpty;
    final filas = clasificatoriaEjemplo(
      alcance: _alcance,
      periodo: _periodo,
      tuNombre: nombre == null || nombre.isEmpty ? 'Tú' : nombre,
      tusKm: kmDelPeriodo(historial, _periodo, DateTime.now()),
    );
    final tu = filas.firstWhere((f) => f.esTu);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            children: [
              Text(
                'Clasificatoria',
                style: TextStyle(
                  color: c.textoPrincipal,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SegmentosHey<AlcanceClasificatoria>(
                opciones: [
                  for (final a in AlcanceClasificatoria.values) (a, a.etiqueta),
                ],
                actual: _alcance,
                onCambio: (a) => setState(() => _alcance = a),
              ),
              const SizedBox(height: 10),
              SegmentosHey<PeriodoClasificatoria>(
                opciones: [
                  for (final p in PeriodoClasificatoria.values) (p, p.etiqueta),
                ],
                actual: _periodo,
                onCambio: (p) => setState(() => _periodo = p),
              ),
              const SizedBox(height: 6),
              Text(
                'Datos de ejemplo',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textoTenue, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (sinCiudad)
                Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Elige tu ciudad para competir con los corredores de tu zona.',
                        style: TextStyle(color: c.textoSecundario, height: 1.3),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(pestanaProvider.notifier).ir(3),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        child: const Text('ELEGIR CIUDAD'),
                      ),
                    ],
                  ),
                )
              else ...[
                _Podio(filas.take(3).toList()),
                const SizedBox(height: 16),
                for (final f in filas.skip(3)) _Fila(f),
              ],
            ],
          ),
        ),
        if (!sinCiudad)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _Fila(tu, destacada: true),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.nombre, {this.tam = 40, this.destacado = false});

  final String nombre;
  final double tam;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.primarioSuave,
        border: Border.all(
          color: destacado ? c.primario : c.borde,
          width: destacado ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(
          nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
          style: TextStyle(
            color: c.primario,
            fontSize: tam * .42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _km(double km) => '${formatearKmUno(km)} km';

/// Primero al centro, segundo a la izquierda y tercero a la derecha.
class _Podio extends StatelessWidget {
  const _Podio(this.top);

  final List<FilaClasificatoria> top;

  @override
  Widget build(BuildContext context) {
    final orden = [
      if (top.length > 1) top[1],
      if (top.isNotEmpty) top[0],
      if (top.length > 2) top[2],
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [for (final f in orden) Expanded(child: _Puesto(f))],
    );
  }
}

class _Puesto extends StatelessWidget {
  const _Puesto(this.fila);

  final FilaClasificatoria fila;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = switch (fila.posicion) {
      1 => c.medalla,
      2 => c.textoSecundario,
      _ => c.intensidadDura,
    };
    final alto = switch (fila.posicion) {
      1 => 92.0,
      2 => 68.0,
      _ => 52.0,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          _Avatar(
            fila.nombre,
            tam: fila.posicion == 1 ? 56 : 46,
            destacado: fila.esTu,
          ),
          const SizedBox(height: 6),
          Text(
            fila.esTu ? '${fila.nombre} (tú)' : fila.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textoPrincipal,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _km(fila.km),
              style: TextStyle(color: c.textoSecundario, fontSize: 13),
            ),
          ),
          Text(
            '+${fila.puntos} pts',
            style: TextStyle(color: c.textoTenue, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Container(
            height: alto,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              border: Border.all(color: color, width: 1.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Center(
              child: Text(
                '${fila.posicion}',
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.fila, {this.destacada = false});

  final FilaClasificatoria fila;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final resaltada = destacada || fila.esTu;
    return Padding(
      padding: EdgeInsets.only(bottom: destacada ? 0 : 8),
      child: Material(
        color: resaltada ? c.primarioSuave : c.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: resaltada ? c.primario : c.borde,
            width: resaltada ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${fila.posicion}',
                  style: TextStyle(
                    color: c.textoSecundario,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _Avatar(fila.nombre, tam: 36, destacado: resaltada),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fila.esTu ? '${fila.nombre} (tú)' : fila.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textoPrincipal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _km(fila.km),
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '+${fila.puntos} pts',
                    style: TextStyle(color: c.textoTenue, fontSize: 12),
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
