import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Se sobrescribe en `main` con la instancia ya cargada.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider sin sobrescribir'),
);

const _kTema = 'tema';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final guardado = ref.read(prefsProvider).getString(_kTema);
    return ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    await ref.read(prefsProvider).setString(_kTema, modo.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
