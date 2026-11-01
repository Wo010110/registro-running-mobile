import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/datos_ejemplo.dart';
import '../../theme/app_colors.dart';
import '../../widgets/medalla_tarjeta.dart';
import '../../widgets/tarjeta.dart';

class RetosTab extends StatelessWidget {
  const RetosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Retos',
          style: TextStyle(
            color: c.textoPrincipal,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Metas, rutas de la comunidad y medallas',
          style: TextStyle(color: c.textoSecundario, fontSize: 15),
        ),
        const TituloSeccion('En curso'),
        for (final r in retosEjemplo) ...[
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconoCirculo(
                      icono: HugeIcons.strokeRoundedTarget01,
                      tam: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.titulo,
                            style: TextStyle(
                              color: c.textoPrincipal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            r.detalle,
                            style: TextStyle(color: c.textoTenue, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: r.progreso,
                    minHeight: 8,
                    color: c.primario,
                    backgroundColor: c.primarioSuave,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.meta,
                  style: TextStyle(color: c.textoSecundario, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const TituloSeccion('Medallas'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .85,
          children: [for (final m in medallasEjemplo) MedallaTarjeta(m)],
        ),
      ],
    );
  }
}
