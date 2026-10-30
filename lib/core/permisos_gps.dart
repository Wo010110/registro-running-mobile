import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermisoUbicacion { concedido, gpsApagado, denegado, denegadoParaSiempre }

/// Ubicación "mientras se usa la app"; el servicio en primer plano cubre la
/// pantalla apagada, no hace falta "siempre".
Future<PermisoUbicacion> pedirUbicacion() async {
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.deniedForever) {
    return PermisoUbicacion.denegadoParaSiempre;
  }
  if (permiso == LocationPermission.denied ||
      permiso == LocationPermission.unableToDetermine) {
    return PermisoUbicacion.denegado;
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    return PermisoUbicacion.gpsApagado;
  }
  return PermisoUbicacion.concedido;
}

/// Sin este permiso (Android 13+) no se ve el aviso de actividad en curso.
Future<bool> pedirNotificaciones() async =>
    (await Permission.notification.request()).isGranted;
