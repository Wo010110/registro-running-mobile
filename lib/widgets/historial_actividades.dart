import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tipo_actividad.dart';
import '../providers/historial_provider.dart';
import '../theme/app_colors.dart';
import 'tarjeta_actividad.dart';

/// Filtros Todas / Correr / Caminar y la lista de actividades guardadas.
class HistorialActividades extends ConsumerStatefulWidget {
  const HistorialActividades({super.key});

  @override
  ConsumerState<HistorialActividades> createState() =>
      _HistorialActividadesState();
}

class _HistorialActividadesState extends ConsumerState<HistorialActividades> {
  /// null = todas.
  TipoActividad? _filtro;

  @override
  Widget build(BuildContext context) {
    final historial = ref.watch(historialProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Ficha(
              'Todas',
              activa: _filtro == null,
              alTocar: () => setState(() => _filtro = null),
            ),
            for (final t in TipoActividad.values)
              _Ficha(
                t.etiqueta,
                activa: _filtro == t,
                alTocar: () => setState(() => _filtro = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...historial.when(
          data: (todas) {
            final lista = [
              for (final a in todas)
                if (_filtro == null || a.tipo == _filtro) a,
            ];
            if (lista.isEmpty) {
              return [
                SinActividades(
                  texto: todas.isEmpty
                      ? null
                      : 'No hay actividades de este tipo todavía.',
                ),
              ];
            }
            return [
              for (final a in lista) ...[
                TarjetaActividad(key: ValueKey(a.id), carrera: a, alto: 96),
                const SizedBox(height: 12),
              ],
            ];
          },
          loading: () => const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            const SinActividades(
              texto: 'No se pudieron leer las actividades guardadas.',
            ),
          ],
        ),
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha(this.texto, {required this.activa, required this.alTocar});

  final String texto;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activa ? c.accion : c.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activa ? c.accion : c.borde),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activa ? c.sobreAccion : c.textoSecundario,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
