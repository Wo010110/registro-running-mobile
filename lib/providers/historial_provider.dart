import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/carreras_db.dart';
import '../core/historial.dart';
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
