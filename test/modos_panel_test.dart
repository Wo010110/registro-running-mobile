import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/historial_provider.dart';
import 'package:heyrun_mobile/providers/modo_provider.dart';
import 'package:heyrun_mobile/providers/theme_provider.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';
import 'package:heyrun_mobile/theme/app_theme.dart';
import 'package:heyrun_mobile/widgets/modos_panel.dart';
import 'package:heyrun_mobile/widgets/tarjeta_actividad.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer c;

  Future<void> abrir(
    WidgetTester tester, {
    bool habilitado = true,
    Brightness brillo = Brightness.light,
    double alto = 1400,
  }) async {
    tester.view.physicalSize = Size(360, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: construirTema(
            brillo == Brightness.dark ? AppColors.oscuro : AppColors.claro,
            brillo,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ModosPanel(habilitado: habilitado),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('elegir un modo muestra su configuración y la recuerda', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('MODOS'), findsOneWidget);
    expect(find.text('Sin objetivo'), findsOneWidget);
    expect(find.text('EDITAR ›'), findsNothing);

    await tester.tap(find.text('INTERVALOS'));
    await tester.pump();
    expect(find.text('8 × 400 m · descanso 90 s'), findsOneWidget);
    expect(find.text('EDITAR ›'), findsOneWidget);
    expect(c.read(seleccionModoProvider).tipo, TipoModo.intervalos);

    await tester.tap(find.text('META'));
    await tester.pump();
    expect(find.textContaining('5 km'), findsOneWidget);
  });

  testWidgets('deshabilitado no deja cambiar de modo', (tester) async {
    await abrir(tester, habilitado: false);
    await tester.tap(find.text('META'));
    await tester.pump();
    expect(c.read(seleccionModoProvider).tipo, TipoModo.libre);
  });

  /// Gira la rueda [indice] (0 = la primera) [pasos] elementos hacia arriba.
  Future<void> girar(WidgetTester tester, int indice, int pasos) async {
    await tester.drag(
      find.byType(CupertinoPicker).at(indice),
      Offset(0, -38.0 * pasos),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirHoja(WidgetTester tester, String modo) async {
    await tester.tap(find.text(modo));
    await tester.pump();
    await tester.tap(find.text('EDITAR ›'));
    await tester.pumpAndSettle();
  }

  testWidgets('la hoja de intervalos: filas con el valor en formato corto', (
    tester,
  ) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    expect(find.text('Correr'), findsOneWidget);
    expect(find.text('400 m'), findsOneWidget);
    expect(find.text('Descanso'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('Repeticiones'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Al terminar'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    // Nada desplegado, sin atajos ni píldoras de unidades.
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.text('1 KM'), findsNothing);
    expect(find.text('SIN LÍMITE'), findsNothing);
  });

  testWidgets('acordeón: una sola fila abierta a la vez', (tester) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.text('DISTANCIA'), findsOneWidget);
    expect(find.text('TIEMPO'), findsOneWidget);

    await tester.tap(find.text('Repeticiones'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsOneWidget); // la de repeticiones
    expect(find.text('DISTANCIA'), findsNothing);

    await tester.tap(find.text('Repeticiones'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNothing);
  });

  testWidgets('girar la rueda de distancia cambia el tramo', (tester) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    await girar(tester, 0, 1); // km: 0 -> 1
    expect(c.read(seleccionModoProvider).intervalos.tramo, 1400);
    await girar(tester, 1, 2); // m: 400 -> 500
    expect(c.read(seleccionModoProvider).intervalos.tramo, 1500);
    expect(find.text('1,5 km'), findsOneWidget);
  });

  testWidgets('el mínimo no permite 0 y vuelve a 50 m', (tester) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    await girar(tester, 1, -8); // los metros a 0 con 0 km
    expect(c.read(seleccionModoProvider).intervalos.tramo, 50);
    expect(find.text('50 m'), findsOneWidget);
  });

  testWidgets('tiempo de tramo: mínimo de 5 s y pasos de 5 s', (tester) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TIEMPO'));
    await tester.pumpAndSettle();
    expect(c.read(seleccionModoProvider).intervalos.tramoMedida, Medida.tiempo);
    expect(c.read(seleccionModoProvider).intervalos.tramo, 120);
    await girar(tester, 1, 1); // s: 0 -> 5
    expect(c.read(seleccionModoProvider).intervalos.tramo, 125);
    await girar(tester, 0, -2); // min: 2 -> 0
    await girar(tester, 1, -1); // s: 5 -> 0: no puede ser 0
    expect(c.read(seleccionModoProvider).intervalos.tramo, 5);
  });

  testWidgets('el descanso ofrece primero Tiempo y redondea al paso', (
    tester,
  ) async {
    await abrir(tester);
    // Un 333 m / 47 s guardados antes no caen en un paso de la rueda.
    await c
        .read(seleccionModoProvider.notifier)
        .guardarIntervalos(
          const ModoIntervalos(
            tramo: 333,
            descansoMedida: Medida.tiempo,
            descanso: 47,
          ),
        );
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Descanso'));
    await tester.pumpAndSettle();
    final tiempo = tester.getRect(find.text('TIEMPO'));
    final distancia = tester.getRect(find.text('DISTANCIA'));
    expect(tiempo.left, lessThan(distancia.left));
    // Gira a otro valor y comprueba que partió de 45 s.
    await girar(tester, 1, 1);
    expect(c.read(seleccionModoProvider).intervalos.descanso, 50);
  });

  testWidgets('∞ pone las repeticiones sin límite', (tester) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Repeticiones'));
    await tester.pumpAndSettle();
    await girar(tester, 0, 1); // 8 -> 9
    expect(c.read(seleccionModoProvider).intervalos.repeticiones, 9);
    await girar(tester, 0, 50); // hasta el final de la rueda
    expect(c.read(seleccionModoProvider).intervalos.repeticiones, isNull);
    expect(find.text('∞'), findsWidgets);
    await girar(tester, 0, -1);
    expect(c.read(seleccionModoProvider).intervalos.repeticiones, 50);
  });

  testWidgets('al terminar: un solo selector con las tres opciones', (
    tester,
  ) async {
    await abrir(tester);
    await abrirHoja(tester, 'INTERVALOS');
    await tester.tap(find.text('Al terminar'));
    await tester.pumpAndSettle();
    expect(find.text('PAUSAR'), findsOneWidget);
    expect(find.text('SEGUIR LIBRE'), findsOneWidget);
    await tester.tap(find.text('SEGUIR LIBRE'));
    await tester.pump();
    expect(
      c.read(seleccionModoProvider).intervalos.alTerminar,
      AlTerminarIntervalos.libre,
    );
    await tester.tap(find.text('LISTO'));
    await tester.pumpAndSettle();
    expect(find.text('LISTO'), findsNothing);
  });

  testWidgets('meta: distancia y tiempo con h y min, mínimo 1 min', (
    tester,
  ) async {
    await abrir(tester);
    await abrirHoja(tester, 'META');
    expect(find.text('Objetivo'), findsOneWidget);
    expect(find.text('5 km'), findsWidgets);
    await tester.tap(find.text('Objetivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TIEMPO'));
    await tester.pumpAndSettle();
    expect(c.read(seleccionModoProvider).meta.medida, Medida.tiempo);
    expect(c.read(seleccionModoProvider).meta.valor, 1800);
    expect(find.text('30 min'), findsOneWidget);
    expect(
      find.text('El tiempo cuenta solo en movimiento, sin las pausas.'),
      findsOneWidget,
    );
    await girar(tester, 0, 1); // 1 h
    expect(find.text('1 h 30 min'), findsOneWidget);
    await girar(tester, 0, -1);
    await girar(tester, 1, -30); // minutos a 0 con 0 h
    expect(c.read(seleccionModoProvider).meta.valor, 60);

    await tester.tap(find.text('Al llegar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAUSAR'));
    await tester.pump();
    expect(c.read(seleccionModoProvider).meta.alLlegar, AlLlegarMeta.pausar);
  });

  testWidgets('meta por tiempo: minutos de 0 a 59 y tope de 24 h', (
    tester,
  ) async {
    await abrir(tester);
    await c
        .read(seleccionModoProvider.notifier)
        .guardarMeta(const ModoMeta(medida: Medida.tiempo, valor: 35940));
    await abrirHoja(tester, 'META');
    expect(find.text('9 h 59 min'), findsOneWidget);
    await tester.tap(find.text('Objetivo'));
    await tester.pumpAndSettle();

    List<String> etiquetasDe(int rueda) => [
      for (final t in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(CupertinoPicker).at(rueda),
          matching: find.byType(Text),
        ),
      ))
        t.data!,
    ];
    final minutos = etiquetasDe(1).map(int.parse);
    expect(minutos, isNotEmpty);
    expect(minutos.every((m) => m <= 59), isTrue);
    expect(find.text('3420'), findsNothing);
    expect(minutos.contains(59), isTrue);

    await girar(tester, 0, 15); // 9 h -> tope de 24 h
    expect(c.read(seleccionModoProvider).meta.valor, 86400);
    expect(find.text('24 h'), findsOneWidget);
    expect(etiquetasDe(0).map(int.parse).every((h) => h <= 24), isTrue);
    expect(etiquetasDe(1).map(int.parse).every((m) => m <= 59), isTrue);
  });

  for (final brillo in Brightness.values) {
    testWidgets('sin desbordes a 360 px con una rueda abierta ($brillo)', (
      tester,
    ) async {
      await abrir(tester, brillo: brillo, alto: 700);
      await abrirHoja(tester, 'INTERVALOS');
      for (final fila in [
        'Correr',
        'Descanso',
        'Repeticiones',
        'Al terminar',
      ]) {
        await tester.tap(find.text(fila));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('LISTO'));
      await tester.pumpAndSettle();
      await abrirHoja(tester, 'META');
      await tester.tap(find.text('Objetivo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('historial', () {
    setUpAll(() => initializeDateFormatting('es'));

    Future<void> tarjeta(WidgetTester tester, ModoActividad? modo) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              trazoProvider.overrideWith((ref, id) async => const []),
            ],
            child: MaterialApp(
              theme: construirTema(AppColors.claro, Brightness.light),
              home: Scaffold(
                body: TarjetaActividad(
                  carrera: CarreraLocal(
                    id: 'a',
                    tipo: TipoActividad.correr,
                    origen: origenApp,
                    estado: EstadoCarrera.terminada,
                    inicioUtc: DateTime.utc(2026, 1, 1, 12),
                    finUtc: DateTime.utc(2026, 1, 1, 13),
                    distanciaM: 3200,
                    tiempoMovimientoS: 1000,
                    sincronizada: false,
                    creadoUtc: DateTime.utc(2026, 1, 1, 12),
                    modo: modo,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('la tarjeta muestra el modo con el que se hizo', (
      tester,
    ) async {
      await tarjeta(tester, const ModoIntervalos());
      expect(find.text('Intervalos 8 × 400 m'), findsOneWidget);
      await tarjeta(tester, const ModoMeta(valor: 10000));
      await tester.pump();
      expect(find.text('Meta 10 km'), findsOneWidget);
      await tarjeta(tester, const ModoMeta(medida: Medida.tiempo, valor: 1800));
      await tester.pump();
      expect(find.text('Meta 30 min'), findsOneWidget);
    });

    testWidgets('una actividad libre no muestra modo', (tester) async {
      await tarjeta(tester, null);
      expect(find.textContaining('Intervalos'), findsNothing);
      expect(find.textContaining('Meta'), findsNothing);
    });
  });
}
