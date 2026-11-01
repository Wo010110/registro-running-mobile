import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/carreras_db.dart';
import 'package:heyrun_mobile/core/historial.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/screens/resumen_screen.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';
import 'package:heyrun_mobile/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Notifier con estado fijo que anota lo que le piden.
class _Fijo extends GrabacionNotifier {
  _Fijo(this.estado);

  final GrabacionState estado;
  final llamadas = <String>[];

  @override
  GrabacionState build() => estado;

  @override
  Future<void> cerrar() async => llamadas.add('cerrar');

  @override
  Future<void> descartar() async => llamadas.add('descartar');
}

/// Base que anota lo que se guarda; solo lo que usa la pantalla.
class _Db implements CarrerasDb {
  final guardados = <Map<String, Object?>>[];
  var falla = false;

  @override
  Future<void> actualizarDetalles(
    String carreraId, {
    String? titulo,
    String? descripcion,
    int? intensidad,
    required TipoActividad tipo,
  }) async {
    if (falla) throw Exception('disco');
    guardados.add({
      'id': carreraId,
      'titulo': titulo,
      'descripcion': descripcion,
      'intensidad': intensidad,
      'tipo': tipo,
    });
  }

  @override
  Future<CarreraLocal?> carrera(String id) async => null;
  @override
  Future<List<PuntoGps>> puntos(String carreraId) async => [
    for (var s = 0; s < 4; s++)
      PuntoGps(
        lat: 4 + s / 10000,
        lng: -74,
        precisionM: 5,
        instante: DateTime.utc(2026, 11, 1, 18, 15, s * 5),
      ),
  ];
  @override
  Future<List<PausaCarrera>> pausas(String carreraId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _inicio = DateTime.utc(2026, 11, 1, 18, 15);

CarreraLocal _carrera({
  String? titulo,
  String? descripcion,
  int? intensidad,
  ModoActividad? modo,
}) => CarreraLocal(
  id: 'c1',
  tipo: TipoActividad.correr,
  origen: origenApp,
  estado: EstadoCarrera.terminada,
  inicioUtc: _inicio,
  finUtc: _inicio.add(const Duration(minutes: 25)),
  distanciaM: 5000,
  tiempoMovimientoS: 1500,
  sincronizada: false,
  creadoUtc: _inicio,
  modo: modo,
  titulo: titulo,
  descripcion: descripcion,
  intensidad: intensidad,
);

GrabacionState _estadoTerminado({ModoActividad modo = const ModoLibre()}) =>
    GrabacionState(
      fase: FaseGrabacion.terminada,
      tipo: TipoActividad.correr,
      carreraId: 'c1',
      inicioUtc: _inicio,
      tiempoTotalS: 1500,
      modo: modo,
      ruta: [
        [
          for (var s = 0; s < 3; s++)
            PuntoGps(
              lat: 4 + s / 10000,
              lng: -74,
              precisionM: 5,
              instante: _inicio.add(Duration(seconds: s)),
            ),
        ],
      ],
      resumen: const ResumenCarrera(
        distanciaM: 5000,
        tiempoMovimientoS: 1500,
        ritmoMedioSKm: 300,
        ritmoActualSKm: null,
        parcialesS: [],
        huecos: [],
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  late _Db db;
  late _Fijo notifier;

  /// Abre la pantalla desde un botón, para poder volver atrás.
  Future<void> abrir(
    WidgetTester tester, {
    CarreraLocal? carrera,
    Brightness brillo = Brightness.light,
    double escala = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = escala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    db = _Db();
    notifier = _Fijo(_estadoTerminado());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grabacionProvider.overrideWith(() => notifier),
          carrerasDbProvider.overrideWithValue(db),
        ],
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResumenScreen(carrera: carrera),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
  }

  Finder campo(String etiqueta) =>
      find.widgetWithText(TextField, etiqueta).first;

  String texto(WidgetTester tester, String etiqueta) =>
      tester.widget<TextField>(campo(etiqueta)).controller!.text;

  group('modo edición', () {
    testWidgets('precarga todo y ofrece GUARDAR y CANCELAR', (tester) async {
      await abrir(
        tester,
        carrera: _carrera(
          titulo: 'Mi tirada larga',
          descripcion: 'Buen día',
          intensidad: 3,
        ),
      );
      expect(find.text('EDITAR ACTIVIDAD'), findsOneWidget);
      expect(find.text('Mi tirada larga'), findsOneWidget);
      expect(find.text('Buen día'), findsOneWidget);
      expect(find.text('Podías hablar a ratos'), findsOneWidget);
      expect(find.text('GUARDAR'), findsOneWidget);
      expect(find.text('CANCELAR'), findsOneWidget);
      expect(find.text('DESCARTAR'), findsNothing);
      expect(find.text('5,00 km'), findsOneWidget);
    });

    testWidgets('sin título guardado propone el de siempre', (tester) async {
      await abrir(tester, carrera: _carrera());
      final propuesto = tituloActividad(TipoActividad.correr, _inicio);
      expect(texto(tester, 'Título'), propuesto);
    });

    testWidgets('GUARDAR escribe los cambios y vuelve', (tester) async {
      await abrir(tester, carrera: _carrera());
      await tester.enterText(campo('Título'), 'Rodaje');
      await tester.enterText(campo('Descripción'), 'Piernas pesadas');
      await tocar(tester, find.text('CAMINAR'));
      await tocar(tester, find.text('Dura'));
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(db.guardados.single, {
        'id': 'c1',
        'titulo': 'Rodaje',
        'descripcion': 'Piernas pesadas',
        'intensidad': 4,
        'tipo': TipoActividad.caminar,
      });
      expect(find.text('abrir'), findsOneWidget);
      expect(notifier.llamadas, isEmpty); // no toca la grabación
    });

    testWidgets('Atrás y CANCELAR salen sin guardar', (tester) async {
      await abrir(tester, carrera: _carrera());
      await tester.enterText(campo('Título'), 'Cambio');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
      expect(db.guardados, isEmpty);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
      expect(db.guardados, isEmpty);
    });
  });

  group('modo resumen', () {
    testWidgets('título, tipo, datos y huecos de la pantalla', (tester) async {
      await abrir(tester);
      expect(find.text('RESUMEN'), findsOneWidget);
      expect(
        find.textContaining('Correr · 1 de noviembre 2026'),
        findsOneWidget,
      );
      expect(find.text('Distancia'), findsOneWidget);
      expect(find.text('Tiempo'), findsOneWidget);
      expect(find.text('Ritmo'), findsOneWidget);
      expect(find.text('CORRER'), findsOneWidget);
      expect(find.text('CAMINAR'), findsOneWidget);
      expect(find.text('GUARDAR'), findsOneWidget);
      expect(find.text('DESCARTAR'), findsOneWidget);
      expect(find.text('CANCELAR'), findsNothing);
    });

    testWidgets('el título vacío o igual al propuesto se guarda como null', (
      tester,
    ) async {
      await abrir(tester);
      await tester.enterText(campo('Título'), '   ');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(db.guardados.single['titulo'], isNull);
      expect(notifier.llamadas, ['cerrar']);
    });

    testWidgets('cambiar el tipo mueve el título propuesto, no uno propio', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('CAMINAR'));
      await tester.pump();
      expect(
        texto(tester, 'Título'),
        tituloActividad(TipoActividad.caminar, _inicio),
      );
      await tester.enterText(campo('Título'), 'Mío');
      await tester.tap(find.text('CORRER'));
      await tester.pump();
      expect(texto(tester, 'Título'), 'Mío');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(db.guardados.single['titulo'], 'Mío');
      expect(db.guardados.single['tipo'], TipoActividad.correr);
    });

    testWidgets('contador de la descripción, máximo 500', (tester) async {
      await abrir(tester);
      expect(find.text('0/500'), findsOneWidget);
      await tester.enterText(campo('Descripción'), 'hola');
      await tester.pump();
      expect(find.text('4/500'), findsOneWidget);
      await tester.enterText(campo('Descripción'), 'x' * 600);
      await tester.pump();
      expect(find.text('500/500'), findsOneWidget);
    });

    testWidgets('la intensidad se elige, explica y se desmarca', (
      tester,
    ) async {
      await abrir(tester);
      for (final n in ['Muy suave', 'Suave', 'Moderada', 'Dura', 'Máxima']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Solo frases cortas'), findsNothing);
      await tocar(tester, find.text('Dura'));
      expect(find.text('Solo frases cortas'), findsOneWidget);
      await tocar(tester, find.text('Máxima'));
      expect(find.text('Solo frases cortas'), findsNothing);
      expect(find.text('No podías hablar'), findsOneWidget);
      await tocar(tester, find.text('Máxima')); // de nuevo: se desmarca
      expect(find.text('No podías hablar'), findsNothing);
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(db.guardados.single['intensidad'], isNull);
    });

    testWidgets('fotos, medalla y dorsal solo avisan que llegan pronto', (
      tester,
    ) async {
      await abrir(tester);
      final scroll = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Foto de tu dorsal'),
        200,
        scrollable: scroll,
      );
      expect(
        find.text('Luego la IA los redibujará para tu actividad'),
        findsOneWidget,
      );
      await tester.tap(find.text('Foto de tu medalla'));
      await tester.pump();
      expect(find.text('Pronto podrás subir fotos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('foto-mas')),
        -200,
        scrollable: scroll,
      );
      expect(find.text('0/5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const ValueKey('foto-mas')));
      await tester.pump();
      expect(find.text('Pronto podrás subir fotos'), findsOneWidget);
      expect(db.guardados, isEmpty); // no se guarda nada
    });

    test('las fotos no traen dependencias nuevas', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('image_picker')));
      expect(pubspec, isNot(contains('path_provider')));
    });

    testWidgets('Atrás guarda igual que GUARDAR', (tester) async {
      await abrir(tester);
      await tester.enterText(campo('Título'), 'Salida');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(db.guardados.single['titulo'], 'Salida');
      expect(notifier.llamadas, ['cerrar']);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('si falla el guardado muestra el error y no sale', (
      tester,
    ) async {
      await abrir(tester);
      db.falla = true;
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudo guardar. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('RESUMEN'), findsOneWidget);
      expect(notifier.llamadas, isEmpty);
      db.falla = false;
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(notifier.llamadas, ['cerrar']);
    });

    testWidgets('DESCARTAR sigue pidiendo confirmación', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('DESCARTAR'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar la actividad?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(notifier.llamadas, isEmpty);
    });
  });

  for (final brillo in Brightness.values) {
    for (final escala in [1.0, 1.5]) {
      testWidgets('sin desbordes a 360 px ($brillo, texto x$escala)', (
        tester,
      ) async {
        await abrir(
          tester,
          carrera: _carrera(
            titulo: 'Una tirada con un título bastante largo para ver',
            descripcion: 'Descripción ' * 20,
            intensidad: 4,
            modo: const ModoIntervalos(),
          ),
          brillo: brillo,
          escala: escala,
        );
        final scroll = find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Foto de tu dorsal'),
          200,
          scrollable: scroll,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Ritmo tramos'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
