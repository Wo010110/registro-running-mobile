import 'package:flutter/services.dart';

/// Cómo se actualiza el texto de la notificación del servicio de GPS; en
/// pruebas se sustituye por uno que anota.
abstract interface class NotificadorGrabacion {
  Future<void> actualizar(String titulo, String texto);
}

/// Reescribe la notificación que ya publica el servicio en primer plano de
/// geolocator (ver `NotificacionGrabacion.kt`). Un fallo del canal se ignora:
/// la notificación sigue con su texto de arranque y la grabación no se afecta.
class NotificadorAndroid implements NotificadorGrabacion {
  static const _canal = MethodChannel('com.heyrun.mobile/notificacion');

  @override
  Future<void> actualizar(String titulo, String texto) async {
    try {
      await _canal.invokeMethod<bool>('actualizar', {
        'titulo': titulo,
        'texto': texto,
      });
    } catch (_) {}
  }
}
