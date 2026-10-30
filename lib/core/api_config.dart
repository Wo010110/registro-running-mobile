/// URL base de la API (`--dart-define=API_URL=http://<ip>:8000`).
const String apiUrl = String.fromEnvironment('API_URL');

/// Llave de MapTiler (`--dart-define=MAPTILER_KEY=`). Vacía = mapa de OSM.
const String mapTilerKey = String.fromEnvironment('MAPTILER_KEY');

/// Client ID de servidor de Google (`--dart-define=GOOGLE_SERVER_CLIENT_ID=`).
/// Vacío = el botón de Google avisa que no está configurado.
const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
);
