import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/carreras_db.dart';
import '../core/formato.dart';
import '../core/historial.dart';
import '../models/tipo_actividad.dart';
import '../providers/historial_provider.dart';
import '../theme/app_colors.dart';
import 'tarjeta.dart';
import 'trazo_ruta.dart';

/// Resumen de una actividad guardada: título, fecha, ruta y cifras.
class TarjetaActividad extends ConsumerWidget {
  const TarjetaActividad({super.key, required this.carrera, this.alto = 120});

  final CarreraLocal carrera;
  final double alto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final trazo = ref.watch(trazoProvider(carrera.id)).value ?? const [];
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoCirculo(
                icono: carrera.tipo == TipoActividad.correr
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
                      tituloActividad(carrera.tipo, carrera.inicioUtc),
                      style: TextStyle(
                        color: c.textoPrincipal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatearFechaActividad(
                        carrera.inicioUtc,
                        DateTime.now(),
                      ),
                      style: TextStyle(color: c.textoTenue, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TrazoRuta(puntos: trazo, alto: alto),
          const SizedBox(height: 14),
          Row(
            children: [
              _Dato('Distancia', '${formatearKm(carrera.distanciaM)} km'),
              _Dato('Tiempo', formatearTiempo(carrera.tiempoMovimientoS)),
              _Dato('Ritmo', '${formatearRitmo(ritmoMedioSKm(carrera))} /km'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aviso cuando todavía no hay actividades que mostrar.
class SinActividades extends StatelessWidget {
  const SinActividades({super.key, this.texto});

  final String? texto;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tarjeta(
      child: Row(
        children: [
          const IconoCirculo(icono: HugeIcons.strokeRoundedRunningShoes),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto ??
                  'Aún no tienes actividades. Toca el botón redondo para '
                      'grabar la primera.',
              style: TextStyle(color: c.textoSecundario, height: 1.3),
            ),
          ),
        ],
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
