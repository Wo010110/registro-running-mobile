enum AlcanceClasificatoria {
  ciudad('Mi ciudad'),
  global('Global');

  const AlcanceClasificatoria(this.etiqueta);
  final String etiqueta;
}

enum PeriodoClasificatoria {
  semana('Semana'),
  mes('Mes'),
  historico('Histórico');

  const PeriodoClasificatoria(this.etiqueta);
  final String etiqueta;
}

/// Una fila de la clasificación: orden por km del período; los [puntos] de
/// retos son una bonificación que se muestra aparte.
class FilaClasificatoria {
  const FilaClasificatoria({
    required this.posicion,
    required this.nombre,
    required this.km,
    required this.puntos,
    this.esTu = false,
  });

  final int posicion;
  final String nombre;
  final double km;
  final int puntos;
  final bool esTu;
}
