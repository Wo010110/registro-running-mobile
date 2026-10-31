import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';

/// Contenedor base de las pantallas: superficie con borde suave.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Título de sección con texto opcional a la derecha.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final String? accion;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            texto,
            style: TextStyle(
              color: c.textoPrincipal,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (accion != null)
            Text(
              accion!,
              style: TextStyle(color: c.primario, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// Ícono dentro de un círculo con el tinte del primario.
class IconoCirculo extends StatelessWidget {
  const IconoCirculo({
    super.key,
    required this.icono,
    this.color,
    this.tam = 44,
  });

  final List<List<dynamic>> icono;
  final Color? color;
  final double tam;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(color: c.primarioSuave, shape: BoxShape.circle),
      child: Center(
        child: HugeIcon(
          icon: icono,
          color: color ?? c.primario,
          size: tam * .5,
        ),
      ),
    );
  }
}
