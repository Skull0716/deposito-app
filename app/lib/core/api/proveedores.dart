import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/configuracion.dart';
import '../servidor/servidor_embebido.dart';
import '../textos.dart';
import 'api.dart';
import 'api_falsa.dart';
import 'fallo_api.dart';

/// La [Api] según el modo del dispositivo:
/// - En Web: ApiFalsa con catálogo precargado para desarrollo y demo en navegador.
/// - Caja: el servidor embebido, en `localhost`, con la clave de caja.
/// - Terminal: la IP de la caja, con la clave que recibió al registrarse.
///
/// En pruebas se sobrescribe con `ApiFalsa`.
final apiProvider = FutureProvider<Api>((ref) async {
  if (kIsWeb) {
    return ApiFalsa(productos: productosDeDemo());
  }
  final config = ref.watch(configuracionProvider);
  switch (config.modo) {
    case ModoDispositivo.caja:
      final servidor = await ref.watch(servidorEmbebidoProvider.future);
      return ApiHttp(
        base: Uri.parse('http://127.0.0.1:${servidor.puertoActual}'),
        clave: servidor.claveCaja,
      );
    case ModoDispositivo.terminal:
      final c = config.conexion;
      if (c == null) {
        throw const FalloApi('sin_conexion', Textos.terminalNoVinculada);
      }
      return ApiHttp(
        base: Uri(scheme: 'http', host: c.host, port: c.puerto),
        clave: c.clave,
      );
    case null:
      throw StateError('Elige un modo antes de usar la API');
  }
}, retry: (_, _) => null);
