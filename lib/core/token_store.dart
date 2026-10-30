import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// Los tokens y el último perfil conocido viven solo en el almacenamiento
/// seguro del sistema.
class TokenStore {
  const TokenStore();

  static const _storage = FlutterSecureStorage();
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kPerfil = 'perfil';

  Future<String?> get access => _storage.read(key: _kAccess);
  Future<String?> get refresh => _storage.read(key: _kRefresh);

  /// Último perfil conocido, para arrancar sin red; null si falta o está corrupto.
  Future<User?> get perfil async {
    try {
      final raw = await _storage.read(key: _kPerfil);
      if (raw == null) return null;
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(String access, String refresh) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> guardarPerfil(User user) =>
      _storage.write(key: _kPerfil, value: jsonEncode(user.toJson()));

  Future<void> borrar() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kPerfil);
  }
}
