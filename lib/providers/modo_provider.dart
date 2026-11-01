import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modo_actividad.dart';
import 'theme_provider.dart';

const _kModo = 'modo_ultimo';
const _kIntervalos = 'modo_intervalos';
const _kMeta = 'modo_meta';

/// Modo elegido en la pantalla de preparar y la última configuración de cada
/// modo; todo se recuerda entre sesiones.
class SeleccionModo {
  const SeleccionModo({
    this.tipo = TipoModo.libre,
    this.intervalos = const ModoIntervalos(),
    this.meta = const ModoMeta(),
  });

  final TipoModo tipo;
  final ModoIntervalos intervalos;
  final ModoMeta meta;

  ModoActividad get modo => switch (tipo) {
    TipoModo.libre => const ModoLibre(),
    TipoModo.intervalos => intervalos,
    TipoModo.meta => meta,
  };
}

class SeleccionModoNotifier extends Notifier<SeleccionModo> {
  @override
  SeleccionModo build() {
    final prefs = ref.read(prefsProvider);
    // Un texto guardado que no se entiende deja la configuración por defecto.
    final intervalos = ModoActividad.desdeTexto(prefs.getString(_kIntervalos));
    final meta = ModoActividad.desdeTexto(prefs.getString(_kMeta));
    return SeleccionModo(
      tipo: TipoModo.values.firstWhere(
        (t) => t.name == prefs.getString(_kModo),
        orElse: () => TipoModo.libre,
      ),
      intervalos: intervalos is ModoIntervalos
          ? intervalos
          : const ModoIntervalos(),
      meta: meta is ModoMeta ? meta : const ModoMeta(),
    );
  }

  Future<void> elegir(TipoModo tipo) async {
    state = SeleccionModo(
      tipo: tipo,
      intervalos: state.intervalos,
      meta: state.meta,
    );
    await ref.read(prefsProvider).setString(_kModo, tipo.name);
  }

  Future<void> guardarIntervalos(ModoIntervalos intervalos) async {
    state = SeleccionModo(
      tipo: state.tipo,
      intervalos: intervalos,
      meta: state.meta,
    );
    await ref.read(prefsProvider).setString(_kIntervalos, intervalos.aTexto()!);
  }

  Future<void> guardarMeta(ModoMeta meta) async {
    state = SeleccionModo(
      tipo: state.tipo,
      intervalos: state.intervalos,
      meta: meta,
    );
    await ref.read(prefsProvider).setString(_kMeta, meta.aTexto()!);
  }
}

final seleccionModoProvider =
    NotifierProvider<SeleccionModoNotifier, SeleccionModo>(
      SeleccionModoNotifier.new,
    );
