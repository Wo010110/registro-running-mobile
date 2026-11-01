import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/core/clasificatoria_ejemplo.dart';
import 'package:heyrun_mobile/core/formato.dart';
import 'package:heyrun_mobile/core/historial.dart';
import 'package:heyrun_mobile/models/clasificatoria.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/models/user.dart';
import 'package:heyrun_mobile/providers/auth_provider.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/providers/historial_provider.dart';
import 'package:heyrun_mobile/providers/navegacion_provider.dart';
import 'package:heyrun_mobile/providers/perfil_provider.dart';
import 'package:heyrun_mobile/providers/theme_provider.dart';
import 'package:heyrun_mobile/screens/home_screen.dart';
import 'package:heyrun_mobile/screens/tabs/clasificatoria_tab.dart';
import 'package:heyrun_mobile/screens/tabs/perfil_tab.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';
import 'package:heyrun_mobile/theme/app_theme.dart';
import 'package:heyrun_mobile/widgets/tarjeta_actividad.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'u',
      email: 'ana@correo.com',
      displayName: 'Ana',
      createdAt: DateTime.utc(2026),
    ),
  );
}

class _Grabacion extends GrabacionNotifier {
  @override
  GrabacionState build() => const GrabacionState(
    fase: FaseGrabacion.inactivo,
    tipo: TipoActividad.correr,
  );

  @override
  Future<CarreraLocal?> carreraPendiente() async => null;
}

CarreraLocal _carrera(
  String id,
  DateTime inicio,
  double km, {
  TipoActividad tipo = TipoActividad.correr,
}) => CarreraLocal(
  id: id,
  tipo: tipo,
  origen: origenApp,
  estado: EstadoCarrera.terminada,
  inicioUtc: inicio.toUtc(),
  finUtc: inicio.toUtc().add(const Duration(minutes: 30)),
  distanciaM: km * 1000,
  tiempoMovimientoS: 1800,
  sincronizada: false,
  creadoUtc: inicio.toUtc(),
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('funciones puras', () {
    test('tiempo de un récord', () {
      expect(formatearTiempoRecord(14), '0:14');
      expect(formatearTiempoRecord(33.4), '0:33');
      expect(formatearTiempoRecord(280), '4:40');
      expect(formatearTiempoRecord(2025), '33:45');
      expect(formatearTiempoRecord(5140), '1:25:40');
      expect(formatearHorasMin(45 * 60), '45 min');
    });

    test('km de la semana, el mes y el histórico', () {
      // Miércoles 28 de octubre de 2026.
      final ahora = DateTime(2026, 10, 28, 12);
      final carreras = [
        _carrera('a', DateTime(2026, 10, 26, 7), 5), // lunes
        _carrera('b', DateTime(2026, 10, 28, 7), 10), // hoy
        _carrera('c', DateTime(2026, 10, 25, 7), 8), // domingo anterior
        _carrera('d', DateTime(2026, 10, 2, 7), 4), // mes, no semana
        _carrera('e', DateTime(2026, 9, 30, 7), 20), // mes anterior
      ];
      expect(kmDelPeriodo(carreras, PeriodoClasificatoria.semana, ahora), 15);
      expect(kmDelPeriodo(carreras, PeriodoClasificatoria.mes, ahora), 27);
      expect(
        kmDelPeriodo(carreras, PeriodoClasificatoria.historico, ahora),
        47,
      );
    });

    test('tu fila se coloca por tus km y la ciudad filtra', () {
      final mundo = clasificatoriaEjemplo(
        alcance: AlcanceClasificatoria.global,
        periodo: PeriodoClasificatoria.semana,
        tuNombre: 'Ana',
        tusKm: 30,
      );
      final tu = mundo.singleWhere((f) => f.esTu);
      expect(tu.nombre, 'Ana');
      expect(tu.km, 30);
      expect(tu.posicion, 6); // detrás de 54, 49, 41, 36 y 32
      expect(
        [for (final f in mundo) f.posicion],
        [for (var i = 1; i <= mundo.length; i++) i],
      );
      for (var i = 1; i < mundo.length; i++) {
        expect(mundo[i].km, lessThanOrEqualTo(mundo[i - 1].km));
      }
      final ciudad = clasificatoriaEjemplo(
        alcance: AlcanceClasificatoria.ciudad,
        periodo: PeriodoClasificatoria.semana,
        tuNombre: 'Ana',
        tusKm: 0,
      );
      expect(ciudad.length, lessThan(mundo.length));
      expect(ciudad.last.esTu, isTrue); // sin km, la última
      // El histórico es otra escala.
      final historico = clasificatoriaEjemplo(
        alcance: AlcanceClasificatoria.global,
        periodo: PeriodoClasificatoria.historico,
        tuNombre: 'Ana',
        tusKm: 30,
      );
      expect(historico.first.km, greaterThan(1000));
      expect(historico.singleWhere((f) => f.esTu).posicion, greaterThan(5));
    });
  });

  late ProviderContainer contenedor;

  Future<void> abrir(
    WidgetTester tester,
    Widget home, {
    List<CarreraLocal> historial = const [],
    Map<double, RecordPersonal> records = const {},
    Map<String, Object> prefsIniciales = const {},
    Brightness brillo = Brightness.light,
    double escala = 1,
    Size tam = const Size(360, 780),
  }) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = escala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues(prefsIniciales);
    final prefs = await SharedPreferences.getInstance();
    contenedor = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_Auth.new),
        grabacionProvider.overrideWith(_Grabacion.new),
        historialProvider.overrideWith((ref) async => historial),
        recordsProvider.overrideWith((ref) async => records),
        trazoProvider.overrideWith((ref, id) async => const []),
      ],
    );
    addTearDown(contenedor.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: contenedor,
        child: MaterialApp(
          theme: construirTema(
            brillo == Brightness.dark ? AppColors.oscuro : AppColors.claro,
            brillo,
          ),
          locale: const Locale('es'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es')],
          home: Scaffold(body: SafeArea(child: home)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final ahora = DateTime.now();
  final historial = [
    _carrera('a', ahora.subtract(const Duration(hours: 3)), 5),
    _carrera('b', ahora.subtract(const Duration(days: 40)), 10),
    _carrera(
      'c',
      ahora.subtract(const Duration(days: 50)),
      2.5,
      tipo: TipoActividad.caminar,
    ),
  ];

  group('Perfil', () {
    testWidgets('cabecera, cifras, medallas y récords', (tester) async {
      await abrir(
        tester,
        const PerfilTab(),
        historial: historial,
        records: {
          1000: RecordPersonal(
            objetivoM: 1000,
            tiempoS: 280,
            carreraId: 'a',
            inicioUtc: DateTime.utc(2026, 10, 12, 8),
          ),
          100: RecordPersonal(
            objetivoM: 100,
            tiempoS: 14,
            carreraId: 'a',
            inicioUtc: DateTime.utc(2026, 10, 12, 8),
          ),
        },
      );
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // inicial del avatar
      expect(find.text('Sin ciudad'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // actividades
      expect(find.text('17,5'), findsOneWidget); // km
      expect(find.text('Seguidores'), findsOneWidget);
      expect(find.text('Siguiendo'), findsOneWidget);
      expect(find.text('Primera salida'), findsOneWidget);
      expect(find.text('4:40'), findsOneWidget);
      expect(find.text('0:14'), findsOneWidget);
      expect(find.text('4:40 /km'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(6));
      for (final r in ['100 m', '500 m', '1 km', '5 km', '100 km']) {
        expect(find.text(r), findsWidgets);
      }
    });

    testWidgets('el historial se filtra por tipo y tiene estado vacío', (
      tester,
    ) async {
      await abrir(tester, const PerfilTab(), historial: historial);
      final lista = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Todas'),
        300,
        scrollable: lista,
      );
      expect(
        find.byType(TarjetaActividad, skipOffstage: false),
        findsNWidgets(3),
      );
      await tester.tap(find.text('Caminar'));
      await tester.pumpAndSettle();
      expect(
        find.byType(TarjetaActividad, skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.text('Correr'));
      await tester.pumpAndSettle();
      expect(
        find.byType(TarjetaActividad, skipOffstage: false),
        findsNWidgets(2),
      );
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(
        find.byType(TarjetaActividad, skipOffstage: false),
        findsNWidgets(3),
      );
      // Cada tarjeta conserva su menú Editar / Eliminar.
      expect(
        find.byTooltip('Más opciones', skipOffstage: false),
        findsNWidgets(3),
      );
    });

    testWidgets('sin actividades muestra el aviso', (tester) async {
      await abrir(tester, const PerfilTab());
      expect(find.text('0'), findsOneWidget); // actividades
      await tester.scrollUntilVisible(
        find.textContaining('Aún no tienes actividades'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    });

    testWidgets('editar ciudad y presentación se guarda en el teléfono', (
      tester,
    ) async {
      await abrir(tester, const PerfilTab());
      await tester.tap(find.text('EDITAR PERFIL'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Ciudad'),
        'Bogotá',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Presentación'),
        'Corro por las mañanas',
      );
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(find.text('Bogotá'), findsOneWidget);
      expect(find.text('Corro por las mañanas'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('perfil_ciudad'), 'Bogotá');
      expect(
        contenedor.read(perfilLocalProvider).presentacion,
        'Corro por las mañanas',
      );
    });

    testWidgets('la ciudad guardada se recuerda', (tester) async {
      await abrir(
        tester,
        const PerfilTab(),
        prefsIniciales: {'perfil_ciudad': 'Quito'},
      );
      expect(find.text('Quito'), findsOneWidget);
    });

    testWidgets('pedir el historial baja hasta él', (tester) async {
      await abrir(tester, const PerfilTab(), historial: historial);
      expect(find.text('Todas').hitTestable(), findsNothing);
      contenedor.read(solicitudHistorialProvider.notifier).pedir();
      await tester.pumpAndSettle();
      expect(find.text('Todas').hitTestable(), findsOneWidget);
    });

    for (final brillo in Brightness.values) {
      testWidgets('sin desbordes a 360 px ($brillo, texto x1,5)', (
        tester,
      ) async {
        await abrir(
          tester,
          const PerfilTab(),
          historial: historial,
          records: {
            for (final o in [100.0, 5000.0, 100000.0])
              o: RecordPersonal(
                objetivoM: o,
                tiempoS: 3 * 3600 + 25 * 60 + 40,
                carreraId: 'a',
                inicioUtc: DateTime.utc(2026, 10, 12, 8),
              ),
          },
          prefsIniciales: {
            'perfil_ciudad': 'San Cristóbal de las Casas',
            'perfil_presentacion': 'Una presentación bastante larga ' * 4,
          },
          brillo: brillo,
          escala: 1.5,
        );
        for (var i = 0; i < 8; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Clasificatoria', () {
    testWidgets('sin ciudad avisa y lleva al Perfil', (tester) async {
      await abrir(tester, const ClasificatoriaTab(), historial: historial);
      expect(find.text('Clasificatoria'), findsOneWidget);
      expect(find.text('Datos de ejemplo'), findsOneWidget);
      expect(find.text('ELEGIR CIUDAD'), findsOneWidget);
      expect(find.textContaining('(tú)'), findsNothing);
      await tester.tap(find.text('ELEGIR CIUDAD'));
      expect(contenedor.read(pestanaProvider), 3);
      // En global sí hay clasificación aun sin ciudad.
      await tester.tap(find.text('GLOBAL'));
      await tester.pump();
      expect(find.text('ELEGIR CIUDAD'), findsNothing);
      expect(find.text('Camila R.'), findsOneWidget);
    });

    testWidgets('con ciudad: podio, lista, tu fila y cambio de período', (
      tester,
    ) async {
      await abrir(
        tester,
        const ClasificatoriaTab(),
        historial: historial,
        prefsIniciales: {'perfil_ciudad': 'Bogotá'},
      );
      expect(find.text('ELEGIR CIUDAD'), findsNothing);
      expect(find.text('MI CIUDAD'), findsOneWidget);
      expect(find.text('SEMANA'), findsOneWidget);
      expect(find.text('HISTÓRICO'), findsOneWidget);
      // Podio (3 primeros) y bonificación de puntos.
      expect(find.text('Camila R.'), findsOneWidget);
      expect(find.text('Valentina P.'), findsOneWidget);
      expect(find.text('+410 pts'), findsOneWidget);
      // Tu fila, fija abajo, con tus km reales de la semana.
      expect(find.text('Ana (tú)'), findsWidgets);
      expect(find.text('5,0 km'), findsWidgets);
      expect(find.text('+$tusPuntosEjemplo pts'), findsWidgets);

      await tester.tap(find.text('HISTÓRICO'));
      await tester.pump();
      expect(find.text('2380,0 km'), findsOneWidget); // km con coma
      expect(find.textContaining('17,5 km'), findsWidgets);
    });

    for (final brillo in Brightness.values) {
      testWidgets('sin desbordes a 360 px ($brillo, texto x1,5)', (
        tester,
      ) async {
        await abrir(
          tester,
          const ClasificatoriaTab(),
          historial: historial,
          prefsIniciales: {'perfil_ciudad': 'Bogotá'},
          brillo: brillo,
          escala: 1.5,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Navegación', () {
    testWidgets('Inicio · Clasificatoria · Retos · Perfil', (tester) async {
      await abrir(
        tester,
        const HomeScreen(),
        historial: historial,
        tam: const Size(600, 900),
      );
      for (final t in ['Inicio', 'Clasificatoria', 'Retos', 'Perfil']) {
        expect(find.text(t), findsWidgets);
      }
      expect(find.text('Actividades'), findsNothing);
      await tester.tap(find.text('Clasificatoria'));
      await tester.pumpAndSettle();
      expect(contenedor.read(pestanaProvider), 1);
      expect(find.text('Datos de ejemplo').hitTestable(), findsOneWidget);
    });

    testWidgets('Ver todas lleva al historial del Perfil', (tester) async {
      await abrir(
        tester,
        const HomeScreen(),
        historial: historial,
        tam: const Size(600, 900),
      );
      await tester.scrollUntilVisible(
        find.text('Ver todas'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(contenedor.read(pestanaProvider), 3);
      expect(
        find.text('Historial de actividades').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Todas').hitTestable(), findsOneWidget);
    });
  });
}
