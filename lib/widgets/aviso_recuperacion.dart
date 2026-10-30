import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/carreras_db.dart';
import '../providers/grabacion_provider.dart';
import '../screens/grabando_screen.dart';
import '../screens/resumen_screen.dart';
import '../theme/app_colors.dart';

enum _Opcion { continuar, terminar, descartar }

/// Si la app se cerró con una actividad a medias, ofrece qué hacer con ella.
Future<void> avisarActividadPendiente(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(grabacionProvider.notifier);
  final pendiente = await notifier.carreraPendiente();
  if (pendiente == null || !context.mounted) return;
  while (true) {
    if (!context.mounted) return;
    final opcion = await showDialog<_Opcion>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Aviso(pendiente),
    );
    if (opcion == null || !context.mounted) return;
    switch (opcion) {
      case _Opcion.continuar:
        await notifier.continuar(pendiente);
        if (!context.mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const GrabandoScreen()));
        return;
      case _Opcion.terminar:
        await notifier.terminarPendiente(pendiente);
        if (!context.mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ResumenScreen()));
        return;
      case _Opcion.descartar:
        final seguro = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('¿Descartar la actividad?'),
            content: const Text(
              'Se borrará del teléfono y no se podrá recuperar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (seguro ?? false) {
          await notifier.descartarPendiente(pendiente);
          return;
        }
        if (!context.mounted) return;
    }
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.carrera);

  final CarreraLocal carrera;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final inicio = DateFormat(
      "d 'de' MMMM, HH:mm",
      'es',
    ).format(carrera.inicioUtc.toLocal());
    return AlertDialog(
      title: const Text('Tienes una actividad sin terminar'),
      content: Text('${carrera.tipo.etiqueta} · $inicio'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Opcion.descartar),
          child: Text('Descartar', style: TextStyle(color: c.errorTexto)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Opcion.terminar),
          child: const Text('Terminar y guardar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_Opcion.continuar),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
