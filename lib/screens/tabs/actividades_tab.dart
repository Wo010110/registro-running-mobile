import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/datos_ejemplo.dart';
import '../../models/tipo_actividad.dart';
import '../../theme/app_colors.dart';
import '../../widgets/tarjeta.dart';
import '../../widgets/trazo_ruta.dart';

class ActividadesTab extends StatelessWidget {
  const ActividadesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Actividades',
          style: TextStyle(
            color: c.textoPrincipal,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            _Ficha('Todas', activa: true),
            SizedBox(width: 8),
            _Ficha('Correr'),
            SizedBox(width: 8),
            _Ficha('Caminar'),
          ],
        ),
        const SizedBox(height: 16),
        for (final a in actividadesEjemplo) ...[
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconoCirculo(
                      icono: a.tipo == TipoActividad.correr
                          ? HugeIcons.strokeRoundedRunningShoes
                          : HugeIcons.strokeRoundedRoute01,
                      tam: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.titulo,
                            style: TextStyle(
                              color: c.textoPrincipal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${a.tipo.etiqueta} · ${a.fecha}',
                            style: TextStyle(color: c.textoTenue, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TrazoRuta(puntos: a.trazo, alto: 96),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Dato('Distancia', '${a.km} km'),
                    _Dato('Tiempo', a.tiempo),
                    _Dato('Ritmo', '${a.ritmo} /km'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha(this.texto, {this.activa = false});

  final String texto;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: activa ? c.accion : c.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activa ? c.accion : c.borde),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: activa ? c.sobreAccion : c.textoSecundario,
          fontWeight: FontWeight.w600,
        ),
      ),
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
