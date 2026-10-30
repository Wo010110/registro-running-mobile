import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

http.Response _json(int code, String body) =>
    http.Response(body, code, headers: {'content-type': 'application/json'});

void main() {
  test('login ok guarda los tokens', () async {
    final tokens = FakeTokens();
    final api = ApiClient(
      baseUrl: 'http://x',
      tokens: tokens,
      client: MockClient((req) async {
        expect(req.url.path, '/auth/login');
        return _json(200, tokensJson('A1', 'R1'));
      }),
    );
    await api.login('a@b.com', 'secreto123');
    expect(await tokens.access, 'A1');
    expect(await tokens.refresh, 'R1');
  });

  test('login con 401 da mensaje de credenciales', () async {
    final api = ApiClient(
      baseUrl: 'http://x',
      tokens: FakeTokens(),
      client: MockClient(
        (_) async => _json(401, '{"detail":"Credenciales inválidas"}'),
      ),
    );
    expect(
      api.login('a@b.com', 'mal'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Correo o contraseña incorrectos',
        ),
      ),
    );
  });

  test('401 -> refresh -> reintento con el token nuevo', () async {
    final tokens = FakeTokens(access: 'viejo', refresh: 'R1');
    final llamadas = <String>[];
    final api = ApiClient(
      baseUrl: 'http://x',
      tokens: tokens,
      client: MockClient((req) async {
        llamadas.add('${req.url.path} ${req.headers['Authorization'] ?? ''}');
        if (req.url.path == '/auth/refresh') {
          return _json(200, tokensJson('nuevo', 'R2'));
        }
        return req.headers['Authorization'] == 'Bearer nuevo'
            ? _json(200, usuarioJson)
            : _json(401, '{"detail":"expirado"}');
      }),
    );
    final user = await api.me();
    expect(user.displayName, 'Ana');
    expect(user.createdAt.isUtc, isTrue);
    expect(user.createdAt, DateTime.utc(2026, 1, 2, 12));
    expect(llamadas, [
      '/me Bearer viejo',
      '/auth/refresh ',
      '/me Bearer nuevo',
    ]);
    expect(await tokens.refresh, 'R2');
  });

  test('refresh fallido borra tokens y cierra sesión', () async {
    final tokens = FakeTokens(access: 'viejo', refresh: 'R1');
    var cerrada = false;
    final api = ApiClient(
      baseUrl: 'http://x',
      tokens: tokens,
      alCerrarSesion: () => cerrada = true,
      client: MockClient((_) async => _json(401, '{"detail":"x"}')),
    );
    await expectLater(api.me(), throwsA(isA<ApiException>()));
    expect(cerrada, isTrue);
    expect(await tokens.access, isNull);
    expect(await tokens.refresh, isNull);
  });

  test(
    'timeout de 8 s da mensaje de servidor lento',
    () async {
      final api = ApiClient(
        baseUrl: 'http://x',
        tokens: FakeTokens(),
        client: MockClient((_) => Completer<http.Response>().future),
      );
      await expectLater(
        api.login('a@b.com', 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('tardó'),
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
