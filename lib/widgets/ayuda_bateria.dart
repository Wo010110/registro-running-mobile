import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

const _kAyudaVista = 'ayuda_bateria_vista';

/// Tecno, Infinix e itel (Transsion) matan las apps en segundo plano más
/// agresivamente que el resto.
bool esTranssion(String fabricante) => const {
  'tecno',
  'infinix',
  'itel',
  'transsion',
}.contains(fabricante.trim().toLowerCase());

const pasosGenerales = [
  'Ajustes > Aplicaciones > Hey, run! > Batería: elige "Sin restricciones".',
  'Ubicación: "Permitir solo mientras se usa la app". Notificaciones: activadas.',
  'No cierres la app deslizándola desde recientes mientras grabas.',
];

const pasosTranssion = [
  'Gestor del teléfono o Ajustes > Batería: quita Hey, run! de la optimización o ahorro de batería.',
  'Permite el inicio automático (autoarranque) de Hey, run!.',
  'Abre recientes, toca el icono de Hey, run! y elige "Bloquear" para que no la cierre el sistema.',
];

/// La primera vez, antes de iniciar. Se puede saltar: la app graba igual.
Future<void> mostrarAyudaBateriaSiToca(
  BuildContext context,
  WidgetRef ref,
) async {
  final prefs = ref.read(prefsProvider);
  if (prefs.getBool(_kAyudaVista) ?? false) return;
  var fabricante = '';
  try {
    fabricante = (await DeviceInfoPlugin().androidInfo).manufacturer;
  } catch (_) {}
  if (!context.mounted) return;
  final noVolver = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AyudaBateria(transsion: esTranssion(fabricante)),
  );
  if (noVolver ?? false) await prefs.setBool(_kAyudaVista, true);
}

class AyudaBateria extends StatefulWidget {
  const AyudaBateria({super.key, required this.transsion});

  final bool transsion;

  @override
  State<AyudaBateria> createState() => _AyudaBateriaState();
}

class _AyudaBateriaState extends State<AyudaBateria> {
  var _noVolver = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pasos = widget.transsion ? pasosTranssion : pasosGenerales;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Para que el teléfono no duerma la app',
              style: TextStyle(
                color: c.textoPrincipal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Si el sistema cierra la app a mitad de la actividad, se pierde '
              'el recorrido desde ese momento. Los nombres de los menús pueden '
              'variar según la versión.',
              style: TextStyle(color: c.textoSecundario),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < pasos.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${i + 1}. ${pasos[i]}',
                  style: TextStyle(color: c.textoPrincipal),
                ),
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _noVolver,
              onChanged: (v) => setState(() => _noVolver = v ?? false),
              title: const Text('No volver a mostrar'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: OutlinedButton(
                    onPressed: openAppSettings,
                    child: Text('Abrir ajustes'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_noVolver),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
