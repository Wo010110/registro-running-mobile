import 'package:geolocator/geolocator.dart';

import 'carrera_calculos.dart';

/// De dónde llegan las posiciones; en pruebas se sustituye por una falsa.
abstract interface class FuentePosiciones {
  /// [conServicio]: con servicio en primer plano (grabando); sin él solo se
  /// escucha mientras la pantalla está abierta (preparando).
  Stream<PuntoGps> escuchar({required bool conServicio});

  /// Cambios del interruptor de ubicación del teléfono (true = encendido).
  Stream<bool> servicioHabilitado();
}

/// Configuración validada en el KM7 con la pantalla apagada (30 min sin
/// huecos > 10 s).
class FuenteGeolocator implements FuentePosiciones {
  const FuenteGeolocator();

  @override
  Stream<PuntoGps> escuchar({required bool conServicio}) {
    // shortcut: solo configura Android; iOS no está en el alcance. Mejorar al
    // publicar en iOS.
    final ajustes = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: conServicio
          ? const ForegroundNotificationConfig(
              notificationTitle: 'Hey, run!',
              notificationText: 'Grabando actividad',
              enableWakeLock: true,
            )
          : null,
    );
    return Geolocator.getPositionStream(locationSettings: ajustes).map(
      (pos) => PuntoGps(
        lat: pos.latitude,
        lng: pos.longitude,
        altitud: pos.altitude,
        precisionM: pos.accuracy,
        velocidad: pos.speed,
        instante: pos.timestamp,
      ),
    );
  }

  @override
  Stream<bool> servicioHabilitado() => Geolocator.getServiceStatusStream().map(
    (estado) => estado == ServiceStatus.enabled,
  );
}
