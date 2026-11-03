import 'dart:io';

import 'fechas.dart';

enum NivelLog { info, advertencia, error }

/// Log del servidor: una línea por evento, en consola y opcionalmente en un
/// archivo que rota al pasar de [tamanoMaximo] y conserva [archivosRotados]
/// copias (`anaquel.log.1`, `.2`...). El archivo se puede exportar desde la
/// pantalla de Diagnóstico para dar soporte remoto.
class Bitacora {
  Bitacora({
    this.rutaArchivo,
    this.consola = true,
    this.tamanoMaximo = 1024 * 1024,
    this.archivosRotados = 3,
    this._reloj = relojSistema,
  });

  /// Bitácora que no escribe nada (pruebas).
  Bitacora.silenciosa({Reloj reloj = relojSistema})
    : this(consola: false, reloj: reloj);

  final String? rutaArchivo;
  final bool consola;
  final int tamanoMaximo;
  final int archivosRotados;
  final Reloj _reloj;

  /// Últimos errores en memoria, para la pantalla de Diagnóstico.
  final ultimosErrores = <String>[];

  void info(String mensaje) => _escribir(NivelLog.info, mensaje);

  void advertencia(String mensaje) => _escribir(NivelLog.advertencia, mensaje);

  void error(String mensaje, [Object? error, StackTrace? pila]) {
    final detalle = [mensaje, ?error?.toString(), ?pila?.toString()].join('\n');
    _escribir(NivelLog.error, detalle);
    ultimosErrores.add(
      '${instanteIso(_reloj())} $mensaje${error == null ? '' : ': $error'}',
    );
    if (ultimosErrores.length > 50) ultimosErrores.removeAt(0);
  }

  /// El log completo, de la copia rotada más vieja al archivo actual. Vacío
  /// si no se escribe a archivo.
  String exportar() {
    final ruta = rutaArchivo;
    if (ruta == null) return '';
    final texto = StringBuffer();
    for (final r in [
      for (var i = archivosRotados; i >= 1; i--) '$ruta.$i',
      ruta,
    ]) {
      final archivo = File(r);
      if (archivo.existsSync()) texto.write(archivo.readAsStringSync());
    }
    return texto.toString();
  }

  void _escribir(NivelLog nivel, String mensaje) {
    final linea =
        '${instanteIso(_reloj())} ${nivel.name.toUpperCase()} $mensaje';
    if (consola) stdout.writeln(linea);
    final ruta = rutaArchivo;
    if (ruta == null) return;
    try {
      final archivo = File(ruta);
      if (archivo.existsSync() && archivo.lengthSync() > tamanoMaximo) {
        _rotar(ruta);
      }
      archivo.writeAsStringSync(
        '$linea\n',
        mode: FileMode.append,
        flush: false,
      );
    } on FileSystemException catch (e) {
      // Un log que falla no debe tumbar una venta.
      if (consola) stderr.writeln('No se pudo escribir el log: $e');
    }
  }

  void _rotar(String ruta) {
    for (var i = archivosRotados - 1; i >= 1; i--) {
      final anterior = File('$ruta.$i');
      if (anterior.existsSync()) anterior.renameSync('$ruta.${i + 1}');
    }
    File(ruta).renameSync('$ruta.1');
    final sobrante = File('$ruta.${archivosRotados + 1}');
    if (sobrante.existsSync()) sobrante.deleteSync();
  }
}
