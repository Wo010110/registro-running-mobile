import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/providers/historial_provider.dart';
import 'package:heyrun_mobile/providers/perfil_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'al abrir el Perfil se calculan los récords de las actividades viejas',
    () async {
      final db = await CarrerasDb.abrir(ruta: inMemoryDatabasePath);
      addTearDown(db.cerrar);
      // Una actividad anterior a los récords: terminada, con puntos y sin
      // tramos calculados.
      final c = await db.crearCarrera(
        TipoActividad.correr,
        inicio: DateTime.utc(2026, 1, 1, 8),
      );
      for (var s = 0; s <= 400; s += 10) {
        await db.insertarPunto(
          c.id,
          PuntoGps(
            lat: 4 + 3.0 * s / 111194.93,
            lng: -74,
            precisionM: 2,
            instante: DateTime.utc(2026, 1, 1, 8).add(Duration(seconds: s)),
          ),
        );
      }
      await db.terminar(c.id, distanciaM: 1200, tiempoMovimientoS: 400);
      expect(await db.carrerasSinTramos(), hasLength(1));

      final contenedor = ProviderContainer(
        overrides: [
          carrerasDbProvider.overrideWithValue(db),
          historialProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(contenedor.dispose);
      final records = await contenedor.read(recordsProvider.future);
      expect(records[1000]!.tiempoS, closeTo(1000 / 3, 0.1));
      expect(records[1000]!.carreraId, c.id);
      expect(records.containsKey(5000), isFalse);
      // Ya quedó calculada: no se repite.
      expect(await db.carrerasSinTramos(), isEmpty);
    },
  );
}
