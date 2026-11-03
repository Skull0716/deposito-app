import 'dart:io';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:deposito_backend/src/db/base_datos.dart';
import 'package:deposito_backend/src/db/migraciones.dart';
import 'package:deposito_backend/src/servicios/servicio_diagnostico.dart';
import 'package:deposito_backend/src/ws/hub.dart';
import 'package:test/test.dart';

void main() {
  final ahora = DateTime.utc(2026, 11, 3, 18, 30, 5);
  DateTime reloj() => ahora;

  group('Bitacora.exportar', () {
    late Directory carpeta;

    setUp(() => carpeta = Directory.systemTemp.createTempSync('anaquel_log_'));
    tearDown(() => carpeta.deleteSync(recursive: true));

    test('sin archivo regresa vacío', () {
      expect(Bitacora.silenciosa().exportar(), isEmpty);
    });

    test('junta las copias rotadas, de la más vieja a la actual', () {
      final ruta = '${carpeta.path}/anaquel.log';
      final bitacora = Bitacora(
        rutaArchivo: ruta,
        consola: false,
        tamanoMaximo: 10,
        archivosRotados: 2,
        reloj: reloj,
      );
      for (final m in ['uno', 'dos', 'tres', 'cuatro']) {
        bitacora.info(m);
      }

      final lineas = bitacora.exportar().trim().split('\n');
      // Con 2 copias, la primera línea ya se descartó.
      expect(lineas.map((l) => l.split(' ').last), ['dos', 'tres', 'cuatro']);
      expect(lineas.first, '2026-11-03T18:30:05Z INFO dos');
    });
  });

  group('ServicioDiagnostico', () {
    test('reporta versión, arranque, esquema, base y errores', () {
      final db = abrirBaseDatos(enMemoria);
      addTearDown(db.close);
      aplicarMigraciones(db);
      final bitacora = Bitacora.silenciosa(reloj: reloj)
        ..error('primero')
        ..error('segundo', StateError('falló'));
      final servicio = ServicioDiagnostico(
        db: db,
        hub: Hub(version: '9.9.9', bitacora: bitacora),
        bitacora: bitacora,
        iniciado: DateTime.utc(2026, 11, 3, 12),
        reloj: reloj,
      );

      final d = servicio.leer();
      expect(d.version, '9.9.9');
      expect(d.iniciado, '2026-11-03T12:00:00Z');
      expect(d.esquema, migraciones.last.numero);
      expect(d.bytesBaseDatos, greaterThan(0));
      expect(d.conexiones, 0);
      expect(d.terminalesConectadas, 0);
      expect(d.ultimosErrores, [
        '2026-11-03T18:30:05Z segundo: Bad state: falló',
        '2026-11-03T18:30:05Z primero',
      ]);
      expect(Diagnostico.fromJson(d.toJson()).toJson(), d.toJson());
    });

    test('nombra el log con la fecha', () {
      final db = abrirBaseDatos(enMemoria);
      addTearDown(db.close);
      final bitacora = Bitacora.silenciosa();
      final servicio = ServicioDiagnostico(
        db: db,
        hub: Hub(version: 'prueba', bitacora: bitacora),
        bitacora: bitacora,
        iniciado: ahora,
        reloj: reloj,
      );
      expect(servicio.bitacora().nombre, 'anaquel-20261103-183005.log');
    });
  });
}
