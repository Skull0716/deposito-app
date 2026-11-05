import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../api/api.dart';
import '../servidor/servidor_embebido.dart';
import '../textos.dart';

/// Cuántos respaldos guarda el iPad; los más viejos se borran.
const maximoRespaldos = 30;

/// `respaldos/` junto a la base (donde el servidor guarda también los de
/// antes de migrar).
Future<Directory> carpetaRespaldos() async =>
    Directory('${(await carpetaCaja()).path}/respaldos')
      ..createSync(recursive: true);

/// Respaldos guardados en el iPad, del más nuevo al más viejo.
Future<List<File>> respaldosLocales() async {
  final carpeta = await carpetaRespaldos();
  final archivos = [
    for (final f in carpeta.listSync())
      if (f is File && f.path.endsWith('.db')) f,
  ]..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return archivos;
}

/// Descarga el respaldo del servidor y lo guarda en el iPad. Deja solo los
/// últimos [maximoRespaldos].
Future<File> guardarRespaldo(Api api) async {
  final copia = await api.descargarRespaldo();
  final carpeta = await carpetaRespaldos();
  final archivo = File('${carpeta.path}/${copia.nombre}')
    ..writeAsBytesSync(copia.bytes, flush: true);
  final todos = await respaldosLocales();
  for (final viejo in todos.skip(maximoRespaldos)) {
    viejo.deleteSync();
  }
  return archivo;
}

/// Hoja de compartir del sistema (AirDrop, Guardar en Archivos, WhatsApp...).
Future<void> compartirRespaldo(File archivo) => SharePlus.instance.share(
  ShareParams(
    files: [XFile(archivo.path, mimeType: 'application/vnd.sqlite3')],
    subject: Textos.respaldoDeAnaquel,
  ),
);
