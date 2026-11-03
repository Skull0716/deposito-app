import 'package:sqlite3/sqlite3.dart';

import '../comun/bitacora.dart';
import '../comun/fechas.dart';
import '../db/base_datos.dart';
import '../db/migraciones.dart';
import '../modelos/diagnostico.dart';
import '../ws/hub.dart';

/// Estado del servidor y su log, para dar soporte sin estar en el depósito.
class ServicioDiagnostico {
  ServicioDiagnostico({
    required this._db,
    required this._hub,
    required this._bitacora,
    required this.iniciado,
    this._reloj = relojSistema,
  });

  final Database _db;
  final Hub _hub;
  final Bitacora _bitacora;
  final Reloj _reloj;

  /// Cuándo arrancó el servidor.
  final DateTime iniciado;

  Diagnostico leer() => Diagnostico(
    version: _hub.version,
    iniciado: instanteIso(iniciado),
    esquema: versionEsquema(_db),
    bytesBaseDatos: tamanoBaseDatos(_db),
    conexiones: _hub.totalConexiones,
    terminalesConectadas: _hub.terminalesConectadas.length,
    ultimosErrores: _bitacora.ultimosErrores.reversed.toList(),
  );

  /// El log completo (con sus copias rotadas) y su nombre de archivo sugerido.
  ({String texto, String nombre}) bitacora() {
    final marca = instanteIso(_reloj())
        .replaceAll(RegExp('[-:]'), '')
        .replaceAll('T', '-')
        .replaceAll('Z', '');
    return (texto: _bitacora.exportar(), nombre: 'anaquel-$marca.log');
  }
}
