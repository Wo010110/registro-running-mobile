import 'package:intl/intl.dart';

import '../core/carrera_calculos.dart';
import '../models/tipo_actividad.dart';

/// Huecos mayores que esto (s) entre puntos consecutivos se listan.
const huecoInformeS = 10;

class InformeGps {
  const InformeGps({
    required this.tipo,
    required this.total,
    required this.precisionMediaM,
    required this.mayorHuecoS,
    required this.huecos,
  });

  final TipoActividad tipo;
  final int total;
  final double precisionMediaM;
  final int mayorHuecoS;
  final List<({DateTime inicio, int duracionS})> huecos;

  String comoTexto() {
    final hora = DateFormat('HH:mm:ss');
    final b = StringBuffer()
      ..writeln('Tipo: ${tipo.etiqueta}')
      ..writeln('Puntos: $total')
      ..writeln('Precisión media: ${precisionMediaM.toStringAsFixed(1)} m')
      ..writeln('Mayor hueco: $mayorHuecoS s')
      ..writeln('Huecos > $huecoInformeS s: ${huecos.length}');
    for (final h in huecos) {
      b.writeln('  ${hora.format(h.inicio.toLocal())}  ${h.duracionS} s');
    }
    return b.toString().trimRight();
  }
}

InformeGps construirInforme(TipoActividad tipo, List<PuntoGps> puntos) {
  var suma = 0.0;
  var mayor = 0;
  final huecos = <({DateTime inicio, int duracionS})>[];
  for (var i = 0; i < puntos.length; i++) {
    suma += puntos[i].precisionM;
    if (i == 0) continue;
    final s = puntos[i].instante.difference(puntos[i - 1].instante).inSeconds;
    if (s > mayor) mayor = s;
    if (s > huecoInformeS) {
      huecos.add((inicio: puntos[i - 1].instante, duracionS: s));
    }
  }
  return InformeGps(
    tipo: tipo,
    total: puntos.length,
    precisionMediaM: puntos.isEmpty ? 0 : suma / puntos.length,
    mayorHuecoS: mayor,
    huecos: huecos,
  );
}
