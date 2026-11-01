import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/carreras_db.dart';
import '../core/records.dart';
import 'grabacion_provider.dart';
import 'historial_provider.dart';
import 'theme_provider.dart';

const _kCiudad = 'perfil_ciudad';
const _kPresentacion = 'perfil_presentacion';

/// Ciudad y presentación del perfil, guardadas solo en el teléfono.
class PerfilLocal {
  const PerfilLocal({this.ciudad = '', this.presentacion = ''});

  final String ciudad;
  final String presentacion;
}

class PerfilLocalNotifier extends Notifier<PerfilLocal> {
  @override
  PerfilLocal build() {
    final prefs = ref.read(prefsProvider);
    return PerfilLocal(
      ciudad: prefs.getString(_kCiudad) ?? '',
      presentacion: prefs.getString(_kPresentacion) ?? '',
    );
  }

  Future<void> guardar({
    required String ciudad,
    required String presentacion,
  }) async {
    final nuevo = PerfilLocal(
      ciudad: ciudad.trim(),
      presentacion: presentacion.trim(),
    );
    state = nuevo;
    final prefs = ref.read(prefsProvider);
    await prefs.setString(_kCiudad, nuevo.ciudad);
    await prefs.setString(_kPresentacion, nuevo.presentacion);
  }
}

final perfilLocalProvider = NotifierProvider<PerfilLocalNotifier, PerfilLocal>(
  PerfilLocalNotifier.new,
);

class CifrasPerfil {
  const CifrasPerfil({
    this.actividades = 0,
    this.distanciaM = 0,
    this.tiempoS = 0,
  });

  final int actividades;
  final double distanciaM;
  final int tiempoS;
}

/// Totales de las actividades terminadas de la app (de la base local).
final cifrasPerfilProvider = Provider<CifrasPerfil>((ref) {
  final todas = ref.watch(historialProvider).value ?? const <CarreraLocal>[];
  return CifrasPerfil(
    actividades: todas.length,
    distanciaM: todas.fold(0.0, (a, c) => a + c.distanciaM),
    tiempoS: todas.fold(0, (a, c) => a + c.tiempoMovimientoS),
  );
});

/// Mejores tiempos por distancia. Antes de leerlos calcula, una por una y
/// cediendo el hilo entre actividades, las que aún no tienen sus tramos
/// (grabadas antes de existir los récords).
final recordsProvider = FutureProvider<Map<double, RecordPersonal>>((
  ref,
) async {
  // Espera al historial: así un cambio en él (nueva actividad, edición) vuelve
  // a calcular, pero no a mitad de una ejecución.
  await ref.watch(historialProvider.future);
  final db = ref.read(carrerasDbProvider);
  for (final c in await db.carrerasSinTramos()) {
    final puntos = await db.puntos(c.id);
    final pausas = await db.pausas(c.id);
    await db.guardarTramos(c.id, mejoresTramos(puntos, pausas));
    await Future<void>.delayed(Duration.zero);
  }
  return db.mejoresRecords();
});
