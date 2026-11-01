/// Cómo se sintió la actividad, de 1 a 5.
enum Intensidad {
  muySuave('Muy suave', 'Podías conversar sin esfuerzo'),
  suave('Suave', 'Respiración cómoda'),
  moderada('Moderada', 'Podías hablar a ratos'),
  dura('Dura', 'Solo frases cortas'),
  maxima('Máxima', 'No podías hablar');

  const Intensidad(this.nombre, this.explicacion);

  final String nombre;
  final String explicacion;

  /// Valor guardado en la base (1 a 5).
  int get nivel => index + 1;

  /// null si no hay nivel o está fuera de rango.
  static Intensidad? desdeNivel(int? nivel) =>
      nivel == null || nivel < 1 || nivel > values.length
      ? null
      : values[nivel - 1];
}
