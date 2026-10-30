import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/theme/app_colors.dart';

void main() {
  test('el tema claro y el oscuro tienen fondos distintos', () {
    expect(AppColors.claro.fondo, isNot(AppColors.oscuro.fondo));
    expect(AppColors.oscuro.fondo, const Color(0xFF0B0F14));
    expect(AppColors.claro.fondo, const Color(0xFFF5F5F7));
  });

  testWidgets('of(context) sigue el brillo del tema', (tester) async {
    for (final brillo in Brightness.values) {
      late AppColors obtenida;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brillo),
          home: Builder(
            builder: (context) {
              obtenida = AppColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        obtenida,
        brillo == Brightness.dark ? AppColors.oscuro : AppColors.claro,
      );
    }
  });

  test('ningún archivo de lib/ fuera de theme/ escribe colores sueltos', () {
    final literal = RegExp(r'Color\(0x|(?<![A-Za-z])Colors\.(?!transparent)');
    final infractores = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.replaceAll('\\', '/').contains('lib/theme/')) continue;
      if (literal.hasMatch(f.readAsStringSync())) infractores.add(f.path);
    }
    expect(infractores, isEmpty);
  });
}
