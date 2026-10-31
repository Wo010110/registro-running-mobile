import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Valor grande con su etiqueta en mayúscula, para repartir en una fila.
class DatoActividad extends StatelessWidget {
  const DatoActividad(this.etiqueta, this.valor, {super.key});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta.toUpperCase(),
            style: TextStyle(
              color: c.textoTenue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
