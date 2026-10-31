// shortcut: datos de ejemplo SOLO para ver el diseño. Cada pantalla que use
// esto se conecta a la base local / API cuando exista su función y este
// archivo desaparece.
import '../models/tipo_actividad.dart';

class ActividadEjemplo {
  const ActividadEjemplo({
    required this.tipo,
    required this.titulo,
    required this.fecha,
    required this.km,
    required this.tiempo,
    required this.ritmo,
    required this.trazo,
  });

  final TipoActividad tipo;
  final String titulo;
  final String fecha;
  final String km;
  final String tiempo;
  final String ritmo;

  /// Puntos del dibujo de la ruta, de 0 a 1 en cada eje.
  final List<(double, double)> trazo;
}

const actividadesEjemplo = [
  ActividadEjemplo(
    tipo: TipoActividad.correr,
    titulo: 'Rodaje de la mañana',
    fecha: 'Hoy · 6:12',
    km: '6,42',
    tiempo: '00:52:10',
    ritmo: '8:07',
    trazo: [(.08, .7), (.2, .4), (.4, .3), (.55, .55), (.7, .25), (.9, .35)],
  ),
  ActividadEjemplo(
    tipo: TipoActividad.caminar,
    titulo: 'Paseo de la tarde',
    fecha: 'Ayer · 18:30',
    km: '3,10',
    tiempo: '00:41:05',
    ritmo: '13:15',
    trazo: [(.1, .3), (.3, .2), (.5, .5), (.35, .75), (.7, .8), (.9, .55)],
  ),
  ActividadEjemplo(
    tipo: TipoActividad.correr,
    titulo: 'Fondo del domingo',
    fecha: 'Dom 25 oct · 7:00',
    km: '10,01',
    tiempo: '01:25:40',
    ritmo: '8:33',
    trazo: [(.1, .6), (.15, .25), (.45, .15), (.8, .3), (.85, .7), (.5, .85)],
  ),
  ActividadEjemplo(
    tipo: TipoActividad.correr,
    titulo: 'Series cortas',
    fecha: 'Mié 21 oct · 6:05',
    km: '4,80',
    tiempo: '00:38:22',
    ritmo: '7:59',
    trazo: [(.1, .5), (.3, .3), (.5, .5), (.7, .3), (.9, .5)],
  ),
];

/// Kilómetros de lunes a domingo.
const semanaEjemplo = [4.2, 0.0, 6.4, 3.1, 0.0, 10.0, 0.0];
const diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

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
