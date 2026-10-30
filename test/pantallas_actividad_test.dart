import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/screens/resumen_screen.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';
import 'package:heyrun_mobile/theme/app_theme.dart';
import 'package:heyrun_mobile/widgets/aviso_recuperacion.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Notifier con estado fijo que anota lo que le piden.
class _Fijo extends GrabacionNotifier {
  _Fijo(this.estado, {this.pendiente});

  final GrabacionState estado;
  final CarreraLocal? pendiente;
  final llamadas = <String>[];

  @override
  GrabacionState build() => estado;

  @override
  Future<CarreraLocal?> carreraPendiente() async => pendiente;

  @override
  Future<void> continuar(CarreraLocal carrera) async =>
      llamadas.add('continuar');

  @override
  Future<void> terminarPendiente(CarreraLocal carrera) async =>
      llamadas.add('terminar');

  @override
  Future<void> descartarPendiente(CarreraLocal carrera) async =>
      llamadas.add('descartar');

  @override
  Future<void> descartar() async => llamadas.add('descartar');

  @override
  Future<void> cerrar() async => llamadas.add('cerrar');
}

Widget _app(_Fijo notifier, Widget home) => ProviderScope(
  overrides: [grabacionProvider.overrideWith(() => notifier)],
  child: MaterialApp(
    theme: construirTema(AppColors.claro, Brightness.light),
    locale: const Locale('es'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es')],
    home: home,
  ),
);

PuntoGps _punto(int s) => PuntoGps(
  lat: 4 + s / 10000,
  lng: -74,
  precisionM: 5,
  instante: DateTime.utc(2026, 1, 1, 8, 0, s),
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el resumen muestra las cifras, el tipo y los parciales', (
    tester,
  ) async {
    final notifier = _Fijo(
      GrabacionState(
        fase: FaseGrabacion.terminada,
        tipo: TipoActividad.caminar,
        carreraId: 'x',
        tiempoTotalS: 1500,
        inicioUtc: DateTime.utc(2026, 11, 15, 12, 30),
        ruta: [_punto(0), _punto(1), _punto(2)],
        resumen: const ResumenCarrera(
          distanciaM: 5012.5,
          tiempoMovimientoS: 1500,
          ritmoMedioSKm: 299.3,
          ritmoActualSKm: null,
          parcialesS: [300, 295],
          huecos: [],
        ),
      ),
    );
    await tester.pumpWidget(_app(notifier, const ResumenScreen()));
    await tester.pump();

    expect(find.text('5,01 km'), findsOneWidget);
    expect(find.text('00:25:00'), findsOneWidget);
    expect(find.text('4:59 /km'), findsOneWidget);
    expect(find.textContaining('Caminar · '), findsOneWidget);
    expect(find.text('Km 1'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
    expect(find.text('Km 2'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('En movimiento'), findsNothing);

    await tester.scrollUntilVisible(find.text('Descartar'), 200);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar la actividad?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(notifier.llamadas, isEmpty);
  });

  testWidgets('el resumen muestra tiempo total y en movimiento si difieren', (
    tester,
  ) async {
    final notifier = _Fijo(
      GrabacionState(
        fase: FaseGrabacion.terminada,
        tipo: TipoActividad.correr,
        carreraId: 'x',
        tiempoTotalS: 1800,
        inicioUtc: DateTime.utc(2026, 11, 15, 12, 30),
        ruta: [_punto(0), _punto(1)],
        resumen: const ResumenCarrera(
          distanciaM: 5000,
          tiempoMovimientoS: 1500,
          ritmoMedioSKm: 300,
          ritmoActualSKm: null,
          parcialesS: [],
          huecos: [],
        ),
      ),
    );
    await tester.pumpWidget(_app(notifier, const ResumenScreen()));
    await tester.pump();
    expect(find.text('00:30:00'), findsOneWidget);
    expect(find.text('En movimiento'), findsOneWidget);
    expect(find.text('00:25:00'), findsOneWidget);
  });

  group('aviso de actividad sin terminar', () {
    final pendiente = CarreraLocal(
      id: 'p',
      tipo: TipoActividad.correr,
      origen: origenApp,
      estado: EstadoCarrera.grabando,
      inicioUtc: DateTime.utc(2026, 11, 15, 12),
      finUtc: null,
      distanciaM: 0,
      tiempoMovimientoS: 0,
      sincronizada: false,
      creadoUtc: DateTime.utc(2026, 11, 15, 12),
    );
    const inactivo = GrabacionState(
      fase: FaseGrabacion.inactivo,
      tipo: TipoActividad.correr,
    );

    Widget host() => Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () => avisarActividadPendiente(context, ref),
          child: const Text('abrir'),
        ),
      ),
    );

    testWidgets('sin pendiente no aparece nada', (tester) async {
      await tester.pumpWidget(_app(_Fijo(inactivo), host()));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Tienes una actividad sin terminar'), findsNothing);
    });

    testWidgets('ofrece las tres opciones y descartar pide confirmación', (
      tester,
    ) async {
      final notifier = _Fijo(inactivo, pendiente: pendiente);
      await tester.pumpWidget(_app(notifier, host()));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Tienes una actividad sin terminar'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Terminar y guardar'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar la actividad?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(notifier.llamadas, isEmpty);
      // Al cancelar vuelve a ofrecer las opciones.
      expect(find.text('Tienes una actividad sin terminar'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();
      expect(notifier.llamadas, ['descartar']);
      expect(find.text('Tienes una actividad sin terminar'), findsNothing);
    });
  });
}
