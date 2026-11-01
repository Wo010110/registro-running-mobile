import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/motor_modos.dart';
import 'package:heyrun_mobile/core/notificacion_grabacion.dart';
import 'package:heyrun_mobile/models/modo_actividad.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';
import 'package:heyrun_mobile/providers/grabacion_provider.dart';
import 'package:heyrun_mobile/providers/notificacion_provider.dart';

GrabacionState _estado({
  FaseGrabacion fase = FaseGrabacion.grabando,
  ModoActividad modo = const ModoLibre(),
  EstadoModo? estadoModo,
  int tiempoS = 1421,
  double distanciaM = 3250,
}) => GrabacionState(
  fase: fase,
  tipo: TipoActividad.correr,
  modo: modo,
  estadoModo: estadoModo,
  tiempoTotalS: tiempoS,
  distanciaM: distanciaM,
  ritmoActualSKm: 332,
);

class _Control extends GrabacionNotifier {
  @override
  GrabacionState build() => _estado(fase: FaseGrabacion.inactivo);

  void poner(GrabacionState g) => state = g;
}

class _Anota implements NotificadorGrabacion {
  final llamadas = <String>[];

  @override
  Future<void> actualizar(String titulo, String texto) async =>
      llamadas.add('$titulo|$texto');
}

void main() {
  group('texto de la notificación', () {
    test('libre', () {
      final t = textoNotificacion(_estado())!;
      expect(t.titulo, '00:23:41 · 3,25 km');
      expect(t.texto, 'Ritmo 5:32 /km');
    });

    test('intervalos corriendo, con y sin límite', () {
      const e = EstadoModo(
        fase: FaseModo.corriendo,
        repeticion: 3,
        tiempoTramoS: 41,
        ritmoTramoSKm: 290,
      );
      final t = textoNotificacion(
        _estado(modo: const ModoIntervalos(), estadoModo: e),
      )!;
      expect(t.titulo, 'Rep. 3 de 8 · 00:41');
      expect(t.texto, '3,25 km · Ritmo del tramo 4:50 /km');
      final sin = textoNotificacion(
        _estado(modo: const ModoIntervalos(repeticiones: null), estadoModo: e),
      )!;
      expect(sin.titulo, 'Rep. 3 · 00:41');
    });

    test('descansando por tiempo y por metros', () {
      const e = EstadoModo(
        fase: FaseModo.descansando,
        repeticion: 3,
        restanteDescanso: 44.2,
      );
      final t = textoNotificacion(
        _estado(
          fase: FaseGrabacion.pausada,
          modo: const ModoIntervalos(),
          estadoModo: e,
        ),
      )!;
      expect(t.titulo, 'Descanso 0:45 · Rep. 3 de 8');
      expect(t.texto, '3,25 km');
      final m = textoNotificacion(
        _estado(
          fase: FaseGrabacion.pausada,
          modo: const ModoIntervalos(
            descansoMedida: Medida.distancia,
            descanso: 100,
          ),
          estadoModo: const EstadoModo(
            fase: FaseModo.descansando,
            repeticion: 1,
            restanteDescanso: 40,
          ),
        ),
      )!;
      expect(m.titulo, 'Descanso 40 m · Rep. 1 de 8');
    });

    test('meta por distancia y por tiempo', () {
      final d = textoNotificacion(
        _estado(
          modo: const ModoMeta(valor: 10000),
          estadoModo: const EstadoModo(
            fase: FaseModo.corriendo,
            progreso: 3200,
            objetivo: 10000,
          ),
        ),
      )!;
      expect(d.titulo, '3,2 / 10 km · 00:23:41');
      expect(d.texto, 'Ritmo 5:32 /km');
      final t = textoNotificacion(
        _estado(
          modo: const ModoMeta(medida: Medida.tiempo, valor: 1800),
          estadoModo: const EstadoModo(
            fase: FaseModo.corriendo,
            progreso: 750,
            objetivo: 1800,
          ),
        ),
      )!;
      expect(t.titulo, '12:30 / 30:00');
    });

    test('en pausa, en cualquier modo', () {
      final t = textoNotificacion(_estado(fase: FaseGrabacion.pausada))!;
      expect(t.titulo, 'En pausa · 00:23:41');
      expect(t.texto, '3,25 km');
    });

    test('sin actividad en curso no hay texto', () {
      for (final f in [
        FaseGrabacion.inactivo,
        FaseGrabacion.preparando,
        FaseGrabacion.terminada,
      ]) {
        expect(textoNotificacion(_estado(fase: f)), isNull);
      }
    });
  });

  group('frecuencia de actualización', () {
    late ProviderContainer c;
    late _Control control;
    late _Anota nota;
    late DateTime reloj;

    setUp(() {
      control = _Control();
      nota = _Anota();
      reloj = DateTime.utc(2026, 1, 1, 8);
      c = ProviderContainer(
        overrides: [
          grabacionProvider.overrideWith(() => control),
          notificadorProvider.overrideWithValue(nota),
          relojProvider.overrideWithValue(() => reloj),
        ],
      );
      c.listen(notificacionVivaProvider, (_, _) {});
      c.read(grabacionProvider);
    });
    tearDown(() => c.dispose());

    void tick(int s, {FaseGrabacion fase = FaseGrabacion.grabando}) {
      reloj = DateTime.utc(2026, 1, 1, 8).add(Duration(seconds: s));
      control.poner(_estado(fase: fase, tiempoS: s));
    }

    test('como mucho cada 3 s', () {
      for (var s = 0; s <= 7; s++) {
        tick(s);
      }
      // En los segundos 0, 3 y 6.
      expect(nota.llamadas.length, 3);
      expect(nota.llamadas.first, startsWith('00:00:00'));
    });

    test('al cambiar de fase o pausar actualiza de inmediato', () {
      tick(0);
      tick(1, fase: FaseGrabacion.pausada);
      expect(nota.llamadas.length, 2);
      expect(nota.llamadas.last, startsWith('En pausa'));
      tick(2);
      expect(nota.llamadas.length, 3);
    });

    test('un texto idéntico no se repite', () {
      tick(0);
      reloj = reloj.add(const Duration(seconds: 10));
      control.poner(_estado(tiempoS: 0));
      expect(nota.llamadas.length, 1);
    });

    test('preparando, inactivo y terminada no notifican', () {
      tick(0, fase: FaseGrabacion.preparando);
      tick(5, fase: FaseGrabacion.terminada);
      tick(9, fase: FaseGrabacion.inactivo);
      expect(nota.llamadas, isEmpty);
    });
  });
}
