import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../providers/auth_provider.dart';
import '../providers/grabacion_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/aviso_recuperacion.dart';

import 'actividad_screen.dart';
import 'tabs/actividades_tab.dart';
import 'tabs/inicio_tab.dart';
import 'tabs/perfil_tab.dart';
import 'tabs/retos_tab.dart';

/// Pantalla principal: cuatro pestañas y el botón central para empezar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _pestana = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) avisarActividadPendiente(context, ref);
    });
  }

  void _empezar(bool enCurso) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ActividadScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sinConexion = ref.watch(authProvider.select((a) => a.sinConexion));
    final enCurso = ref.watch(grabacionProvider.select((g) => g.enCurso));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (sinConexion)
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
              child: IndexedStack(
                index: _pestana,
                children: const [
                  InicioTab(),
                  ActividadesTab(),
                  RetosTab(),
                  PerfilTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BarraInferior(
        pestana: _pestana,
        enCurso: enCurso,
        onPestana: (i) => setState(() => _pestana = i),
        onEmpezar: () => _empezar(enCurso),
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.pestana,
    required this.enCurso,
    required this.onPestana,
    required this.onEmpezar,
  });

  final int pestana;
  final bool enCurso;
  final ValueChanged<int> onPestana;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.superficie,
        border: Border(top: BorderSide(color: c.borde)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _Destino(
                'Inicio',
                HugeIcons.strokeRoundedHome01,
                pestana == 0,
                () => onPestana(0),
              ),
              _Destino(
                'Actividades',
                HugeIcons.strokeRoundedActivity01,
                pestana == 1,
                () => onPestana(1),
              ),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: enCurso ? 'Actividad en curso' : 'Empezar',
                    child: Material(
                      color: c.accion,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onEmpezar,
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(
                            child: HugeIcon(
                              icon: enCurso
                                  ? HugeIcons.strokeRoundedTimer01
                                  : HugeIcons.strokeRoundedRunningShoes,
                              color: c.sobreAccion,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _Destino(
                'Retos',
                HugeIcons.strokeRoundedTarget01,
                pestana == 2,
                () => onPestana(2),
              ),
              _Destino(
                'Perfil',
                HugeIcons.strokeRoundedUser,
                pestana == 3,
                () => onPestana(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destino extends StatelessWidget {
  const _Destino(this.etiqueta, this.icono, this.activo, this.onTap);

  final String etiqueta;
  final List<List<dynamic>> icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = activo ? c.primario : c.textoTenue;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: icono, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
