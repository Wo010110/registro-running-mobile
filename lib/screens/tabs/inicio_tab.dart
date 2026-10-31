import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/datos_ejemplo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grabacion_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/tarjeta.dart';
import '../../widgets/trazo_ruta.dart';
import '../actividad_screen.dart';

class InicioTab extends ConsumerWidget {
  const InicioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final nombre = ref.watch(authProvider.select((a) => a.user?.displayName));
    final enCurso = ref.watch(grabacionProvider.select((g) => g.enCurso));
    final ultima = actividadesEjemplo.first;
    final maximo = semanaEjemplo.reduce((a, b) => a > b ? a : b);
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
                    '23,7',
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
                    for (var i = 0; i < semanaEjemplo.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 14,
                              height: semanaEjemplo[i] == 0
                                  ? 6
                                  : 8 + 56 * semanaEjemplo[i] / maximo,
                              decoration: BoxDecoration(
                                color: semanaEjemplo[i] == 0
                                    ? c.divisor
                                    : c.primario,
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
        const TituloSeccion('Última actividad', accion: 'Ver todas'),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconoCirculo(
                    icono: HugeIcons.strokeRoundedRunningShoes,
                    tam: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ultima.titulo,
                          style: TextStyle(
                            color: c.textoPrincipal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ultima.fecha,
                          style: TextStyle(color: c.textoTenue, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TrazoRuta(puntos: ultima.trazo),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Dato('Distancia', '${ultima.km} km'),
                  _Dato('Tiempo', ultima.tiempo),
                  _Dato('Ritmo', '${ultima.ritmo} /km'),
                ],
              ),
            ],
          ),
        ),
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

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(color: c.textoTenue, fontSize: 12)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
