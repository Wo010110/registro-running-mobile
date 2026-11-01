// Genera los tonos de aviso en assets/sonidos/. Desde la carpeta de la app:
//   dart run tool/generar_tonos.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _tasa = 44100;
const _volumen = 0.3;

/// Una nota: seno puro con fundido de entrada y de salida (coseno elevado).
List<double> _nota(double hz, double segundos) {
  final n = (_tasa * segundos).round();
  final fundido = (_tasa * 0.04).round();
  return [
    for (var i = 0; i < n; i++)
      sin(2 * pi * hz * i / _tasa) *
          _volumen *
          (i < fundido
              ? 0.5 - 0.5 * cos(pi * i / fundido)
              : i >= n - fundido
              ? 0.5 - 0.5 * cos(pi * (n - 1 - i) / fundido)
              : 1.0),
  ];
}

/// WAV mono de 16 bits.
Uint8List _wav(List<double> muestras) {
  final datos = muestras.length * 2;
  final b = ByteData(44 + datos);
  void texto(int pos, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(pos + i, t.codeUnitAt(i));
    }
  }

  texto(0, 'RIFF');
  b.setUint32(4, 36 + datos, Endian.little);
  texto(8, 'WAVEfmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, _tasa, Endian.little);
  b.setUint32(28, _tasa * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  texto(36, 'data');
  b.setUint32(40, datos, Endian.little);
  for (var i = 0; i < muestras.length; i++) {
    b.setInt16(44 + i * 2, (muestras[i] * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  final tonos = {
    // Dos notas ascendentes: a correr.
    'correr': [..._nota(523.25, 0.25), ..._nota(783.99, 0.35)],
    // Dos notas descendentes: a descansar.
    'descanso': [..._nota(783.99, 0.25), ..._nota(523.25, 0.35)],
    // Tres notas ascendentes: meta o fin de los intervalos.
    'meta': [
      ..._nota(523.25, 0.2),
      ..._nota(659.25, 0.2),
      ..._nota(783.99, 0.4),
    ],
  };
  Directory('assets/sonidos').createSync(recursive: true);
  tonos.forEach((nombre, muestras) {
    File('assets/sonidos/$nombre.wav').writeAsBytesSync(_wav(muestras));
    // ignore: avoid_print
    print('assets/sonidos/$nombre.wav (${muestras.length / _tasa} s)');
  });
}
