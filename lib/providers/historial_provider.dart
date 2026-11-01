import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/carrera_calculos.dart';
import '../core/carreras_db.dart';
import '../core/historial.dart';
import '../models/tipo_actividad.dart';
import 'grabacion_provider.dart';

/// Actividades cerradas, de la más reciente a la más antigua. Se vuelve a leer
/// cuando cambia la fase de la grabación: al terminar ya están en disco.
final historialProvider = FutureProvider<List<CarreraLocal>>((ref) {
  ref.watch(grabacionProvider.select((g) => g.fase));
  return ref.read(carrerasDbProvider).terminadas();
});

/// Dibujo de la ruta de una actividad; se calcula una vez por actividad.
final trazoProvider = FutureProvider.family<List<(double, double)>, String>((
  ref,
  carreraId,
) async {
  final puntos = await ref.read(carrerasDbProvider).puntos(carreraId);
  return trazoNormalizado(puntos);
});

/// Recorrido (en trozos) y parciales de una actividad guardada, para
/// mostrarla al editarla.
final recorridoProvider =
    FutureProvider.family<
      ({List<List<PuntoGps>> ruta, List<int> parciales}),
      String
    >((ref, carreraId) async {
      final db = ref.read(carrerasDbProvider);
      final carrera = await db.carrera(carreraId);
      final puntos = await db.puntos(carreraId);
      final pausas = await db.pausas(carreraId);
      return (
        ruta: rutaVisual(puntos, carrera?.tipo ?? TipoActividad.correr, pausas),
        parciales: calcularCarrera(puntos, pausas).parcialesS,
      );
    });
