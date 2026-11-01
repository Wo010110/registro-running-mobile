import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/providers/historial_provider.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';
import 'package:heyrun_mobile/theme/app_theme.dart';
import 'package:heyrun_mobile/widgets/tarjeta_actividad.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    initializeDateFormatting('es');
  });

  late CarrerasDb db;
  late String idA;
  late String idB;

  Future<String> terminada(int dia) async {
    final c = await db.crearCarrera(
      TipoActividad.correr,
      inicio: DateTime.utc(2026, 1, dia, 8),
    );
    for (var s = 0; s < 3; s++) {
      await db.insertarPunto(
        c.id,
        PuntoGps(
          lat: 4 + s / 10000,
          lng: -74,
          precisionM: 5,
          instante: DateTime.utc(2026, 1, dia, 8, 0, s),
        ),
      );
    }
    await db.pausar(c.id, ahora: DateTime.utc(2026, 1, dia, 8, 0, 1));
    await db.terminar(
      c.id,
      distanciaM: 40,
      tiempoMovimientoS: 2,
      fin: DateTime.utc(2026, 1, dia, 8, 1),
    );
    return c.id;
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.runAsync(() async {
      db = await CarrerasDb.abrir(ruta: inMemoryDatabasePath);
      idA = await terminada(1);
      idB = await terminada(2);
    });
    addTearDown(() => tester.runAsync(db.cerrar));
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [carrerasDbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: construirTema(AppColors.claro, Brightness.light),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ListView(
                children: [
                  for (final c in ref.watch(historialProvider).value ?? [])
                    TarjetaActividad(carrera: c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  // La base trabaja en otro hilo: se deja pasar tiempo real entre fotogramas.
  Future<void> esperarDb(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> pedirEliminar(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Más opciones').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar actividad'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar esta actividad?'), findsOneWidget);
    expect(
      find.text('Se borrará con su recorrido y no se puede deshacer.'),
      findsOneWidget,
    );
  }

  testWidgets('cancelar no borra nada', (tester) async {
    await abrir(tester);
    expect(find.byTooltip('Más opciones'), findsNWidgets(2));
    await pedirEliminar(tester);
    await tester.tap(find.text('Cancelar'));
    await esperarDb(tester);
    expect(find.byTooltip('Más opciones'), findsNWidgets(2));
    final quedan = await tester.runAsync(() => db.terminadas());
    expect(quedan!.length, 2);
  });

  testWidgets('eliminar quita la actividad, sus puntos y sus pausas', (
    tester,
  ) async {
    await abrir(tester);
    // La primera tarjeta es la más reciente (día 2).
    await pedirEliminar(tester);
    await tester.tap(find.text('Eliminar'));
    await esperarDb(tester);

    expect(find.byTooltip('Más opciones'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await db.carrera(idB), isNull);
      expect(await db.puntos(idB), isEmpty);
      expect(await db.pausas(idB), isEmpty);
      expect(await db.carrera(idA), isNotNull);
      expect((await db.puntos(idA)).length, 3);
      expect((await db.pausas(idA)).length, 1);
    });
  });
}
