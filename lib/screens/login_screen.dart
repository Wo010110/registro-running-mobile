import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/api_client.dart';
import '../core/utils.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await accion();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _entrar() {
    if (!_form.currentState!.validate()) return;
    _ejecutar(
      () => ref
          .read(authProvider.notifier)
          .iniciarSesion(_email.text.trim().toLowerCase(), _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hey, run!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textoPrincipal,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Correo'),
                    validator: (v) => emailRegex.hasMatch((v ?? '').trim())
                        ? null
                        : 'Ingresa un correo válido',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                    onFieldSubmitted: (_) => _entrar(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.errorTexto),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: c.sobreAccion,
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _cargando
                        ? null
                        : () => _ejecutar(
                            ref.read(authProvider.notifier).conGoogle,
                          ),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedGoogle,
                      color: c.textoPrincipal,
                      size: 20,
                    ),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
