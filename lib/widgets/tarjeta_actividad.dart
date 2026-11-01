import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/carreras_db.dart';
import '../core/formato.dart';
import '../core/historial.dart';
import '../models/tipo_actividad.dart';
import '../providers/grabacion_provider.dart';
import '../providers/historial_provider.dart';
import '../theme/app_colors.dart';
import 'dialogo_hey.dart';
import 'tarjeta.dart';
import 'trazo_ruta.dart';

/// Resumen de una actividad guardada: título, fecha, ruta y cifras.
class TarjetaActividad extends ConsumerWidget {
  const TarjetaActividad({super.key, required this.carrera, this.alto = 120});

  final CarreraLocal carrera;
  final double alto;

  /// Pide confirmación y borra la actividad con su recorrido y sus pausas.
  Future<void> _eliminar(BuildContext context) async {
    // El contenedor sobrevive a la tarjeta, que desaparece al borrar.
    final contenedor = ProviderScope.containerOf(context);
    final confirmado = await confirmarHey(
      context,
      titulo: '¿Eliminar esta actividad?',
      mensaje: 'Se borrará con su recorrido y no se puede deshacer.',
      confirmar: 'Eliminar',
      cancelar: 'Cancelar',
      destructivo: true,
    );
    if (!confirmado) return;
    await contenedor.read(carrerasDbProvider).descartar(carrera.id);
    contenedor.invalidate(historialProvider);
    contenedor.invalidate(trazoProvider(carrera.id));
  }

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
                    if (carrera.modo != null)
                      Text(
                        carrera.modo!.etiqueta!,
                        style: TextStyle(
                          color: c.primario,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (carrera.estado == EstadoCarrera.terminada)
                PopupMenuButton<void>(
                  tooltip: 'Más opciones',
                  color: c.superficie,
                  padding: EdgeInsets.zero,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreHorizontal,
                    color: c.textoTenue,
                    size: 22,
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem<void>(
                      onTap: () => _eliminar(context),
                      child: Text(
                        'Eliminar actividad',
                        style: TextStyle(color: c.errorTexto),
                      ),
                    ),
                  ],
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
              _Dato(
                'Ritmo',
                formatearRitmo(ritmoMedioSKm(carrera)),
                unidad: '/km',
              ),
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
  const _Dato(this.etiqueta, this.valor, {this.unidad});

  final String etiqueta;
  final String valor;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: TextStyle(color: c.textoTenue, fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    color: c.textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    if (unidad != null)
                      TextSpan(
                        text: ' $unidad',
                        style: TextStyle(
                          color: c.textoTenue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
