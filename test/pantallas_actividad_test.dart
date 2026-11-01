import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/core/motor_modos.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/providers/theme_provider.dart';
import 'package:heyrun_mobile/screens/actividad_screen.dart';
import 'package:heyrun_mobile/screens/resumen_screen.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';
import 'package:heyrun_mobile/theme/app_theme.dart';
import 'package:heyrun_mobile/widgets/aviso_recuperacion.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void saltarDescanso() => llamadas.add('saltar');

  @override
  Future<void> preparar(TipoActividad tipo) async {}

  @override
  void cambiarModo(ModoActividad modo) =>
      llamadas.add('modo ${modo.etiqueta ?? 'libre'}');

  @override
  Future<void> iniciar() async => llamadas.add('iniciar');
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
        ruta: [
          [_punto(0), _punto(1), _punto(2)],
        ],
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
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('5,01 km'), findsOneWidget);
    expect(find.text('00:25:00'), findsOneWidget);
    expect(find.text('4:59 /km'), findsOneWidget);
    expect(find.textContaining('Caminar · '), findsOneWidget);
    // La lista de parciales está dentro del contenedor, que se desplaza.
    await tester.scrollUntilVisible(
      find.text('Km 2'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Km 1'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
    expect(find.text('Km 2'), findsOneWidget);
    expect(find.text('GUARDAR'), findsOneWidget);
    expect(find.textContaining('En movimiento'), findsNothing);

    await tester.tap(find.text('DESCARTAR'));
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
        ruta: [
          [_punto(0), _punto(1)],
        ],
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
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:30:00'), findsOneWidget);
    expect(find.text('En movimiento · 00:25:00'), findsOneWidget);
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

  testWidgets('en intervalos el resumen dice que el ritmo es de los tramos', (
    tester,
  ) async {
    final notifier = _Fijo(
      GrabacionState(
        fase: FaseGrabacion.terminada,
        tipo: TipoActividad.correr,
        carreraId: 'x',
        tiempoTotalS: 900,
        inicioUtc: DateTime.utc(2026, 11, 15, 12, 30),
        ruta: [
          [_punto(0), _punto(1)],
        ],
        modo: const ModoIntervalos(),
        resumen: const ResumenCarrera(
          distanciaM: 3000,
          tiempoMovimientoS: 900,
          ritmoMedioSKm: 300,
          ritmoActualSKm: null,
          parcialesS: [],
          huecos: [],
        ),
      ),
    );
    await tester.pumpWidget(_app(notifier, const ResumenScreen()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ritmo tramos'), findsOneWidget);
    expect(find.text('Ritmo medio'), findsNothing);
  });

  testWidgets('valores anchos con fuente grande no se tocan ni desbordan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final notifier = _Fijo(
      const GrabacionState(
        fase: FaseGrabacion.grabando,
        tipo: TipoActividad.correr,
        carreraId: 'x',
        distanciaM: 12345,
        tiempoTotalS: 3753,
        ritmoActualSKm: 894,
        ritmoMedioSKm: 1732,
      ),
    );
    await tester.pumpWidget(_app(notifier, const ActividadScreen()));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('01:02:33'), findsOneWidget);
    final a = tester.getRect(find.text('14:54 /km'));
    final b = tester.getRect(find.text('28:52 /km'));
    expect(a.right + 8, lessThanOrEqualTo(b.left));
  });

  testWidgets('el resumen con valores anchos no desborda a 360 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final notifier = _Fijo(
      GrabacionState(
        fase: FaseGrabacion.terminada,
        tipo: TipoActividad.correr,
        carreraId: 'x',
        tiempoTotalS: 5753,
        inicioUtc: DateTime.utc(2026, 11, 1, 18, 15),
        ruta: [
          [_punto(0), _punto(1)],
        ],
        resumen: const ResumenCarrera(
          distanciaM: 5000,
          tiempoMovimientoS: 3753,
          ritmoMedioSKm: 1732,
          ritmoActualSKm: null,
          parcialesS: [],
          huecos: [],
        ),
      ),
    );
    await tester.pumpWidget(_app(notifier, const ResumenScreen()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('28:52 /km'), findsOneWidget);
    expect(find.textContaining('01:02:33'), findsOneWidget);
  });

  group('vista de grabación con modos', () {
    Future<_Fijo> abrir(WidgetTester tester, GrabacionState estado) async {
      // Ancho de un teléfono: así salta cualquier desborde.
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final notifier = _Fijo(estado);
      await tester.pumpWidget(_app(notifier, const ActividadScreen()));
      await tester.pump(const Duration(seconds: 3));
      return notifier;
    }

    GrabacionState grabando({
      FaseGrabacion fase = FaseGrabacion.grabando,
      ModoActividad modo = const ModoLibre(),
      EstadoModo? estadoModo,
    }) => GrabacionState(
      fase: fase,
      tipo: TipoActividad.correr,
      carreraId: 'x',
      modo: modo,
      estadoModo: estadoModo,
      distanciaM: 1200,
      tiempoTotalS: 600,
    );

    testWidgets('libre queda igual: sin repetición ni barra', (tester) async {
      await abrir(tester, grabando());
      expect(find.text('00:10:00'), findsOneWidget);
      expect(find.text('Ritmo medio'), findsOneWidget);
      expect(find.textContaining('Repetición'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('PAUSAR'), findsOneWidget);
      expect(find.text('FINALIZAR'), findsOneWidget);
    });

    testWidgets('intervalos corriendo: repetición, tiempo del tramo y barra', (
      tester,
    ) async {
      await abrir(
        tester,
        grabando(
          modo: const ModoIntervalos(),
          estadoModo: const EstadoModo(
            fase: FaseModo.corriendo,
            repeticion: 3,
            progreso: 245,
            objetivo: 400,
            tiempoTramoS: 75,
            distanciaTramoM: 245,
            ritmoTramoSKm: 306,
          ),
        ),
      );
      expect(find.text('Repetición 3 de 8'), findsOneWidget);
      expect(find.text('00:01:15'), findsOneWidget);
      expect(find.text('245 / 400 m'), findsOneWidget);
      expect(find.text('Ritmo del tramo'), findsOneWidget);
      expect(find.text('5:06 /km'), findsOneWidget);
      expect(find.text('PAUSAR'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Las tres columnas de datos quedan alineadas, con la etiqueta en una
      // línea.
      final etiquetas = [
        for (final t in ['Kilómetros', 'Ritmo actual', 'Ritmo del tramo'])
          tester.getRect(find.text(t)),
      ];
      expect(
        etiquetas.every(
          (r) => (r.center.dy - etiquetas.first.center.dy).abs() < 0.5,
        ),
        isTrue,
      );
      expect(etiquetas.every((r) => r.height < 20), isTrue);
      final valores = [
        for (final t in ['1,20', '--:-- /km', '5:06 /km'])
          tester.getRect(find.text(t)).center.dy,
      ];
      expect(valores.every((y) => (y - valores.first).abs() < 0.5), isTrue);
    });

    testWidgets('sin límite no dice "de N"', (tester) async {
      await abrir(
        tester,
        grabando(
          modo: const ModoIntervalos(repeticiones: null),
          estadoModo: const EstadoModo(
            fase: FaseModo.corriendo,
            repeticion: 4,
            objetivo: 400,
          ),
        ),
      );
      expect(find.text('Repetición 4'), findsOneWidget);
    });

    testWidgets('descansando: cuenta atrás, DESCANSO y saltar', (tester) async {
      final notifier = await abrir(
        tester,
        grabando(
          fase: FaseGrabacion.pausada,
          modo: const ModoIntervalos(),
          estadoModo: const EstadoModo(
            fase: FaseModo.descansando,
            repeticion: 3,
            progreso: 400,
            objetivo: 400,
            tiempoTramoS: 80,
            ritmoTramoSKm: 200,
            restanteDescanso: 45.2,
          ),
        ),
      );
      expect(find.text('Descanso'), findsOneWidget);
      expect(find.text('00:00:46'), findsOneWidget);
      expect(find.text('Repetición 3 de 8'), findsOneWidget);
      expect(find.text('3:20 /km'), findsOneWidget);
      expect(find.text('REANUDAR'), findsNothing);
      // El texto y el icono no tocan los bordes del botón.
      await tester.pump(const Duration(seconds: 2));
      final boton = tester.getRect(
        find.ancestor(
          of: find.text('SALTAR DESCANSO'),
          matching: find.byType(InkWell),
        ),
      );
      final texto = tester.getRect(find.text('SALTAR DESCANSO'));
      expect(texto.right, lessThanOrEqualTo(boton.right - 16));
      expect(texto.left, greaterThan(boton.left + 16));
      await tester.tap(find.text('SALTAR DESCANSO'));
      expect(notifier.llamadas, ['saltar']);
    });

    testWidgets('descanso por metros muestra los metros que faltan', (
      tester,
    ) async {
      await abrir(
        tester,
        grabando(
          fase: FaseGrabacion.pausada,
          modo: const ModoIntervalos(
            descansoMedida: Medida.distancia,
            descanso: 100,
          ),
          estadoModo: const EstadoModo(
            fase: FaseModo.descansando,
            repeticion: 1,
            objetivo: 400,
            restanteDescanso: 62.3,
          ),
        ),
      );
      expect(find.text('63 m'), findsOneWidget);
      expect(find.text('de 100 m'), findsOneWidget);
    });

    testWidgets('meta: barra con el progreso hacia la meta', (tester) async {
      await abrir(
        tester,
        grabando(
          modo: const ModoMeta(valor: 10000),
          estadoModo: const EstadoModo(
            fase: FaseModo.corriendo,
            progreso: 3200,
            objetivo: 10000,
          ),
        ),
      );
      expect(find.text('3,20 / 10 km'), findsOneWidget);
      expect(find.text('Ritmo medio'), findsOneWidget);
      expect(find.textContaining('Repetición'), findsNothing);
    });

    testWidgets('meta por tiempo se escribe como m:ss', (tester) async {
      await abrir(
        tester,
        grabando(
          modo: const ModoMeta(medida: Medida.tiempo, valor: 1800),
          estadoModo: const EstadoModo(
            fase: FaseModo.corriendo,
            progreso: 750,
            objetivo: 1800,
          ),
        ),
      );
      expect(find.text('12:30 / 30:00'), findsOneWidget);
    });

    testWidgets('intervalos terminados se siguen como libre', (tester) async {
      await abrir(
        tester,
        grabando(
          modo: const ModoIntervalos(repeticiones: 2),
          estadoModo: const EstadoModo(
            fase: FaseModo.terminado,
            repeticion: 2,
            progreso: 410,
            objetivo: 400,
          ),
        ),
      );
      expect(find.text('Intervalos completados'), findsOneWidget);
      expect(find.text('00:10:00'), findsOneWidget);
      expect(find.text('Ritmo medio'), findsOneWidget);
    });
  });

  group('preparar con modos', () {
    // Permisos concedidos en los canales de la plataforma.
    void permisosConcedidos(WidgetTester tester) {
      final m = tester.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (call) async => switch (call.method) {
          'checkPermission' => 3, // siempre
          'isLocationServiceEnabled' => true,
          _ => null,
        },
      );
      m.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => call.method == 'requestPermissions'
            ? {for (final p in call.arguments as List) p: 1}
            : null,
      );
      addTearDown(() {
        m.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          null,
        );
        m.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
      });
    }

    testWidgets('MODOS va sobre Nueva actividad y se inicia con el modo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      permisosConcedidos(tester);
      SharedPreferences.setMockInitialValues({'ayuda_bateria_vista': true});
      final prefs = await SharedPreferences.getInstance();
      final notifier = _Fijo(
        GrabacionState(
          fase: FaseGrabacion.preparando,
          tipo: TipoActividad.correr,
          posicion: PuntoGps(
            lat: 4,
            lng: -74,
            precisionM: 5,
            instante: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            grabacionProvider.overrideWith(() => notifier),
            prefsProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: construirTema(AppColors.claro, Brightness.light),
            home: const ActividadScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final modos = tester.getRect(find.text('MODOS'));
      final gps = tester.getRect(find.text('GPS'));
      expect(modos.bottom, lessThan(gps.top));
      expect(modos.center.dx, closeTo(gps.center.dx, 60));

      await tester.tap(find.text('INTERVALOS'));
      await tester.pump();
      expect(find.text('8 × 400 m · descanso 90 s'), findsOneWidget);

      await tester.tap(find.text('INICIAR'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        notifier.llamadas,
        containsAllInOrder(['modo Intervalos 8 × 400 m', 'iniciar']),
      );
    });
  });
}
