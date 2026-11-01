import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/carreras_db.dart';
import '../../core/formato.dart';
import '../../core/historial.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grabacion_provider.dart';
import '../../providers/historial_provider.dart';
import '../../providers/navegacion_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/tarjeta.dart';
import '../../widgets/tarjeta_actividad.dart';
import '../actividad_screen.dart';

class InicioTab extends ConsumerWidget {
  const InicioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final nombre = ref.watch(authProvider.select((a) => a.user?.displayName));
    final enCurso = ref.watch(grabacionProvider.select((g) => g.enCurso));
    final historial = ref.watch(historialProvider).value ?? <CarreraLocal>[];
    final ultima = historial.isEmpty ? null : historial.first;
    final semana = kmPorDiaSemana(historial, DateTime.now());
    final totalSemana = semana.fold(0.0, (a, b) => a + b);
    final maximo = semana.reduce((a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Hola, ${nombre ?? ''}',
          style: TextStyle(
            color: c.textoPrincipal,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Listo para salir a correr',
          style: TextStyle(color: c.textoSecundario, fontSize: 15),
        ),
        const SizedBox(height: 20),
        if (enCurso) ...[
          Tarjeta(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ActividadScreen()),
            ),
            child: Row(
              children: [
                const IconoCirculo(icono: HugeIcons.strokeRoundedTimer01),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Tienes una actividad en curso',
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: c.textoTenue,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Tarjeta(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta semana',
                style: TextStyle(color: c.textoTenue, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatearKmUno(totalSemana),
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'km',
                      style: TextStyle(color: c.textoSecundario, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < semana.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 14,
                              height: semana[i] == 0
                                  ? 6
                                  : 8 + 56 * semana[i] / maximo,
                              decoration: BoxDecoration(
                                color: semana[i] == 0 ? c.divisor : c.primario,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              diasSemana[i],
                              style: TextStyle(
                                color: c.textoTenue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        TituloSeccion(
          'Última actividad',
          accion: 'Ver todas',
          alTocar: () {
            ref.read(pestanaProvider.notifier).ir(3);
            ref.read(solicitudHistorialProvider.notifier).pedir();
          },
        ),
        if (ultima == null)
          const SinActividades()
        else
          TarjetaActividad(carrera: ultima),
        const TituloSeccion('Tu meta del mes'),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '50 km en noviembre',
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '42 %',
                    style: TextStyle(
                      color: c.primario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: .42,
                  minHeight: 10,
                  color: c.primario,
                  backgroundColor: c.primarioSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
