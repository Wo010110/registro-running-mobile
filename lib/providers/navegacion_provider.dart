import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestaña de la pantalla principal: 0 Inicio, 1 Clasificatoria, 2 Retos,
/// 3 Perfil.
class PestanaNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void ir(int pestana) => state = pestana;
}

final pestanaProvider = NotifierProvider<PestanaNotifier, int>(
  PestanaNotifier.new,
);

/// Cada pedido de "ver el historial" sube el contador; el Perfil baja hasta
/// su sección de historial.
class SolicitudHistorialNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void pedir() => state++;
}

final solicitudHistorialProvider =
    NotifierProvider<SolicitudHistorialNotifier, int>(
      SolicitudHistorialNotifier.new,
    );
