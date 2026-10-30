import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Hay sesión guardada pero no se pudo llegar al servidor al arrancar.
class SinConexion extends ConsumerWidget {
  const SinConexion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo conectar con el servidor',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textoPrincipal, fontSize: 18),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: ref.read(authProvider.notifier).reintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
