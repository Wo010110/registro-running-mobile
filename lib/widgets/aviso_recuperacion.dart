import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/carreras_db.dart';
import '../providers/grabacion_provider.dart';
import '../screens/actividad_screen.dart';
import '../screens/resumen_screen.dart';
import 'dialogo_hey.dart';

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
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ActividadScreen()),
        );
        return;
      case _Opcion.terminar:
        await notifier.terminarPendiente(pendiente);
        if (!context.mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ResumenScreen()));
        return;
      case _Opcion.descartar:
        final seguro = await confirmarHey(
          context,
          titulo: '¿Descartar la actividad?',
          mensaje: 'Se borrará del teléfono y no se podrá recuperar.',
          confirmar: 'Descartar',
          cancelar: 'Cancelar',
          destructivo: true,
        );
        if (seguro) {
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
    final inicio = DateFormat(
      "d 'de' MMMM, HH:mm",
      'es',
    ).format(carrera.inicioUtc.toLocal());
    return DialogoHey(
      titulo: 'Tienes una actividad sin terminar',
      mensaje: '${carrera.tipo.etiqueta} · $inicio',
      acciones: [
        BotonDialogo(
          'Continuar',
          onPressed: () => Navigator.of(context).pop(_Opcion.continuar),
        ),
        BotonDialogo(
          'Terminar y guardar',
          secundario: true,
          onPressed: () => Navigator.of(context).pop(_Opcion.terminar),
        ),
        BotonDialogo(
          'Descartar',
          secundario: true,
          destructivo: true,
          onPressed: () => Navigator.of(context).pop(_Opcion.descartar),
        ),
      ],
    );
  }
}
