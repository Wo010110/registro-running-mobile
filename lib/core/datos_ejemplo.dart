// shortcut: datos de ejemplo SOLO para ver el diseño. Cada pantalla que use
// esto se conecta a la base local / API cuando exista su función y este
// archivo desaparece.

/// Distancia y mejor tiempo (null = aún sin récord).
const recordsEjemplo = <(String, String?)>[
  ('1 km', '06:10'),
  ('5 km', '33:45'),
  ('10 km', '01:25:40'),
  ('21 km', null),
  ('42 km', null),
  ('100 km', null),
];

class RetoEjemplo {
  const RetoEjemplo(this.titulo, this.detalle, this.progreso, this.meta);

  final String titulo;
  final String detalle;
  final double progreso;
  final String meta;
}

const retosEjemplo = [
  RetoEjemplo('50 km en noviembre', 'Meta mensual', 0.42, '21 / 50 km'),
  RetoEjemplo('10K sin parar', 'Reto personal', 0.0, 'Sin empezar'),
  RetoEjemplo('Madrugador', 'Salir antes de las 7:00', 0.6, '3 / 5 salidas'),
];

class MedallaEjemplo {
  const MedallaEjemplo(this.nombre, this.ganada);

  final String nombre;
  final bool ganada;
}

const medallasEjemplo = [
  MedallaEjemplo('Primera salida', true),
  MedallaEjemplo('Primer 5K', true),
  MedallaEjemplo('Primer 10K', true),
  MedallaEjemplo('Racha de 7 días', false),
  MedallaEjemplo('100 km', false),
  MedallaEjemplo('Media maratón', false),
];
