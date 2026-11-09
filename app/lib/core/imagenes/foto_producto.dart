import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Lado máximo de la foto que se sube al servidor. 800 px alcanza para verla
/// en el iPad y en la terminal sin mandar varios megabytes por la Wi-Fi.
const ladoMaximoFoto = 800;

/// Reduce y vuelve a codificar la foto como JPEG. Regresa `null` si el
/// archivo no es una imagen que se pueda leer.
///
/// El servidor acepta JPEG, PNG y WebP de hasta 5 MB; mandar siempre JPEG
/// reducido mantiene la foto ligera y dentro del límite.
Uint8List? reducirFotoProducto(
  Uint8List original, {
  int lado = ladoMaximoFoto,
}) {
  final img.Image? imagen;
  try {
    imagen = img.decodeImage(original);
  } on Object {
    // Algunos decodificadores lanzan con archivos truncados en vez de
    // regresar null.
    return null;
  }
  if (imagen == null) return null;
  final reducida = imagen.width <= lado && imagen.height <= lado
      ? imagen
      : imagen.width >= imagen.height
      ? img.copyResize(
          imagen,
          width: lado,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          imagen,
          height: lado,
          interpolation: img.Interpolation.average,
        );
  return Uint8List.fromList(img.encodeJpg(reducida, quality: 82));
}
