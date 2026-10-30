import 'package:flutter_test/flutter_test.dart';
import 'package:heyrun_mobile/core/formato.dart';
import 'package:heyrun_mobile/widgets/ayuda_bateria.dart';

void main() {
  test('tiempo en hh:mm:ss', () {
    expect(formatearTiempo(0), '00:00:00');
    expect(formatearTiempo(59), '00:00:59');
    expect(formatearTiempo(3725), '01:02:05');
    expect(formatearTiempo(5100), '01:25:00');
    expect(formatearTiempo(-3), '00:00:00');
  });

  test('distancia en km con dos decimales y coma', () {
    expect(formatearKm(0), '0,00');
    expect(formatearKm(5012.5), '5,01');
    expect(formatearKm(10000), '10,00');
  });

  test('ritmo en m:ss y sin dato', () {
    expect(formatearRitmo(null), '--:--');
    expect(formatearRitmo(double.infinity), '--:--');
    expect(formatearRitmo(333.3), '5:33');
    expect(formatearRitmo(359.6), '6:00');
    expect(formatearRitmo(605), '10:05');
    expect(formatearRitmo(3599), '59:59');
    expect(formatearRitmo(3600), '--:--');
    expect(formatearRitmo(13427), '--:--');
  });

  test('detecta los fabricantes Transsion', () {
    expect(esTranssion('TECNO'), isTrue);
    expect(esTranssion('Infinix'), isTrue);
    expect(esTranssion('itel'), isTrue);
    expect(esTranssion('samsung'), isFalse);
    expect(esTranssion(''), isFalse);
  });
}
