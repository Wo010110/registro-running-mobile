import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../core/formato.dart';
import '../models/modo_actividad.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/actividad_paneles.dart';
import '../widgets/dato_actividad.dart';
import '../widgets/dialogo_hey.dart';
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
    final confirmado = await confirmarHey(
      context,
      titulo: '¿Descartar la actividad?',
      mensaje: 'Se borrará del teléfono y no se podrá recuperar.',
      confirmar: 'Descartar',
      cancelar: 'Cancelar',
      destructivo: true,
    );
    if (!confirmado || !context.mounted) return;
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
    final arriba = MediaQuery.paddingOf(context).top;
    final alto = MediaQuery.sizeOf(context).height;
    return PopScope(
      onPopInvokedWithResult: (salio, _) {
        if (salio) ref.read(grabacionProvider.notifier).cerrar();
      },
      child: Scaffold(
        body: Column(
          children: [
            // Mapa con el recorrido, con las esquinas de abajo redondeadas.
            SizedBox(
              height: alto * .5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MapaRecorrido(ruta: g.ruta, posicion: g.posicion),
                    Positioned(
                      left: 12,
                      top: arriba + 12,
                      child: Material(
                        color: c.superficie,
                        elevation: 8,
                        shadowColor: c.sombra,
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
                    ),
                    Positioned(
                      right: 20,
                      top: arriba + 24,
                      child: Text(
                        'RESUMEN',
                        style: TextStyle(
                          color: c.textoPrincipal,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: c.sombra,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: EntradaPop(
                          retardo: const Duration(milliseconds: 150),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.superficie,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: c.borde),
                              boxShadow: [
                                BoxShadow(
                                  color: c.sombra,
                                  blurRadius: 22,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                18,
                              ),
                              children: [
                                Text(
                                  '${g.tipo.etiqueta} · $fecha',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: c.textoSecundario,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${formatearKm(r.distanciaM)} km',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: c.textoPrincipal,
                                    fontSize: 60,
                                    height: 1.05,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    DatoActividad(
                                      'Tiempo',
                                      formatearTiempo(g.tiempoTotalS),
                                    ),
                                    if ((g.tiempoTotalS - r.tiempoMovimientoS)
                                            .abs() >
                                        5)
                                      DatoActividad(
                                        'En movimiento',
                                        formatearTiempo(r.tiempoMovimientoS),
                                      ),
                                    DatoActividad(
                                      // Los descansos son pausas: el ritmo es
                                      // solo el de los tramos de carrera.
                                      g.modo is ModoIntervalos
                                          ? 'Ritmo tramos'
                                          : 'Ritmo medio',
                                      formatearRitmo(r.ritmoMedioSKm),
                                      unidad: '/km',
                                    ),
                                  ],
                                ),
                                if (r.parcialesS.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    'PARCIALES',
                                    style: TextStyle(
                                      color: c.textoPrincipal,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  for (var i = 0; i < r.parcialesS.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Km ${i + 1}',
                                            style: TextStyle(
                                              color: c.textoSecundario,
                                              fontSize: 17,
                                            ),
                                          ),
                                          Text(
                                            '${formatearRitmo(r.parcialesS[i].toDouble())} /km',
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
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: EntradaPop(
                              retardo: const Duration(milliseconds: 350),
                              child: BotonFlotante(
                                principal: true,
                                texto: 'GUARDAR',
                                icono: HugeIcons.strokeRoundedCheckmarkCircle02,
                                onTap: g.ocupado
                                    ? null
                                    : () => _guardar(context, ref),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EntradaPop(
                              retardo: const Duration(milliseconds: 500),
                              child: BotonFlotante(
                                destructivo: true,
                                texto: 'DESCARTAR',
                                icono: HugeIcons.strokeRoundedDelete02,
                                onTap: g.ocupado
                                    ? null
                                    : () => _descartar(context, ref),
                              ),
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
