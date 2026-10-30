import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/utils.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .registrar(
            _nombre.text.trim(),
            _email.text.trim().toLowerCase(),
            _password.text,
          );
      // La puerta de main ya muestra el inicio; se cierra esta pantalla.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) {
                    final n = (v ?? '').trim();
                    if (n.isEmpty) return 'Ingresa tu nombre';
                    return n.length > 100 ? 'Máximo 100 caracteres' : null;
                  },
                ),
                const SizedBox(height: 16),
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
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (mínimo 8 caracteres)',
                  ),
                  validator: (v) => (v ?? '').length < 8
                      ? 'La contraseña debe tener al menos 8 caracteres'
                      : null,
                  onFieldSubmitted: (_) => _registrar(),
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
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.sobreAccion,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
