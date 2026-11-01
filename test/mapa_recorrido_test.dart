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

Widget _app(
  PuntoGps? pos, {
  bool acercar = false,
  Duration retardo = Duration.zero,
}) => MaterialApp(
  home: SizedBox(
    width: 400,
    height: 800,
    child: MapaRecorrido(
      ruta: const [],
      posicion: pos,
      enVivo: true,
      acercar: acercar,
      retardoAcercar: retardo,
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
    await t.pump(const Duration(milliseconds: 1000));
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
    await t.pump(const Duration(milliseconds: 1000));
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

  testWidgets('el paso del zoom del mundo al de grabación es animado', (
    t,
  ) async {
    await t.pumpWidget(_app(null));
    await t.pump(const Duration(milliseconds: 200));
    expect(_camara(t).zoom, 2);
    await t.pumpWidget(_app(_punto(10.0)));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    expect(_camara(t).zoom, allOf(greaterThan(2), lessThan(17)));
    await t.pump(const Duration(milliseconds: 2000));
    expect(_camara(t).zoom, 17);
    expect(_camara(t).center.latitude, closeTo(10.0, 1e-9));
  });

  testWidgets('el acercar espera el retardo y luego anima hasta 19', (t) async {
    await t.pumpWidget(_app(_punto(10.0)));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpWidget(
      _app(
        _punto(10.0),
        acercar: true,
        retardo: const Duration(milliseconds: 800),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    expect(_camara(t).zoom, 17); // aún esperando
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 800));
    expect(_camara(t).zoom, allOf(greaterThan(17), lessThan(19)));
    await t.pump(const Duration(milliseconds: 1500));
    expect(_camara(t).zoom, 19);
  });

  testWidgets('cada trozo de la ruta es su propia línea', (t) async {
    PuntoGps p(double lat) => _punto(lat);
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: MapaRecorrido(
            ruta: [
              [p(10.0), p(10.001), p(10.002)],
              [p(10.01), p(10.011)],
              const [], // trozo recién abierto, sin puntos
            ],
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    final capa = t.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(capa.polylines.length, 2);
  });
}
