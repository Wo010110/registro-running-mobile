import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/carreras_db.dart';
import '../../core/datos_ejemplo.dart';
import '../../core/formato.dart';
import '../../core/records.dart';
import '../../debug/prueba_gps_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navegacion_provider.dart';
import '../../providers/perfil_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/historial_actividades.dart';
import '../../widgets/medalla_tarjeta.dart';
import '../../widgets/tarjeta.dart';
import '../settings_screen.dart';

class PerfilTab extends ConsumerStatefulWidget {
  const PerfilTab({super.key});

  @override
  ConsumerState<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends ConsumerState<PerfilTab> {
  final _historialKey = GlobalKey();

  /// "Ver todas" de Inicio: baja hasta el historial.
  void _verHistorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _historialKey.currentContext;
      if (contexto != null) {
        Scrollable.ensureVisible(
          contexto,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    ref.listen(solicitudHistorialProvider, (_, _) => _verHistorial());
    final user = ref.watch(authProvider).user;
    final perfil = ref.watch(perfilLocalProvider);
    final cifras = ref.watch(cifrasPerfilProvider);
    final records = ref.watch(recordsProvider).value ?? const {};
    final nombre = user?.displayName ?? '';
    final inicial = nombre.isEmpty
        ? '?'
        : nombre.characters.first.toUpperCase();
    // Sin carga perezosa: Inicio pide bajar hasta el historial y su contexto
    // debe existir.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primarioSuave,
                    border: Border.all(color: c.primario, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      inicial,
                      style: TextStyle(
                        color: c.primario,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textoPrincipal,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (user != null)
                  Text(
                    user.email,
                    style: TextStyle(color: c.textoTenue, fontSize: 14),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: c.textoTenue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        perfil.ciudad.isEmpty ? 'Sin ciudad' : perfil.ciudad,
                        style: TextStyle(
                          color: perfil.ciudad.isEmpty
                              ? c.textoTenue
                              : c.textoSecundario,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (perfil.presentacion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      perfil.presentacion,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textoSecundario, fontSize: 15),
                    ),
                  ),
                TextButton(
                  onPressed: () => editarPerfil(context),
                  child: const Text(
                    'EDITAR PERFIL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Tarjeta(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _Cifra('Actividades', '${cifras.actividades}'),
                _Cifra('Kilómetros', formatearKmUno(cifras.distanciaM / 1000)),
                _Cifra('Tiempo', formatearHorasMin(cifras.tiempoS)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Tarjeta(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                // shortcut: cifras de ejemplo hasta que haya nube (ver
                // datos_ejemplo.dart).
                _Cifra('Seguidores', '$seguidoresEjemplo'),
                _Cifra('Siguiendo', '$siguiendoEjemplo'),
              ],
            ),
          ),
          const TituloSeccion('Medallas'),
          // shortcut: medallas de ejemplo (datos_ejemplo.dart) hasta que haya
          // nube; después salen de los retos cumplidos.
          const CuadriculaMedallas(medallasEjemplo),
          const TituloSeccion('Récords personales'),
          _CuadriculaRecords(records),
          TituloSeccion('Historial de actividades', key: _historialKey),
          const HistorialActividades(),
          const TituloSeccion('Cuenta'),
          Tarjeta(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Fila(
                  icono: HugeIcons.strokeRoundedSettings01,
                  texto: 'Ajustes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
                if (kDebugMode) ...[
                  Divider(height: 1, color: c.divisor),
                  _Fila(
                    icono: HugeIcons.strokeRoundedLocation01,
                    texto: 'Prueba GPS',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PruebaGpsScreen(),
                      ),
                    ),
                  ),
                ],
                Divider(height: 1, color: c.divisor),
                _Fila(
                  icono: HugeIcons.strokeRoundedLogout01,
                  texto: 'Cerrar sesión',
                  destructiva: true,
                  onTap: ref.read(authProvider.notifier).cerrarSesion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja inferior para editar la ciudad y la presentación.
Future<void> editarPerfil(BuildContext context) {
  final c = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.superficie,
    showDragHandle: true,
    builder: (_) => const _HojaPerfil(),
  );
}

class _HojaPerfil extends ConsumerStatefulWidget {
  const _HojaPerfil();

  @override
  ConsumerState<_HojaPerfil> createState() => _HojaPerfilState();
}

class _HojaPerfilState extends ConsumerState<_HojaPerfil> {
  late final _ciudad = TextEditingController(
    text: ref.read(perfilLocalProvider).ciudad,
  );
  late final _presentacion = TextEditingController(
    text: ref.read(perfilLocalProvider).presentacion,
  );

  @override
  void dispose() {
    _ciudad.dispose();
    _presentacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    await ref
        .read(perfilLocalProvider.notifier)
        .guardar(ciudad: _ciudad.text, presentacion: _presentacion.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'EDITAR PERFIL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ciudad,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _presentacion,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Presentación',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardar,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los ocho récords en dos columnas; "--" donde la actividad nunca llegó a
/// esa distancia seguida.
class _CuadriculaRecords extends StatelessWidget {
  const _CuadriculaRecords(this.records);

  final Map<double, RecordPersonal> records;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final ancho = (caja.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final objetivo in objetivosRecord)
              SizedBox(
                width: ancho,
                child: _Record(rotulosRecord[objetivo]!, records[objetivo]),
              ),
          ],
        );
      },
    );
  }
}

class _Record extends StatelessWidget {
  const _Record(this.rotulo, this.record);

  final String rotulo;
  final RecordPersonal? record;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = record;
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTrophy,
                color: r == null ? c.textoDeshabilitado : c.medalla,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textoTenue, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              r == null ? '--' : formatearTiempoRecord(r.tiempoS),
              style: TextStyle(
                color: r == null ? c.textoDeshabilitado : c.textoPrincipal,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 2),
            Text(
              '${formatearRitmo(r.ritmoSKm)} /km',
              style: TextStyle(color: c.textoSecundario, fontSize: 13),
            ),
            Text(
              DateFormat('d MMM y', 'es').format(r.inicioUtc.toLocal()),
              style: TextStyle(color: c.textoTenue, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(etiqueta, style: TextStyle(color: c.textoTenue, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.destructiva = false,
  });

  final List<List<dynamic>> icono;
  final String texto;
  final VoidCallback onTap;
  final bool destructiva;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = destructiva ? c.errorTexto : c.textoPrincipal;
    return ListTile(
      onTap: onTap,
      leading: HugeIcon(icon: icono, color: color, size: 22),
      title: Text(texto, style: TextStyle(color: color)),
      trailing: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        color: c.textoDeshabilitado,
        size: 18,
      ),
    );
  }
}
