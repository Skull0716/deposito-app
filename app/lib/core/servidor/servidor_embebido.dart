import 'dart:io';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Carga los productos del prototipo la primera vez. Se apaga antes de la
/// entrega al cliente (Sprint 5), cuando se cargue su inventario real.
const cargarDatosEjemplo = false;

const puertoServidor = 8080;

/// El servidor que corre dentro de la app en modo Caja.
///
/// Arranca la primera vez que alguien lo lee y se detiene si el provider se
/// descarta (por ejemplo, al cambiar a modo Terminal).
final servidorEmbebidoProvider = FutureProvider<DepositoServer>((ref) async {
  if (kIsWeb) {
    final servidor = DepositoServer(
      rutaBaseDatos: ':memory:',
      puerto: puertoServidor,
      datosEjemplo: cargarDatosEjemplo,
      fotosEjemplo: await _leerFotosEjemplo(),
    );
    await servidor.iniciar();
    ref.onDispose(servidor.detener);
    return servidor;
  }

  final carpeta = await carpetaCaja();
  final servidor = DepositoServer(
    rutaBaseDatos: rutaBaseDatosCaja(carpeta),
    puerto: puertoServidor,
    datosEjemplo: cargarDatosEjemplo,
    fotosEjemplo: await _leerFotosEjemplo(),
    bitacora: Bitacora(rutaArchivo: '${carpeta.path}/anaquel.log'),
  );
  await servidor.iniciar();
  ref.onDispose(servidor.detener);
  return servidor;
}, retry: (_, _) => null);

/// Carpeta de la caja en los documentos del dispositivo: base, fotos, log y
/// respaldos.
Future<Directory> carpetaCaja() async {
  final documentos = await getApplicationDocumentsDirectory();
  return Directory('${documentos.path}/anaquel')..createSync(recursive: true);
}

/// La base de la caja dentro de [carpeta].
String rutaBaseDatosCaja(Directory carpeta) => '${carpeta.path}/anaquel.db';

/// Fotos de los productos de ejemplo, desde los assets de la app.
Future<Map<String, Uint8List>> _leerFotosEjemplo() async {
  if (!cargarDatosEjemplo) return const {};
  return {
    for (final archivo in fotosDeEjemplo.values.toSet())
      archivo: (await rootBundle.load('$carpetaFotosEjemplo/$archivo')).buffer
          .asUint8List(),
  };
}

/// IP de este dispositivo en la Wi-Fi, para el QR de emparejamiento.
final direccionLocalProvider = FutureProvider<String?>(
  (ref) => direccionLocal(),
);

Future<String?> direccionLocal() async {
  if (kIsWeb) return '127.0.0.1';
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final candidatas = [
      for (final i in interfaces)
        for (final d in i.addresses)
          if (!d.isLoopback && !d.isLinkLocal)
            (interfaz: i.name, ip: d.address),
    ];
    if (candidatas.isEmpty) return null;
    // Preferir la Wi-Fi (wlan0 en Android, en0 en iOS) y redes privadas.
    int puntaje(({String interfaz, String ip}) c) =>
        (c.interfaz.startsWith('wlan') || c.interfaz == 'en0' ? 2 : 0) +
        (c.ip.startsWith('192.168.') || c.ip.startsWith('10.') ? 1 : 0);
    candidatas.sort((a, b) => puntaje(b).compareTo(puntaje(a)));
    return candidatas.first.ip;
  } catch (_) {
    return '127.0.0.1';
  }
}
