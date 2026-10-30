import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/user.dart';

enum AuthStatus { loading, authenticated, unauthenticated, offline }

class AuthState {
  const AuthState({required this.status, this.user, this.sinConexion = false});

  final AuthStatus status;
  final User? user;

  /// Sesión autenticada con el perfil guardado porque no se llegó a la API.
  final bool sinConexion;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    alCerrarSesion: () => ref.read(authProvider.notifier).sesionExpirada(),
  );
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _cargar();
    return const AuthState(status: AuthStatus.loading);
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _cargar() async {
    if (!await _api.hayTokens) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (e) {
      // 401 ya cerró la sesión vía alCerrarSesion; lo demás es red o servidor.
      if (e.statusCode == 401) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        await _sinRed();
      }
    } catch (_) {
      // Cualquier otro fallo (p. ej. API_URL vacío) no debe dejar la app en "loading".
      await _sinRed();
    }
  }

  /// Sin API: entra con el último perfil guardado; sin perfil, pantalla offline.
  Future<void> _sinRed() async {
    final user = await _api.perfilGuardado;
    state = user == null
        ? const AuthState(status: AuthStatus.offline)
        : AuthState(
            status: AuthStatus.authenticated,
            user: user,
            sinConexion: true,
          );
  }

  /// Intenta /me; si falla no cambia el estado.
  Future<void> refrescarPerfil() async {
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {}
  }

  Future<void> reintentar() async {
    state = const AuthState(status: AuthStatus.loading);
    await _cargar();
  }

  void sesionExpirada() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Las acciones lanzan [ApiException]; la pantalla muestra el mensaje.
  Future<void> iniciarSesion(String email, String password) async {
    await _api.login(email, password);
    await _cargarTrasLogin();
  }

  Future<void> registrar(String nombre, String email, String password) async {
    await _api.register(nombre, email, password);
    await _cargarTrasLogin();
  }

  Future<void> conGoogle() async {
    if (googleServerClientId.isEmpty) {
      throw const ApiException('Google no está configurado en esta versión.');
    }
    final String? idToken;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: googleServerClientId,
      );
      final cuenta = await GoogleSignIn.instance.authenticate();
      idToken = cuenta.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw const ApiException('No se pudo iniciar sesión con Google.');
    }
    if (idToken == null) {
      throw const ApiException('No se pudo iniciar sesión con Google.');
    }
    await _api.loginGoogle(idToken);
    await _cargarTrasLogin();
  }

  Future<void> cerrarSesion() async {
    await _api.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _cargarTrasLogin() async {
    final user = await _api.me();
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Al volver la red, limpia el aviso "sin conexión". Se observa desde la raíz.
final reconexionProvider = Provider<void>((ref) {
  final sub = Connectivity().onConnectivityChanged.listen((redes) {
    if (redes.contains(ConnectivityResult.none)) return;
    if (ref.read(authProvider).sinConexion) {
      ref.read(authProvider.notifier).refrescarPerfil();
    }
  });
  ref.onDispose(sub.cancel);
});
