import 'package:heyrun_mobile/core/token_store.dart';
import 'package:heyrun_mobile/models/user.dart';

/// TokenStore en memoria para pruebas.
class FakeTokens implements TokenStore {
  FakeTokens({this._access, this._refresh, this.perfilGuardado});

  String? _access;
  String? _refresh;
  User? perfilGuardado;

  @override
  Future<String?> get access async => _access;
  @override
  Future<String?> get refresh async => _refresh;
  @override
  Future<User?> get perfil async => perfilGuardado;

  @override
  Future<void> guardar(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> guardarPerfil(User user) async {
    perfilGuardado = user;
  }

  @override
  Future<void> borrar() async {
    _access = null;
    _refresh = null;
    perfilGuardado = null;
  }
}

const usuarioJson =
    '{"id":"11111111-1111-1111-1111-111111111111","email":"a@b.com",'
    '"display_name":"Ana","created_at":"2026-01-02T08:00:00-04:00"}';

String tokensJson(String a, String r) =>
    '{"access_token":"$a","refresh_token":"$r","token_type":"bearer","expires_in":900}';
