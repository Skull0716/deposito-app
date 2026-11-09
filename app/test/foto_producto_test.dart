import 'dart:typed_data';

import 'package:deposito_app/core/imagenes/foto_producto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _imagen(int ancho, int alto) {
  final imagen = img.Image(width: ancho, height: alto);
  img.fill(imagen, color: img.ColorRgb8(120, 70, 30));
  return Uint8List.fromList(img.encodePng(imagen));
}

void main() {
  group('reducirFotoProducto', () {
    test('baja una foto horizontal a 800 px de ancho', () {
      final reducida = reducirFotoProducto(_imagen(1600, 1200));

      expect(reducida, isNotNull);
      final decodificada = img.decodeJpg(reducida!)!;
      expect(decodificada.width, 800);
      expect(decodificada.height, 600);
    });

    test('baja una foto vertical a 800 px de alto', () {
      final reducida = reducirFotoProducto(_imagen(600, 1200));

      final decodificada = img.decodeJpg(reducida!)!;
      expect(decodificada.width, 400);
      expect(decodificada.height, 800);
    });

    test('no agranda una foto que ya es pequeña', () {
      final reducida = reducirFotoProducto(_imagen(400, 300));

      final decodificada = img.decodeJpg(reducida!)!;
      expect(decodificada.width, 400);
      expect(decodificada.height, 300);
    });

    test('un archivo que no es imagen regresa null', () {
      expect(reducirFotoProducto(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}
