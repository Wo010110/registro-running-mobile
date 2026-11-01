// shortcut: toda la clasificatoria (participantes, sus km y puntos) es de
// ejemplo hasta que exista la nube; entonces viene de la API y este archivo
// desaparece. Solo tus km son reales (base local).
import '../models/clasificatoria.dart';

/// Tus puntos de retos de ejemplo (bonificación).
const tusPuntosEjemplo = 120;

class _Participante {
  const _Participante(
    this.nombre,
    this.deMiCiudad,
    this.semana,
    this.mes,
    this.historico,
    this.puntos,
  );

  final String nombre;
  final bool deMiCiudad;
  final double semana;
  final double mes;
  final double historico;
  final int puntos;
}

const _participantes = <_Participante>[
  _Participante('Camila R.', true, 54.2, 212.0, 2380, 410),
  _Participante('Andrés M.', false, 48.9, 190.5, 2105, 330),
  _Participante('Valentina P.', true, 41.0, 176.3, 1710, 280),
  _Participante('Sebastián L.', false, 36.4, 150.2, 1544, 260),
  _Participante('Daniela G.', true, 31.8, 133.0, 1290, 240),
  _Participante('Mateo S.', true, 27.5, 118.7, 980, 190),
  _Participante('Lucía F.', false, 24.1, 101.4, 905, 170),
  _Participante('Santiago V.', true, 19.6, 84.0, 760, 150),
  _Participante('Isabella T.', false, 15.3, 70.9, 612, 90),
  _Participante('Nicolás C.', true, 11.8, 55.2, 430, 60),
  _Participante('Sofía H.', false, 8.4, 39.6, 318, 40),
  _Participante('Diego A.', true, 4.9, 22.1, 150, 20),
];

/// Clasificación de ejemplo con tu fila entre los demás según [tusKm].
List<FilaClasificatoria> clasificatoriaEjemplo({
  required AlcanceClasificatoria alcance,
  required PeriodoClasificatoria periodo,
  required String tuNombre,
  required double tusKm,
}) {
  double km(_Participante p) => switch (periodo) {
    PeriodoClasificatoria.semana => p.semana,
    PeriodoClasificatoria.mes => p.mes,
    PeriodoClasificatoria.historico => p.historico,
  };
  final filas = <(String, double, int, bool)>[
    for (final p in _participantes)
      if (alcance == AlcanceClasificatoria.global || p.deMiCiudad)
        (p.nombre, km(p), p.puntos, false),
    (tuNombre, tusKm, tusPuntosEjemplo, true),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return [
    for (var i = 0; i < filas.length; i++)
      FilaClasificatoria(
        posicion: i + 1,
        nombre: filas[i].$1,
        km: filas[i].$2,
        puntos: filas[i].$3,
        esTu: filas[i].$4,
      ),
  ];
}
