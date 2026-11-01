import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

enum Aviso {
  correr([0, 150, 100, 150]),
  descanso([0, 350]),
  meta([0, 150, 80, 150, 80, 350]);

  const Aviso(this.vibracion);

  /// Patrón de vibración: espera, vibra, espera, vibra...
  final List<int> vibracion;
}

/// Cómo se avisa al usuario; en pruebas se sustituye por uno que anota.
abstract interface class Avisador {
  /// Prepara el reproductor y carga los tonos para que el primer aviso no
  /// cueste nada en plena actividad.
  Future<void> precalentar();

  Future<void> avisar(Aviso aviso);
}

/// Tono suave y vibración. El tono pide el foco de audio de forma transitoria
/// con ducking: la música baja un momento y vuelve. Suena con la pantalla
/// apagada porque la app sigue viva por el servicio en primer plano del GPS.
// shortcut: un solo reproductor; dos avisos casi a la vez se cortarían entre
// sí. Los separan segundos, mejorar si se añaden avisos que puedan solaparse.
class AvisadorSonoro implements Avisador {
  final _reproductor = AudioPlayer();
  var _configurado = false;

  Future<void> _configurar() async {
    if (_configurado) return;
    await _reproductor.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    await _reproductor.setReleaseMode(ReleaseMode.stop);
    _configurado = true;
  }

  // Un fallo de audio o de vibración nunca debe afectar a la grabación.
  @override
  Future<void> precalentar() async {
    try {
      await _configurar();
      await _reproductor.audioCache.loadAll([
        for (final a in Aviso.values) 'sonidos/${a.name}.wav',
      ]);
    } catch (_) {}
  }

  @override
  Future<void> avisar(Aviso aviso) async {
    try {
      await _configurar();
      await _reproductor.play(AssetSource('sonidos/${aviso.name}.wav'));
    } catch (_) {}
    try {
      await Vibration.vibrate(pattern: aviso.vibracion);
    } catch (_) {}
  }
}
