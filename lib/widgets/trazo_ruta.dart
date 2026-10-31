import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dibujo esquemático de una ruta. Es solo decorativo mientras no hay mapa.
class TrazoRuta extends StatelessWidget {
  const TrazoRuta({super.key, required this.puntos, this.alto = 120});

  final List<(double, double)> puntos;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: c.primarioSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          size: Size.infinite,
          painter: _PintorTrazo(
            puntos: puntos,
            linea: c.primario,
            inicio: c.exito,
            fin: c.textoPrincipal,
            rejilla: c.borde,
          ),
        ),
      ),
    );
  }
}

class _PintorTrazo extends CustomPainter {
  _PintorTrazo({
    required this.puntos,
    required this.linea,
    required this.inicio,
    required this.fin,
    required this.rejilla,
  });

  final List<(double, double)> puntos;
  final Color linea;
  final Color inicio;
  final Color fin;
  final Color rejilla;

  @override
  void paint(Canvas canvas, Size size) {
    final fina = Paint()
      ..color = rejilla.withValues(alpha: .5)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(size.width * i / 4, 0),
        Offset(size.width * i / 4, size.height),
        fina,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        fina,
      );
    }
    if (puntos.length < 2) return;
    Offset p((double, double) q) => Offset(
      size.width * (.08 + .84 * q.$1),
      size.height * (.12 + .76 * q.$2),
    );
    final ruta = Path()..moveTo(p(puntos.first).dx, p(puntos.first).dy);
    for (var i = 1; i < puntos.length; i++) {
      final a = p(puntos[i - 1]);
      final b = p(puntos[i]);
      ruta.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    }
    ruta.lineTo(p(puntos.last).dx, p(puntos.last).dy);
    canvas.drawPath(
      ruta,
      Paint()
        ..color = linea
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(p(puntos.first), 6, Paint()..color = inicio);
    canvas.drawCircle(p(puntos.last), 6, Paint()..color = fin);
  }

  @override
  bool shouldRepaint(_PintorTrazo old) =>
      old.puntos != puntos || old.linea != linea;
}
