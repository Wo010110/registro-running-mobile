// shortcut: datos de ejemplo SOLO para ver el diseño. Cada pantalla que use
// esto se conecta a la base local / API cuando exista su función y este
// archivo desaparece.

// shortcut: seguidores y seguidos de ejemplo (y las medallas de abajo en el
// Perfil) hasta que exista la nube; entonces vienen de la API.
const seguidoresEjemplo = 128;
const siguiendoEjemplo = 96;

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
