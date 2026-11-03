import 'package:sqlite3/sqlite3.dart';

import '../comun/constantes.dart';

export '../comun/constantes.dart' show enMemoria;

/// Abre la base con la configuración del proyecto:
/// - WAL: lecturas y escritura al mismo tiempo, y menos riesgo de corrupción.
/// - Llaves foráneas activas (SQLite las trae apagadas).
/// - Espera hasta 5 s si la base está ocupada en vez de fallar al instante.
Database abrirBaseDatos(String ruta) {
  final db = ruta == enMemoria ? sqlite3.openInMemory() : sqlite3.open(ruta);
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('PRAGMA busy_timeout = 5000');
  db.execute('PRAGMA synchronous = NORMAL');
  return db;
}

/// Ejecuta [accion] completa o no la ejecuta (estándar: toda operación de
/// dinero o existencias pasa por aquí).
///
/// `BEGIN IMMEDIATE` toma el bloqueo de escritura al empezar, así dos ventas
/// simultáneas no pueden leer la misma existencia y descontarla dos veces.
T transaccion<T>(Database db, T Function() accion) {
  if (!db.autocommit) {
    throw StateError('Ya hay una transacción abierta; no se anidan');
  }
  db.execute('BEGIN IMMEDIATE');
  try {
    final resultado = accion();
    db.execute('COMMIT');
    return resultado;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

/// Bytes que ocupa la base (páginas por tamaño de página; sirve también en
/// memoria).
int tamanoBaseDatos(Database db) =>
    db
            .select(
              'SELECT page_count * page_size AS b '
              'FROM pragma_page_count(), pragma_page_size()',
            )
            .first['b']
        as int;
