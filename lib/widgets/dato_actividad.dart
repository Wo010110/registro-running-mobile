import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Valor con su etiqueta, para repartir en una fila. [unidad] va más pequeña
/// y tenue a continuación del valor.
class DatoActividad extends StatelessWidget {
  const DatoActividad(this.etiqueta, this.valor, {super.key, this.unidad});

  final String etiqueta;
  final String valor;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      // El aire entre columnas: 6 px a cada lado.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            // Altura fija: un valor que se encoge no desalinea las columnas.
            SizedBox(
              height: 30,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    text: valor,
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      if (unidad != null)
                        TextSpan(
                          text: ' $unidad',
                          style: TextStyle(
                            color: c.textoTenue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 16,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  style: TextStyle(
                    color: c.textoTenue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
