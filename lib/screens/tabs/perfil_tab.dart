import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/datos_ejemplo.dart';
import '../../debug/prueba_gps_screen.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/tarjeta.dart';
import '../settings_screen.dart';

class PerfilTab extends ConsumerWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final user = ref.watch(authProvider).user;
    final nombre = user?.displayName ?? '';
    final inicial = nombre.isEmpty
        ? '?'
        : nombre.characters.first.toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.primarioSuave,
                  border: Border.all(color: c.primario, width: 3),
                ),
                child: Center(
                  child: Text(
                    inicial,
                    style: TextStyle(
                      color: c.primario,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                nombre,
                style: TextStyle(
                  color: c.textoPrincipal,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (user != null)
                Text(
                  user.email,
                  style: TextStyle(color: c.textoTenue, fontSize: 14),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Tarjeta(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              _Cifra('Actividades', '24'),
              _Cifra('Kilómetros', '168'),
              _Cifra('Amigos', '0'),
            ],
          ),
        ),
        const TituloSeccion('Récords personales'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.9,
          children: [
            for (final (distancia, tiempo) in recordsEjemplo)
              Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedTrophy,
                          color: tiempo == null
                              ? c.textoDeshabilitado
                              : c.medalla,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          distancia,
                          style: TextStyle(color: c.textoTenue, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tiempo ?? '—',
                      style: TextStyle(
                        color: tiempo == null
                            ? c.textoDeshabilitado
                            : c.textoPrincipal,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const TituloSeccion('Cuenta'),
        Tarjeta(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Fila(
                icono: HugeIcons.strokeRoundedSettings01,
                texto: 'Ajustes',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              if (kDebugMode) ...[
                Divider(height: 1, color: c.divisor),
                _Fila(
                  icono: HugeIcons.strokeRoundedLocation01,
                  texto: 'Prueba GPS',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PruebaGpsScreen(),
                    ),
                  ),
                ),
              ],
              Divider(height: 1, color: c.divisor),
              _Fila(
                icono: HugeIcons.strokeRoundedLogout01,
                texto: 'Cerrar sesión',
                destructiva: true,
                onTap: ref.read(authProvider.notifier).cerrarSesion,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              color: c.textoPrincipal,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(etiqueta, style: TextStyle(color: c.textoTenue, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.destructiva = false,
  });

  final List<List<dynamic>> icono;
  final String texto;
  final VoidCallback onTap;
  final bool destructiva;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = destructiva ? c.errorTexto : c.textoPrincipal;
    return ListTile(
      onTap: onTap,
      leading: HugeIcon(icon: icono, color: color, size: 22),
      title: Text(texto, style: TextStyle(color: color)),
      trailing: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        color: c.textoDeshabilitado,
        size: 18,
      ),
    );
  }
}
