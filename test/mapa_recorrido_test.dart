import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/carrera_calculos.dart';
import 'package:heyrun_mobile/widgets/mapa_recorrido.dart';

PuntoGps _punto(double lat) => PuntoGps(
  lat: lat,
  lng: -66.8,
  precisionM: 5,
  instante: DateTime.utc(2026, 1, 1, 8),
);

Widget _app(PuntoGps? pos, {bool acercar = false}) => MaterialApp(
  home: SizedBox(
    width: 400,
    height: 800,
    child: MapaRecorrido(
      ruta: const [],
      posicion: pos,
      enVivo: true,
      acercar: acercar,
    ),
  ),
);

MapCamera _camara(WidgetTester t) =>
    MapCamera.of(t.element(find.byType(TileLayer)));

void main() {
  testWidgets('en vivo el mapa sigue la posición', (t) async {
    await t.pumpWidget(_app(_punto(10.0)));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpWidget(_app(_punto(10.001)));
    await t.pump(const Duration(milliseconds: 200));
    expect(_camara(t).center.latitude, closeTo(10.001, 1e-9));
    expect(_camara(t).zoom, 17);
  });

  testWidgets('al empezar se acerca al punto y sigue moviéndose', (t) async {
    await t.pumpWidget(_app(_punto(10.0)));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpWidget(_app(_punto(10.001), acercar: true));
    await t.pump(const Duration(milliseconds: 2000));
    expect(_camara(t).zoom, 19);
    await t.pumpWidget(_app(_punto(10.002), acercar: true));
    await t.pump(const Duration(milliseconds: 200));
    expect(_camara(t).center.latitude, closeTo(10.002, 1e-9));
    expect(_camara(t).zoom, 19);
  });

  testWidgets('si la posición llega tarde, el zoom espera y se hace', (
    t,
  ) async {
    await t.pumpWidget(_app(null));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpWidget(_app(null, acercar: true));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpWidget(_app(_punto(10.0), acercar: true));
    await t.pump(const Duration(milliseconds: 2000));
    expect(_camara(t).zoom, 19);
  });
}
