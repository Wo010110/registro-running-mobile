import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/debug/informe_gps.dart';
import 'package:heyrun_mobile/models/tipo_actividad.dart';

PuntoGps _p(int s, double precision) => PuntoGps(
  lat: 4,
  lng: -74,
  precisionM: precision,
  instante: DateTime.utc(2026, 1, 1, 8, 0, s),
);

void main() {
  test('informe: total, precisión media, mayor hueco y huecos > 10 s', () {
    final i = construirInforme(TipoActividad.caminar, [
      _p(0, 4),
      _p(1, 6),
      _p(31, 5),
      _p(32, 5),
      _p(45, 5),
    ]);
    expect(i.tipo, TipoActividad.caminar);
    expect(i.comoTexto(), startsWith('Tipo: Caminar'));
    expect(i.total, 5);
    expect(i.precisionMediaM, closeTo(5, 0.001));
    expect(i.mayorHuecoS, 30);
    expect(i.huecos.map((h) => h.duracionS), [30, 13]);
    expect(i.huecos.first.inicio, DateTime.utc(2026, 1, 1, 8, 0, 1));
  });

  test('informe sin puntos', () {
    final i = construirInforme(TipoActividad.correr, []);
    expect(i.total, 0);
    expect(i.huecos, isEmpty);
  });
}
