import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'api_config.dart';
import 'token_store.dart';

/// Error de la API con mensaje ya listo para mostrar al usuario.
class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    this._tokens = const TokenStore(),
    this.baseUrl = apiUrl,
    this.alCerrarSesion,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final TokenStore _tokens;
  final String baseUrl;

  /// Se llama cuando el refresh falla y se borraron los tokens.
  final void Function()? alCerrarSesion;

  Future<bool>? _refrescando;

  // ─── Auth ──────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) => _abrirSesion(
    '/auth/login',
    {'email': email, 'password': password},
    credencialesMsg: 'Correo o contraseña incorrectos',
  );

  Future<void> register(String nombre, String email, String password) =>
      _abrirSesion('/auth/register', {
        'email': email,
        'password': password,
        'display_name': nombre,
      });

  Future<void> loginGoogle(String idToken) =>
      _abrirSesion('/auth/google', {'id_token': idToken});

  Future<void> logout() async {
    final refresh = await _tokens.refresh;
    await _tokens.borrar();
    if (refresh == null) return;
    try {
      await _enviar('POST', '/auth/logout', {'refresh_token': refresh});
    } on ApiException {
      // El token local ya se borró; si el servidor no respondió, caduca solo.
    }
  }

  Future<User> me() async {
    final r = await _autenticada('GET', '/me');
    final user = User.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    await _tokens.guardarPerfil(user);
    return user;
  }

  /// Último perfil que devolvió /me, para arrancar sin red.
  Future<User?> get perfilGuardado => _tokens.perfil;

  /// Hay tokens guardados (no valida que sigan siendo válidos).
  Future<bool> get hayTokens async => await _tokens.refresh != null;

  // ─── Internos ──────────────────────────────────────────────────────────

  Future<void> _abrirSesion(
    String ruta,
    Map<String, dynamic> body, {
    String? credencialesMsg,
  }) async {
    final r = await _enviar(
      'POST',
      ruta,
      body,
      credencialesMsg: credencialesMsg,
    );
    await _guardarTokens(r);
  }

  Future<void> _guardarTokens(http.Response r) {
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return _tokens.guardar(
      j['access_token'] as String,
      j['refresh_token'] as String,
    );
  }

  /// Petición con Bearer; ante 401 un único refresh con rotación y reintento.
  Future<http.Response> _autenticada(String metodo, String ruta) async {
    final access = await _tokens.access;
    if (access == null) throw const ApiException('Sesión expirada', 401);
    try {
      return await _enviar(metodo, ruta, null, token: access);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
    }
    if (!await _refrescar()) {
      await _tokens.borrar();
      alCerrarSesion?.call();
      throw const ApiException('Sesión expirada', 401);
    }
    return _enviar(metodo, ruta, null, token: await _tokens.access);
  }

  /// true si rotó los tokens; false si el servidor rechazó el refresh.
  /// Un fallo de red se propaga: no equivale a sesión inválida.
  Future<bool> _refrescar() =>
      _refrescando ??= _hacerRefresh().whenComplete(() => _refrescando = null);

  Future<bool> _hacerRefresh() async {
    final refresh = await _tokens.refresh;
    if (refresh == null) return false;
    try {
      final r = await _enviar('POST', '/auth/refresh', {
        'refresh_token': refresh,
      });
      await _guardarTokens(r);
      return true;
    } on ApiException catch (e) {
      final code = e.statusCode;
      if (code != null && code >= 400 && code < 500) return false;
      rethrow;
    }
  }

  /// Una petición con timeout de operación completa; lanza [ApiException]
  /// con mensaje en español ante cualquier fallo.
  Future<http.Response> _enviar(
    String metodo,
    String ruta,
    Map<String, dynamic>? body, {
    String? token,
    String? credencialesMsg,
  }) async {
    final req = http.Request(metodo, Uri.parse('$baseUrl$ruta'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    final http.Response r;
    try {
      r = await (() async => http.Response.fromStream(
        await _client.send(req),
      ))().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    } on SocketException {
      throw const ApiException('Sin conexión. Revisa tu internet.');
    } on http.ClientException {
      throw const ApiException('Sin conexión. Revisa tu internet.');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    throw ApiException(_mensaje(r, credencialesMsg), r.statusCode);
  }

  String _mensaje(http.Response r, String? credencialesMsg) {
    final code = r.statusCode;
    if (code == 401 && credencialesMsg != null) return credencialesMsg;
    if (code >= 500 && code != 503) {
      return 'Error del servidor. Intenta más tarde.';
    }
    if (code == 422) return 'Revisa los datos ingresados.';
    // 409 / 503 / 401: el backend manda `detail` en español.
    try {
      final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
      if (detail is String) return detail;
    } catch (_) {}
    return 'No se pudo completar la solicitud.';
  }
}
