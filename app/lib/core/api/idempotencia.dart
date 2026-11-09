import 'dart:math';

final _aleatorio = Random.secure();

/// Clave para `X-Clave-Idempotencia`: se genera una por operación de dinero
/// y se reutiliza si se reintenta, para que el servidor no la repita.
String nuevaClaveIdempotencia() => [
  for (var i = 0; i < 4; i++)
    _aleatorio.nextInt(0x7fffffff).toRadixString(36).padLeft(7, '0'),
].join('-');
