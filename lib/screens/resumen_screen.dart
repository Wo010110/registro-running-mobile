import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/formato.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/dato_actividad.dart';
import '../widgets/mapa_recorrido.dart';

class ResumenScreen extends ConsumerWidget {
  const ResumenScreen({super.key});

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    await ref.read(grabacionProvider.notifier).cerrar();
    if (context.mounted) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  Future<void> _descartar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Descartar la actividad?'),
        content: const Text('Se borrará del teléfono y no se podrá recuperar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (!(confirmado ?? false) || !context.mounted) return;
    await ref.read(grabacionProvider.notifier).descartar();
    if (context.mounted) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final g = ref.watch(grabacionProvider);
    final r = g.resumen;
    final inicio = g.inicioUtc;
    if (r == null || inicio == null) return const Scaffold();
    final fecha = DateFormat(
      "d 'de' MMMM y, HH:mm",
      'es',
    ).format(inicio.toLocal());
    return PopScope(
      onPopInvokedWithResult: (salio, _) {
        if (salio) ref.read(grabacionProvider.notifier).cerrar();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Resumen')),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: MapaRecorrido(ruta: g.ruta, posicion: g.posicion),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '${g.tipo.etiqueta} · $fecha',
                    style: TextStyle(color: c.textoSecundario),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${formatearKm(r.distanciaM)} km',
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DatoActividad('Tiempo', formatearTiempo(g.tiempoTotalS)),
                      if ((g.tiempoTotalS - r.tiempoMovimientoS).abs() > 5)
                        DatoActividad(
                          'En movimiento',
                          formatearTiempo(r.tiempoMovimientoS),
                        ),
                      DatoActividad(
                        'Ritmo medio',
                        '${formatearRitmo(r.ritmoMedioSKm)} /km',
                      ),
                    ],
                  ),
                  if (r.parcialesS.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Parciales',
                      style: TextStyle(
                        color: c.textoPrincipal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (var i = 0; i < r.parcialesS.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Km ${i + 1}',
                              style: TextStyle(color: c.textoSecundario),
                            ),
                            Text(
                              '${formatearRitmo(r.parcialesS[i].toDouble())} /km',
                              style: TextStyle(color: c.textoPrincipal),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: g.ocupado ? null : () => _guardar(context, ref),
                    child: const Text('Guardar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: g.ocupado
                        ? null
                        : () => _descartar(context, ref),
                    child: Text(
                      'Descartar',
                      style: TextStyle(color: c.errorTexto),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
