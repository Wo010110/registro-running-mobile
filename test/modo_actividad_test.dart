import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/providers/modo_provider.dart';
import 'package:heyrun_mobile/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('texto para el historial', () {
    test('intervalos por distancia y por tiempo', () {
      expect(const ModoIntervalos().etiqueta, 'Intervalos 8 × 400 m');
      expect(
        const ModoIntervalos(
          tramoMedida: Medida.tiempo,
          tramo: 120,
          repeticiones: null,
        ).etiqueta,
        'Intervalos sin límite × 2 min',
      );
      expect(
        const ModoIntervalos(tramo: 1500, repeticiones: 3).etiqueta,
        'Intervalos 3 × 1,5 km',
      );
    });

    test('meta por distancia y por tiempo; libre no lleva etiqueta', () {
      expect(const ModoMeta(valor: 10000).etiqueta, 'Meta 10 km');
      expect(
        const ModoMeta(medida: Medida.tiempo, valor: 1800).etiqueta,
        'Meta 30 min',
      );
      expect(const ModoLibre().etiqueta, isNull);
    });

    test('línea de configuración de la pantalla de preparar', () {
      expect(const ModoIntervalos().resumen, '8 × 400 m · descanso 90 s');
      expect(
        const ModoIntervalos(
          repeticiones: null,
          descansoMedida: Medida.distancia,
          descanso: 100,
        ).resumen,
        'Sin límite × 400 m · descanso 100 m',
      );
    });
  });

  group('JSON', () {
    test('intervalos y meta van y vuelven iguales', () {
      const i = ModoIntervalos(
        tramoMedida: Medida.tiempo,
        tramo: 90,
        descansoMedida: Medida.distancia,
        descanso: 200,
        repeticiones: null,
        alTerminar: AlTerminarIntervalos.libre,
      );
      final i2 = ModoActividad.desdeTexto(i.aTexto())! as ModoIntervalos;
      expect(i2.aJson(), i.aJson());
      expect(i2.repeticiones, isNull);
      expect(i2.alTerminar, AlTerminarIntervalos.libre);

      const m = ModoMeta(
        medida: Medida.tiempo,
        valor: 1800,
        alLlegar: AlLlegarMeta.pausar,
      );
      final m2 = ModoActividad.desdeTexto(m.aTexto())! as ModoMeta;
      expect(m2.aJson(), m.aJson());
    });

    test('libre se guarda como null y lo ilegible se trata como libre', () {
      expect(const ModoLibre().aTexto(), isNull);
      expect(ModoActividad.desdeTexto(null), isNull);
      expect(ModoActividad.desdeTexto('no es json'), isNull);
      expect(ModoActividad.desdeTexto('[1,2]'), isNull);
      expect(ModoActividad.desdeTexto('{"modo":"otro"}'), isNull);
    });

    test('valores inválidos vuelven a los de por defecto', () {
      final m =
          ModoActividad.desdeTexto(
                '{"modo":"intervalos","tramo":-5,"tramoMedida":"x","repeticiones":0}',
              )!
              as ModoIntervalos;
      expect(m.tramo, 400);
      expect(m.tramoMedida, Medida.distancia);
      expect(m.repeticiones, 8);
    });
  });

  group('selección recordada', () {
    Future<ProviderContainer> abrir([
      Map<String, Object> previo = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(previo);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('por defecto: libre con la configuración de fábrica', () async {
      final c = await abrir();
      final s = c.read(seleccionModoProvider);
      expect(s.tipo, TipoModo.libre);
      expect(s.modo, isA<ModoLibre>());
      expect(s.intervalos.etiqueta, 'Intervalos 8 × 400 m');
    });

    test(
      'recuerda el último modo y la última configuración de cada uno',
      () async {
        final c1 = await abrir();
        final n = c1.read(seleccionModoProvider.notifier);
        await n.guardarIntervalos(
          const ModoIntervalos(tramo: 800, repeticiones: 5),
        );
        await n.guardarMeta(const ModoMeta(valor: 10000));
        await n.elegir(TipoModo.intervalos);

        // Otra sesión con las mismas preferencias.
        final prefs = await SharedPreferences.getInstance();
        final c2 = ProviderContainer(
          overrides: [prefsProvider.overrideWithValue(prefs)],
        );
        addTearDown(c2.dispose);
        final s = c2.read(seleccionModoProvider);
        expect(s.tipo, TipoModo.intervalos);
        expect((s.modo as ModoIntervalos).etiqueta, 'Intervalos 5 × 800 m');
        expect(s.meta.etiqueta, 'Meta 10 km');
      },
    );

    test('un valor guardado que no se entiende no rompe', () async {
      final c = await abrir({
        'modo_ultimo': 'raro',
        'modo_intervalos': '{',
        'modo_meta': '{"modo":"intervalos"}',
      });
      final s = c.read(seleccionModoProvider);
      expect(s.tipo, TipoModo.libre);
      expect(s.intervalos.etiqueta, 'Intervalos 8 × 400 m');
      expect(s.meta.etiqueta, 'Meta 5 km');
    });
  });
}
