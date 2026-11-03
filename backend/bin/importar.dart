import 'dart:io';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:deposito_backend/src/comun/errores.dart';
import 'package:deposito_backend/src/db/base_datos.dart';
import 'package:deposito_backend/src/db/migraciones.dart';
import 'package:deposito_backend/src/db/repositorio_productos.dart';
import 'package:deposito_backend/src/servicios/servicio_productos.dart';
import 'package:deposito_backend/src/ws/hub.dart';
import 'package:path/path.dart' as p;

const _uso = '''
Carga el inventario desde un CSV, con las mismas reglas que
POST /api/v1/productos/importar (docs/API.md).

  dart run bin/importar.dart inventario.csv [--base ruta.db] [--guardar]

  --base     Base de datos. Por omisión datos/anaquel.db.
  --guardar  Guarda los cambios. Sin esta opción solo revisa.

Detén el servidor antes de guardar. Para pasar la base al iPad, descarga un
respaldo de esta base y restáuralo al configurar la caja.
''';

Future<void> main(List<String> args) async {
  final archivos = args.where((a) => !a.startsWith('--')).toList();
  final iBase = args.indexOf('--base');
  final rutaBase = iBase >= 0 && iBase + 1 < args.length
      ? args[iBase + 1]
      : p.join('datos', 'anaquel.db');
  archivos.remove(rutaBase);
  if (archivos.length != 1 || args.contains('--ayuda')) {
    stdout.write(_uso);
    exit(archivos.length == 1 ? 0 : 64);
  }
  final guardar = args.contains('--guardar');

  Directory(p.dirname(rutaBase)).createSync(recursive: true);
  final db = abrirBaseDatos(rutaBase);
  try {
    aplicarMigraciones(db);
    final servicio = ServicioProductos(
      db: db,
      repositorio: RepositorioProductos(db),
      hub: Hub(version: versionServidor, bitacora: Bitacora.silenciosa()),
    );
    final r = servicio.importar({
      'csv': File(archivos.single).readAsStringSync(),
      'soloRevisar': !guardar,
    }, origen: 'Script de importación');

    stdout.writeln(
      '${r.creados} nuevos, ${r.actualizados} actualizados, '
      '${r.sinCambios} sin cambios.',
    );
    for (final c in r.cambiosExistencia) {
      stdout.writeln(
        '  Renglón ${c.renglon}: ${c.nombre} ${c.antes} → ${c.despues}',
      );
    }
    for (final e in r.errores) {
      stderr.writeln(
        '  Renglón ${e.renglon} (${e.codigo ?? 'sin código'}): '
        '${e.campos.entries.map((c) => '${c.key}: ${c.value}').join('; ')}',
      );
    }
    if (r.errores.isNotEmpty) {
      stderr.writeln('${r.errores.length} renglones con error. No se guardó.');
      exitCode = 1;
    } else if (r.guardado) {
      stdout.writeln('Guardado en $rutaBase.');
    } else {
      stdout.writeln('Solo se revisó. Usa --guardar para guardar.');
    }
  } on ErrorApi catch (e) {
    stderr.writeln(e.campos?.values.join('\n') ?? e.mensaje);
    exitCode = 1;
  } finally {
    db.close();
  }
}
