import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogo con el estilo de la app: contenedor redondeado, título firme y
/// botones en píldora apilados.
class DialogoHey extends StatelessWidget {
  const DialogoHey({
    super.key,
    required this.titulo,
    this.mensaje,
    required this.acciones,
  });

  final String titulo;
  final String? mensaje;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 24,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: 10),
              Text(
                mensaje!,
                style: TextStyle(
                  color: c.textoSecundario,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 24),
            for (var i = 0; i < acciones.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              acciones[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón principal en píldora para [DialogoHey].
class BotonDialogo extends StatelessWidget {
  const BotonDialogo(
    this.texto, {
    super.key,
    required this.onPressed,
    this.destructivo = false,
    this.secundario = false,
  });

  final String texto;
  final VoidCallback onPressed;
  final bool destructivo;
  final bool secundario;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const forma = StadiumBorder();
    const tam = Size.fromHeight(50);
    final estilo = const TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
    if (secundario) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: tam,
          shape: forma,
          foregroundColor: destructivo ? c.errorTexto : c.textoPrincipal,
          side: BorderSide(color: destructivo ? c.error : c.borde),
          textStyle: estilo,
        ),
        child: Text(texto),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: tam,
        shape: forma,
        backgroundColor: destructivo ? c.error : c.accion,
        foregroundColor: c.sobreAccion,
        textStyle: estilo,
      ),
      child: Text(texto),
    );
  }
}

/// Pregunta de sí o no. Devuelve true si se confirma.
Future<bool> confirmarHey(
  BuildContext context, {
  required String titulo,
  String? mensaje,
  required String confirmar,
  required String cancelar,
  bool destructivo = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => DialogoHey(
      titulo: titulo,
      mensaje: mensaje,
      acciones: [
        BotonDialogo(
          confirmar,
          destructivo: destructivo,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        BotonDialogo(
          cancelar,
          secundario: true,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
  return r ?? false;
}
