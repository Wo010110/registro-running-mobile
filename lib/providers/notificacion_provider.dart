import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../core/motor_modos.dart';
import '../core/notificacion_grabacion.dart';
import '../models/modo_actividad.dart';
import 'grabacion_provider.dart';

final notificadorProvider = Provider<NotificadorGrabacion>(
  (ref) => NotificadorAndroid(),
);

/// Segundos mínimos entre dos actualizaciones del texto (salvo cambio de fase).
const _esperaNotificacionS = 3;

String _mmss(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

String _rep(EstadoModo e, ModoIntervalos modo) => modo.repeticiones == null
    ? 'Rep. ${e.repeticion}'
    : 'Rep. ${e.repeticion} de ${modo.repeticiones}';

/// Texto de la notificación según el estado de la grabación; null si no hay
/// actividad en curso (preparando, inactivo, terminada).
({String titulo, String texto})? textoNotificacion(GrabacionState g) {
  if (!g.enCurso) return null;
  final km = formatearKm(g.distanciaM);
  final total = formatearTiempo(g.tiempoTotalS);
  final e = g.estadoModo;
  final modo = g.modo;

  if (modo is ModoIntervalos && e != null && e.fase == FaseModo.descansando) {
    final resto = modo.descansoMedida == Medida.tiempo
        ? formatearMinSeg(e.restanteDescanso.ceil())
        : '${e.restanteDescanso.ceil()} m';
    return (titulo: 'Descanso $resto · ${_rep(e, modo)}', texto: '$km km');
  }
  if (g.fase == FaseGrabacion.pausada) {
    return (titulo: 'En pausa · $total', texto: '$km km');
  }
  if (modo is ModoIntervalos && e != null && e.fase == FaseModo.corriendo) {
    return (
      titulo: '${_rep(e, modo)} · ${_mmss(e.tiempoTramoS)}',
      texto: '$km km · Ritmo del tramo ${formatearRitmo(e.ritmoTramoSKm)} /km',
    );
  }
  final ritmo = 'Ritmo ${formatearRitmo(g.ritmoActualSKm)} /km';
  if (modo is ModoMeta && e != null) {
    final avance = modo.medida == Medida.distancia
        ? '${formatearKmUno(e.progreso / 1000)} / '
              '${formatearDistanciaCorta(e.objetivo.round())} · $total'
        : '${formatearMinSeg(e.progreso.floor())} / '
              '${formatearMinSeg(e.objetivo.round())}';
    return (titulo: avance, texto: ritmo);
  }
  return (titulo: '$total · $km km', texto: ritmo);
}

/// Mientras esté activo (lo mira la pantalla principal) reescribe el texto de
/// la notificación del servicio de GPS: cada 3 s como mucho y al momento si
/// cambia la fase o la pausa.
final notificacionVivaProvider = Provider<void>((ref) {
  final notificador = ref.read(notificadorProvider);
  final reloj = ref.read(relojProvider);
  var ultima = DateTime.fromMillisecondsSinceEpoch(0);
  String? clave;
  String? ultimoTexto;
  ref.listen(grabacionProvider, (_, g) {
    final t = textoNotificacion(g);
    if (t == null || g.ocupado) {
      clave = null;
      ultimoTexto = null;
      return;
    }
    final ahora = reloj();
    final nuevaClave = '${g.fase.name}/${g.estadoModo?.fase.name}';
    final cambioFase = nuevaClave != clave;
    if (!cambioFase &&
        ahora.difference(ultima).inSeconds < _esperaNotificacionS) {
      return;
    }
    final texto = '${t.titulo}\n${t.texto}';
    if (texto == ultimoTexto) return;
    clave = nuevaClave;
    ultima = ahora;
    ultimoTexto = texto;
    notificador.actualizar(t.titulo, t.texto);
  });
});
