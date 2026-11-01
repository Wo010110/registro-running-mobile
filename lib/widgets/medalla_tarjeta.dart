import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/datos_ejemplo.dart';
import '../theme/app_colors.dart';
import 'tarjeta.dart';

class MedallaTarjeta extends StatelessWidget {
  const MedallaTarjeta(this.medalla, {super.key});

  final MedallaEjemplo medalla;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = medalla.ganada ? c.medalla : c.textoDeshabilitado;
    return Tarjeta(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .16),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMedal01,
                color: color,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            medalla.nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: medalla.ganada ? c.textoPrincipal : c.textoTenue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Medallas de tres en tres; cada fila crece con el texto (a diferencia de una
/// cuadrícula de proporción fija).
class CuadriculaMedallas extends StatelessWidget {
  const CuadriculaMedallas(this.medallas, {super.key});

  final List<MedallaEjemplo> medallas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final ancho = (caja.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final m in medallas)
              SizedBox(width: ancho, child: MedallaTarjeta(m)),
          ],
        );
      },
    );
  }
}
