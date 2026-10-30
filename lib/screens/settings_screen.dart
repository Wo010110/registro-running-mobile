import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final modo = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tema', style: TextStyle(color: c.textoSecundario)),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
            ],
            selected: {modo},
            onSelectionChanged: (s) =>
                ref.read(themeProvider.notifier).cambiar(s.first),
          ),
        ],
      ),
    );
  }
}
