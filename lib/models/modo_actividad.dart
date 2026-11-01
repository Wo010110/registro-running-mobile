import 'dart:convert';

import '../core/formato.dart';

/// Se mide por distancia (m) o por tiempo (s).
enum Medida { distancia, tiempo }

enum AlTerminarIntervalos {
  finalizar('Finalizar'),
  pausar('Pausar'),
  libre('Seguir libre');

  const AlTerminarIntervalos(this.etiqueta);
  final String etiqueta;
}

enum AlLlegarMeta {
  pausar('Pausar'),
  finalizar('Finalizar'),
  avisar('Solo avisar');

  const AlLlegarMeta(this.etiqueta);
  final String etiqueta;
}

enum TipoModo {
  libre('Libre'),
  intervalos('Intervalos'),
  meta('Meta');

  const TipoModo(this.etiqueta);
  final String etiqueta;
}

String _valor(Medida medida, int v) => medida == Medida.distancia
    ? formatearDistanciaCorta(v)
    : formatearDuracionCorta(v);

T _enumDe<T extends Enum>(List<T> valores, Object? nombre, T defecto) {
  for (final v in valores) {
    if (v.name == nombre) return v;
  }
  return defecto;
}

int _entero(Object? v, int defecto) => v is int && v >= 1 ? v : defecto;

/// Cómo se hace una actividad. Un solo modo por actividad.
sealed class ModoActividad {
  const ModoActividad();

  TipoModo get tipo;

  /// Texto del historial; null en libre.
  String? get etiqueta;

  /// Línea de configuración de la pantalla de preparar.
  String get resumen;

  /// null en libre: así se guarda en la base.
  Map<String, Object?>? aJson();

  String? aTexto() {
    final j = aJson();
    return j == null ? null : jsonEncode(j);
  }

  /// null si el texto es null o no se entiende (se trata como libre).
  static ModoActividad? desdeTexto(String? texto) {
    if (texto == null) return null;
    try {
      final j = jsonDecode(texto);
      if (j is! Map<String, dynamic>) return null;
      return switch (j['modo']) {
        'intervalos' => ModoIntervalos.desdeJson(j),
        'meta' => ModoMeta.desdeJson(j),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}

class ModoLibre extends ModoActividad {
  const ModoLibre();

  @override
  TipoModo get tipo => TipoModo.libre;
  @override
  String? get etiqueta => null;
  @override
  String get resumen => 'Sin objetivo';
  @override
  Map<String, Object?>? aJson() => null;
}

class ModoIntervalos extends ModoActividad {
  const ModoIntervalos({
    this.tramoMedida = Medida.distancia,
    this.tramo = 400,
    this.descansoMedida = Medida.tiempo,
    this.descanso = 90,
    this.repeticiones = 8,
    this.alTerminar = AlTerminarIntervalos.finalizar,
  });

  factory ModoIntervalos.desdeJson(Map<String, dynamic> j) {
    const base = ModoIntervalos();
    final reps = j['repeticiones'];
    return ModoIntervalos(
      tramoMedida: _enumDe(Medida.values, j['tramoMedida'], base.tramoMedida),
      tramo: _entero(j['tramo'], base.tramo),
      descansoMedida: _enumDe(
        Medida.values,
        j['descansoMedida'],
        base.descansoMedida,
      ),
      descanso: _entero(j['descanso'], base.descanso),
      repeticiones: reps == null ? null : _entero(reps, base.repeticiones!),
      alTerminar: _enumDe(
        AlTerminarIntervalos.values,
        j['alTerminar'],
        base.alTerminar,
      ),
    );
  }

  /// Largo del tramo de correr: m o s según [tramoMedida].
  final Medida tramoMedida;
  final int tramo;

  /// Descanso entre tramos: s o m según [descansoMedida].
  final Medida descansoMedida;
  final int descanso;

  /// null = sin límite (hasta Finalizar).
  final int? repeticiones;
  final AlTerminarIntervalos alTerminar;

  ModoIntervalos copyWith({
    Medida? tramoMedida,
    int? tramo,
    Medida? descansoMedida,
    int? descanso,
    AlTerminarIntervalos? alTerminar,
  }) => ModoIntervalos(
    tramoMedida: tramoMedida ?? this.tramoMedida,
    tramo: tramo ?? this.tramo,
    descansoMedida: descansoMedida ?? this.descansoMedida,
    descanso: descanso ?? this.descanso,
    repeticiones: repeticiones,
    alTerminar: alTerminar ?? this.alTerminar,
  );

  /// Aparte de [copyWith] porque null (sin límite) es un valor válido.
  ModoIntervalos conRepeticiones(int? repeticiones) => ModoIntervalos(
    tramoMedida: tramoMedida,
    tramo: tramo,
    descansoMedida: descansoMedida,
    descanso: descanso,
    repeticiones: repeticiones,
    alTerminar: alTerminar,
  );

  @override
  TipoModo get tipo => TipoModo.intervalos;

  String get _reps => repeticiones?.toString() ?? 'sin límite';

  @override
  String get etiqueta => 'Intervalos $_reps × ${_valor(tramoMedida, tramo)}';

  @override
  String get resumen =>
      '${repeticiones ?? 'Sin límite'} × ${_valor(tramoMedida, tramo)} · '
      'descanso ${_valor(descansoMedida, descanso)}';

  @override
  Map<String, Object?> aJson() => {
    'modo': 'intervalos',
    'tramoMedida': tramoMedida.name,
    'tramo': tramo,
    'descansoMedida': descansoMedida.name,
    'descanso': descanso,
    'repeticiones': repeticiones,
    'alTerminar': alTerminar.name,
  };
}

class ModoMeta extends ModoActividad {
  const ModoMeta({
    this.medida = Medida.distancia,
    this.valor = 5000,
    this.alLlegar = AlLlegarMeta.avisar,
  });

  factory ModoMeta.desdeJson(Map<String, dynamic> j) {
    const base = ModoMeta();
    return ModoMeta(
      medida: _enumDe(Medida.values, j['medida'], base.medida),
      valor: _entero(j['valor'], base.valor),
      alLlegar: _enumDe(AlLlegarMeta.values, j['alLlegar'], base.alLlegar),
    );
  }

  /// m o s según [medida]; el tiempo es en movimiento (sin pausas).
  final Medida medida;
  final int valor;
  final AlLlegarMeta alLlegar;

  ModoMeta copyWith({Medida? medida, int? valor, AlLlegarMeta? alLlegar}) =>
      ModoMeta(
        medida: medida ?? this.medida,
        valor: valor ?? this.valor,
        alLlegar: alLlegar ?? this.alLlegar,
      );

  @override
  TipoModo get tipo => TipoModo.meta;

  @override
  String get etiqueta => 'Meta ${_valor(medida, valor)}';

  @override
  String get resumen =>
      '${_valor(medida, valor)} · al llegar: ${alLlegar.etiqueta.toLowerCase()}';

  @override
  Map<String, Object?> aJson() => {
    'modo': 'meta',
    'medida': medida.name,
    'valor': valor,
    'alLlegar': alLlegar.name,
  };
}
