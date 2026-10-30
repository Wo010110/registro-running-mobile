import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/formato.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/dato_actividad.dart';
import '../widgets/mapa_recorrido.dart';
import 'resumen_screen.dart';

class GrabandoScreen extends ConsumerWidget {
  const GrabandoScreen({super.key});

  /// Atrás no detiene la grabación: solo ofrece seguir en segundo plano.
  Future<void> _salir(BuildContext context) async {
    final seguir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('La actividad sigue grabando'),
        content: const Text(
          'Puedes seguir en segundo plano y volver desde el inicio con '
          '"Actividad en curso".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quedarme aquí'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Seguir en segundo plano'),
          ),
        ],
      ),
    );
    if ((seguir ?? false) && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _terminar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Terminar la actividad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (!(confirmado ?? false) || !context.mounted) return;
    await _cerrar(context, ref);
  }

  /// También reintenta cuando terminar falló al guardar.
  Future<void> _cerrar(BuildContext context, WidgetRef ref) async {
    await ref.read(grabacionProvider.notifier).terminar();
    if (!context.mounted) return;
    if (ref.read(grabacionProvider).fase != FaseGrabacion.terminada) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ResumenScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final g = ref.watch(grabacionProvider);
    final notifier = ref.read(grabacionProvider.notifier);
    final pausada = g.fase == FaseGrabacion.pausada;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _salir(context);
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                children: [
                  MapaRecorrido(
                    ruta: g.ruta,
                    posicion: g.posicion,
                    enVivo: true,
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton.filled(
                        tooltip: 'Seguir en segundo plano',
                        style: IconButton.styleFrom(
                          backgroundColor: c.superficie,
                        ),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          color: c.textoPrincipal,
                        ),
                        onPressed: () => _salir(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 9,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    children: [
                      FittedBox(
                        child: Text(
                          formatearTiempo(g.tiempoTotalS),
                          style: TextStyle(
                            color: pausada ? c.textoTenue : c.textoPrincipal,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (pausada)
                        Text('En pausa', style: TextStyle(color: c.textoTenue)),
                      if (g.sinSenal)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
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
                                  fontSize: 13,
                                ),
                              ),
                            ],
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
                          onPressed: g.ocupado
                              ? null
                              : () => _cerrar(context, ref),
                          child: const Text('Reintentar'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          DatoActividad(
                            'Distancia',
                            '${formatearKm(g.distanciaM)} km',
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: g.ocupado || g.falloCierre
                                  ? null
                                  : pausada
                                  ? notifier.reanudar
                                  : notifier.pausar,
                              icon: HugeIcon(
                                icon: pausada
                                    ? HugeIcons.strokeRoundedPlay
                                    : HugeIcons.strokeRoundedPause,
                                color: c.sobreAccion,
                                size: 20,
                              ),
                              label: Text(pausada ? 'Reanudar' : 'Pausa'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: g.ocupado
                                  ? null
                                  : () => _terminar(context, ref),
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedStop,
                                color: c.textoPrincipal,
                                size: 20,
                              ),
                              label: const Text('Terminar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
