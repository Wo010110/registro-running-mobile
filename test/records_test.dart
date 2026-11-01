import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/core/records.dart';

final _t0 = DateTime.utc(2026, 1, 1, 8);
const _mPorGrado = 111194.93;

PuntoGps _p(double metros, double s, {bool aceptado = true}) => PuntoGps(
  lat: 4 + metros / _mPorGrado,
  lng: -74,
  precisionM: 2,
  instante: _t0.add(Duration(milliseconds: (s * 1000).round())),
  aceptado: aceptado,
);

/// Un punto cada [paso] s a [v] m/s de [desde] a [hasta] (s); la posición sale
/// del tiempo, así varios tramos con distinta [v] encajan.
List<PuntoGps> _corre(
  double desde,
  double hasta, {
  double v = 3,
  double m0 = 0,
  double paso = 1,
}) => [
  for (var s = desde; s <= hasta + 1e-9; s += paso) _p(m0 + v * (s - desde), s),
];

PausaCarrera _pausa(double ini, double fin) => PausaCarrera(
  inicio: _t0.add(Duration(milliseconds: (ini * 1000).round())),
  fin: _t0.add(Duration(milliseconds: (fin * 1000).round())),
);

void main() {
  test('ruta recta a ritmo constante: el kilómetro sale exacto', () {
    final r = mejoresTramos(_corre(0, 400), const []);
    expect(r[1000], closeTo(1000 / 3, 0.05));
    expect(r[500], closeTo(500 / 3, 0.05));
    expect(r[100], closeTo(100 / 3, 0.05));
    expect(r.containsKey(5000), isFalse);
  });

  test('el borde se interpola entre puntos (puntos cada 7 s)', () {
    final r = mejoresTramos(_corre(0, 700, paso: 7), const []);
    expect(r[100], closeTo(100 / 3, 0.05));
    expect(r[1000], closeTo(1000 / 3, 0.05));
  });

  test('ritmo variable: elige el mejor tramo, no el primero', () {
    // 1 km lento (4 m/s), 1 km rápido (5 m/s), 1 km lento otra vez.
    final lento = _corre(0, 250, v: 4);
    final rapido = _corre(251, 450, v: 5, m0: 1000 + 4);
    final fin = _corre(451, 701, v: 4, m0: 2000 + 9);
    final r = mejoresTramos([...lento, ...rapido, ...fin], const []);
    expect(r[1000], lessThan(205));
    expect(r[1000], greaterThan(195));
    // Una ventana que empieza a mitad del tramo rápido no es mejor.
    expect(r[500], closeTo(100, 1));
  });

  test('una pausa impide un tramo que sin ella existiría', () {
    final puntos = _corre(0, 400); // 1,2 km
    expect(mejoresTramos(puntos, const []).containsKey(1000), isTrue);
    // Los puntos recibidos durante la pausa se ignoran y el tramo se corta.
    final r = mejoresTramos(puntos, [_pausa(200.5, 210.5)]);
    expect(r.containsKey(1000), isFalse);
    expect(r[500], closeTo(500 / 3, 0.05));
  });

  test('también corta una pausa de descanso', () {
    final puntos = _corre(0, 400);
    final descanso = PausaCarrera(
      inicio: _t0.add(const Duration(milliseconds: 200500)),
      fin: _t0.add(const Duration(milliseconds: 210500)),
      descanso: true,
    );
    expect(mejoresTramos(puntos, [descanso]).containsKey(1000), isFalse);
  });

  test('un hueco de GPS corta el tramo', () {
    final puntos = [..._corre(0, 99), ..._corre(140, 400, m0: 3 * 140)];
    final r = mejoresTramos(puntos, const []);
    expect(r.containsKey(1000), isFalse);
    expect(r[500], closeTo(500 / 3, 0.05));
    // Sin el hueco sí llegaría.
    expect(mejoresTramos(_corre(0, 400), const []).containsKey(1000), isTrue);
  });

  test('sin distancia suficiente no hay récord', () {
    final r = mejoresTramos(_corre(0, 250), const []); // 750 m
    expect(r.keys, [100, 500]);
    expect(mejoresTramos(const [], const []), isEmpty);
    expect(mejoresTramos([_p(0, 0)], const []), isEmpty);
  });

  test('los puntos no aceptados se ignoran', () {
    final ruido = [
      for (var s = 10; s < 300; s += 20)
        _p(5000.0 + s, s + 0.5, aceptado: false),
    ];
    final puntos = [..._corre(0, 400), ...ruido]
      ..sort((a, b) => a.instante.compareTo(b.instante));
    final r = mejoresTramos(puntos, const []);
    expect(r[1000], closeTo(1000 / 3, 0.05));
    expect(r.containsKey(5000), isFalse);
  });

  test('extremos: 100 m y 100 km', () {
    final r = mejoresTramos(_corre(0, 34000, paso: 10), const []);
    expect(r[100], closeTo(100 / 3, 0.05));
    expect(r[100000], closeTo(100000 / 3, 0.5));
    expect(r.keys.length, objetivosRecord.length);
    expect(r[21097.5], closeTo(21097.5 / 3, 0.1));
  });

  test('los rótulos de los objetivos', () {
    expect(
      [for (final o in objetivosRecord) rotulosRecord[o]],
      ['100 m', '500 m', '1 km', '5 km', '10 km', '21 km', '42 km', '100 km'],
    );
  });
}
