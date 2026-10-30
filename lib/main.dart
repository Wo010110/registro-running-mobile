import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/carreras_db.dart';
import 'providers/auth_provider.dart';
import 'providers/grabacion_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/sin_conexion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final carrerasDb = await CarrerasDb.abrir();
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        carrerasDbProvider.overrideWithValue(carrerasDb),
      ],
      child: const HeyRunApp(),
    ),
  );
}

class HeyRunApp extends ConsumerWidget {
  const HeyRunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Hey, run!',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeProvider),
      theme: construirTema(AppColors.claro, Brightness.light),
      darkTheme: construirTema(AppColors.oscuro, Brightness.dark),
      locale: const Locale('es'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      home: const _PuertaAuth(),
    );
  }
}

class _PuertaAuth extends ConsumerWidget {
  const _PuertaAuth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reconexionProvider);
    return switch (ref.watch(authProvider).status) {
      AuthStatus.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.offline => const SinConexion(),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => const HomeScreen(),
    };
  }
}
