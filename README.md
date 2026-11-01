# Hey, run! (app móvil)

App Flutter (Android/iOS) del registro de carreras. Paquete Android `com.heyrun.mobile`.
Esta versión es la base: inicio de sesión, registro, tema claro/oscuro y un inicio provisional.

## Correr en el KM7

1. Levanta el backend con su `run.ps1` (`registro-running-backend`, puerto 8000).
2. La laptop y el teléfono deben estar en la misma wifi.
3. Si el teléfono no llega a la API, permite el puerto 8000 en el firewall de Windows
   (regla de entrada TCP, puerto 8000, perfil Privado). Esa regla la creas tú.
4. Desde esta carpeta, en PowerShell:

```
.\run.ps1
```

Para medir el rendimiento real (fluidez del mapa, zoom, inicio de la actividad) usa el modo
profile, porque en debug todo va más lento:

```
.un.ps1 -Profile
```

En profile no hay hot reload. Lo demás es igual.

El script detecta la IP de la laptop y lanza `flutter run` con
`--dart-define=API_URL=http://<ip>:8000`. `GOOGLE_SERVER_CLIENT_ID` va vacío por ahora:
el botón de Google avisa que no está configurado.

## Tonos de aviso

Los avisos de los modos (correr, descanso, meta) son tonos suaves generados por código en
`assets/sonidos/`. Para cambiarlos, edita `tool/generar_tonos.dart` y ejecuta
`dart run tool/generar_tonos.dart`.

## Pruebas

```
flutter analyze
flutter test
```

## Reglas del proyecto

- Ningún archivo fuera de `lib/theme/` escribe un hex ni `Colors.xxx`: todo sale de `AppColors`
  (lo vigila `test/colores_test.dart`).
- HTTP en claro solo está permitido en el manifest de debug; release exige HTTPS.
- El ícono y el splash son provisionales (`assets/icon/`).
