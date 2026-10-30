// shortcut: los récords de 1k/5k/10k/etc. (tarea futura) deben calcularse
// solo con carreras tipo correr; hoy nada los calcula.
enum TipoActividad {
  correr('correr', 'Correr'),
  caminar('caminar', 'Caminar');

  const TipoActividad(this.valor, this.etiqueta);

  /// Texto estable para guardar en la base local y en la API.
  final String valor;
  final String etiqueta;

  static TipoActividad desdeValor(String valor) =>
      values.firstWhere((t) => t.valor == valor);
}
