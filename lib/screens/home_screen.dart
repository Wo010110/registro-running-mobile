import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../debug/prueba_gps_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/aviso_recuperacion.dart';
import 'grabando_screen.dart';
import 'preparar_screen.dart';
import 'settings_screen.dart';

/// Placeholder: aquí irá el historial.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) avisarActividadPendiente(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final auth = ref.watch(authProvider);
    final enCurso = ref.watch(grabacionProvider.select((g) => g.enCurso));
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hey, run!'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSettings01,
              color: c.textoPrincipal,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (auth.sinConexion)
            Material(
              color: c.superficie,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sin conexión. Tus carreras se guardan en el teléfono.',
                        style: TextStyle(
                          color: c.textoSecundario,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: ref
                          .read(authProvider.notifier)
                          .refrescarPerfil,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hola, ${user?.displayName ?? ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textoPrincipal,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => enCurso
                                ? const GrabandoScreen()
                                : const PrepararScreen(),
                          ),
                        ),
                        icon: HugeIcon(
                          icon: enCurso
                              ? HugeIcons.strokeRoundedTimer01
                              : HugeIcons.strokeRoundedRunningShoes,
                          color: c.sobreAccion,
                        ),
                        label: Text(
                          enCurso ? 'Actividad en curso' : 'Empezar actividad',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (kDebugMode) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PruebaGpsScreen(),
                          ),
                        ),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          color: c.textoPrincipal,
                          size: 20,
                        ),
                        label: const Text('Prueba GPS'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: ref.read(authProvider.notifier).cerrarSesion,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedLogout01,
                        color: c.textoPrincipal,
                        size: 20,
                      ),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
