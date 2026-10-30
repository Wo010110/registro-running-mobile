import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/api_client.dart';
import 'package:heyrun_mobile/models/user.dart';
import 'package:heyrun_mobile/providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

Future<AuthState> _esperar(ProviderContainer c) async {
  c.read(authProvider);
  while (c.read(authProvider).status == AuthStatus.loading) {
    await Future<void>.delayed(Duration.zero);
  }
  return c.read(authProvider);
}

ProviderContainer _contenedor(FakeTokens tokens, MockClient client) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(
        ApiClient(baseUrl: 'http://x', tokens: tokens, client: client),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('sin tokens el estado inicial es no autenticado', () async {
    final c = _contenedor(
      FakeTokens(),
      MockClient((_) async => http.Response('', 500)),
    );
    expect((await _esperar(c)).status, AuthStatus.unauthenticated);
  });

  test('con tokens válidos carga /me y queda autenticado', () async {
    final c = _contenedor(
      FakeTokens(access: 'A', refresh: 'R'),
      MockClient((req) async {
        expect(req.url.path, '/me');
        return http.Response(usuarioJson, 200);
      }),
    );
    final s = await _esperar(c);
    expect(s.status, AuthStatus.authenticated);
    expect(s.user?.displayName, 'Ana');
  });

  test('con tokens y sin red queda offline sin borrar tokens', () async {
    final tokens = FakeTokens(access: 'A', refresh: 'R');
    final c = _contenedor(
      tokens,
      MockClient((_) async => throw http.ClientException('sin red')),
    );
    expect((await _esperar(c)).status, AuthStatus.offline);
    expect(await tokens.refresh, 'R');
  });

  final perfil = User.fromJson(jsonDecode(usuarioJson) as Map<String, dynamic>);

  test('con tokens, perfil guardado y sin red entra sin conexión', () async {
    final tokens = FakeTokens(
      access: 'A',
      refresh: 'R',
      perfilGuardado: perfil,
    );
    final c = _contenedor(
      tokens,
      MockClient((_) async => throw http.ClientException('sin red')),
    );
    final s = await _esperar(c);
    expect(s.status, AuthStatus.authenticated);
    expect(s.sinConexion, isTrue);
    expect(s.user?.displayName, 'Ana');
  });

  test(
    'con perfil guardado y fallo genérico (API_URL vacío) entra sin conexión',
    () async {
      final c = _contenedor(
        FakeTokens(access: 'A', refresh: 'R', perfilGuardado: perfil),
        MockClient((_) async => throw StateError('API_URL vacío')),
      );
      final s = await _esperar(c);
      expect(s.status, AuthStatus.authenticated);
      expect(s.sinConexion, isTrue);
    },
  );

  test('401 sin refresh válido cierra sesión y borra el perfil', () async {
    final tokens = FakeTokens(
      access: 'A',
      refresh: 'R',
      perfilGuardado: perfil,
    );
    final c = _contenedor(
      tokens,
      MockClient((_) async => http.Response('{}', 401)),
    );
    expect((await _esperar(c)).status, AuthStatus.unauthenticated);
    expect(tokens.perfilGuardado, isNull);
  });

  test('cerrar sesión borra el perfil guardado', () async {
    final tokens = FakeTokens(access: 'A', refresh: 'R');
    final c = _contenedor(
      tokens,
      MockClient((req) async => http.Response(usuarioJson, 200)),
    );
    await _esperar(c);
    expect(tokens.perfilGuardado?.displayName, 'Ana');
    await c.read(authProvider.notifier).cerrarSesion();
    expect(tokens.perfilGuardado, isNull);
    expect(c.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('refrescarPerfil con la API de vuelta limpia sinConexion', () async {
    var hayRed = false;
    final c = _contenedor(
      FakeTokens(access: 'A', refresh: 'R', perfilGuardado: perfil),
      MockClient((_) async {
        if (!hayRed) throw http.ClientException('sin red');
        return http.Response(usuarioJson, 200);
      }),
    );
    expect((await _esperar(c)).sinConexion, isTrue);
    await c.read(authProvider.notifier).refrescarPerfil();
    expect(c.read(authProvider).sinConexion, isTrue);
    hayRed = true;
    await c.read(authProvider.notifier).refrescarPerfil();
    expect(c.read(authProvider).sinConexion, isFalse);
    expect(c.read(authProvider).status, AuthStatus.authenticated);
  });
}
