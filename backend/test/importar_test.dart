import 'package:deposito_backend/deposito_backend.dart';
import 'package:deposito_backend/src/comun/csv.dart';
import 'package:deposito_backend/src/comun/errores.dart';
import 'package:deposito_backend/src/db/base_datos.dart';
import 'package:deposito_backend/src/db/migraciones.dart';
import 'package:deposito_backend/src/db/repositorio_productos.dart';
import 'package:deposito_backend/src/servicios/servicio_productos.dart';
import 'package:deposito_backend/src/ws/hub.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'ayudantes/servidor_prueba.dart';

const _encabezado =
    'codigo,nombre,categoria,presentacion,precio,precioCaja,piezasPorCaja,'
    'existencia,minimo,envase,caducidad';

void main() {
  group('leerCsv', () {
    test('comillas, comillas dobles, saltos dentro de celdas y CRLF', () {
      final r = leerCsv('a,b\r\n"x, ""y""","dos\nlíneas"\r\n3,4');
      expect(
        [for (final x in r) x.celdas],
        [
          ['a', 'b'],
          ['x, "y"', 'dos\nlíneas'],
          ['3', '4'],
        ],
      );
      // El renglón de cada registro es donde empieza, como en Excel.
      expect([for (final x in r) x.renglon], [1, 2, 4]);
    });

    test('quita el BOM y usa ; si el encabezado no tiene comas', () {
      final r = leerCsv('﻿codigo;precio\n1;42,50\n');
      expect(r.first.celdas, ['codigo', 'precio']);
      expect(r.last.celdas, ['1', '42,50']);
    });

    test('una comilla sin cerrar es FormatException', () {
      expect(() => leerCsv('a\n"abierta'), throwsFormatException);
    });
  });

  group('centavosDePesos', () {
    test('acepta como lo escribe una persona, sin double', () {
      expect(centavosDePesos('42'), 4200);
      expect(centavosDePesos('42.5'), 4250);
      expect(centavosDePesos(r'$1,234.50'), 123450);
      expect(centavosDePesos(' 0.10 '), 10);
      expect(centavosDePesos('19.99'), 1999);
    });

    test('rechaza coma decimal y formatos raros', () {
      for (final t in ['42,50', '42,5', '1,23', '4.255', 'abc', '-3', '']) {
        expect(centavosDePesos(t), isNull, reason: t);
      }
    });
  });

  group('leerInventario', () {
    test('encabezados sin distinguir mayúsculas, acentos ni espacios', () {
      final r = leerInventario(
        'Código,NOMBRE,Categoría,Precio Caja,piezas_por_caja,Precio\n'
        '1,A,cerveza,480,12,42\n',
      );
      expect(r.single.valores, {
        'codigo': '1',
        'nombre': 'A',
        'categoria': 'cerveza',
        'precioCaja': 48000,
        'piezasPorCaja': 12,
        'precio': 4200,
      });
    });

    test('convierte DD/MM/AAAA, ignora renglones vacíos y celdas vacías', () {
      final r = leerInventario(
        'codigo,nombre,categoria,precio,caducidad,envase\n'
        '\n'
        '1,A,cerveza,42,5/3/2027,MEGA\n'
        ',,,,,\n'
        '2,B,botana,10,,\n',
      );
      expect(r.map((x) => x.renglon), [3, 5]);
      expect(r.first.valores['caducidad'], '2027-03-05');
      expect(r.first.valores['envase'], 'mega');
      expect(r.last.valores.containsKey('caducidad'), isFalse);
    });

    test('marca las celdas que no se pueden leer', () {
      final r = leerInventario(
        'codigo,nombre,categoria,precio,existencia,minimo\n'
        '1,A,cerveza,42,x,-1,2.5\n',
      );
      expect(r.single.errores.keys.toSet(), {'existencia', 'csv'});
      // Un entero negativo sí se lee: la validación de Crear lo rechaza.
      expect(r.single.valores['minimo'], -1);
    });

    test('errores del archivo entero', () {
      for (final (csv, motivo) in [
        ('', 'vacío'),
        ('codigo,nombre,categoria\n', 'Faltan las columnas: precio'),
        ('$_encabezado,color\n', 'No se conoce la columna "color"'),
        ('codigo,Código,nombre,categoria,precio\n', 'viene dos veces'),
      ]) {
        expect(
          () => leerInventario(csv),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(motivo),
            ),
          ),
          reason: csv,
        );
      }
    });

    test('más de 5000 renglones es error', () {
      final csv = StringBuffer('codigo,nombre,categoria,precio\n');
      for (var i = 0; i <= maxRenglonesCsv; i++) {
        csv.writeln('$i,P,cerveza,1');
      }
      expect(() => leerInventario(csv.toString()), throwsFormatException);
    });
  });

  group('ServicioProductos.importar', () {
    late Database db;
    late ServicioProductos servicio;
    final ahora = DateTime.utc(2026, 10, 28, 18);

    setUp(() {
      db = abrirBaseDatos(enMemoria);
      aplicarMigraciones(db);
      servicio = ServicioProductos(
        db: db,
        repositorio: RepositorioProductos(db),
        hub: Hub(version: 'prueba', bitacora: Bitacora.silenciosa()),
        reloj: () => ahora,
      );
    });
    tearDown(() => db.close());

    ResultadoImportacion importar(String csv, {bool soloRevisar = false}) =>
        servicio.importar({
          'csv': csv,
          'soloRevisar': soloRevisar,
        }, origen: 'Caja');

    List<Row> movimientos() => db.select(
      'SELECT p.codigo, m.tipo, m.piezas, m.existencia_resultante, m.nota '
      'FROM movimientos m JOIN productos p ON p.id = m.producto_id ORDER BY m.id',
    );

    const plantilla =
        '$_encabezado\n'
        '7501064191015,Victoria Mega,cerveza,Mega 1.2 L,42.00,480.00,12,66,36,mega,2027-01-29\n'
        '7501055300846,Coca-Cola,refresco,600 ml,18.50,,,24,12,,\n'
        '7501011143258,Bolsa de hielo,hielo,5 kg,35,,,,5,,\n';

    test('crea los productos con su existencia inicial como movimiento', () {
      final r = importar(plantilla);
      expect(r.guardado, isTrue);
      expect((r.creados, r.actualizados, r.sinCambios), (3, 0, 0));
      expect(r.errores, isEmpty);

      final victoria = servicio.porCodigo('7501064191015');
      expect(victoria.precio, 4200);
      expect(victoria.precioCaja, 48000);
      expect(victoria.existenciaPiezas, 66);
      expect(victoria.caducidad, '2027-01-29');
      expect(victoria.creado, '2026-10-28T18:00:00Z');
      expect(servicio.porCodigo('7501011143258').existenciaPiezas, 0);

      expect(
        [
          for (final m in movimientos())
            (m['codigo'], m['tipo'], m['piezas'], m['nota']),
        ],
        [
          ('7501064191015', 'inicial', 66, 'Importación CSV'),
          ('7501055300846', 'inicial', 24, 'Importación CSV'),
        ],
      );
    });

    test('soloRevisar dice lo mismo pero no guarda nada', () {
      final r = importar(plantilla, soloRevisar: true);
      expect(r.guardado, isFalse);
      expect(r.creados, 3);
      expect(servicio.listar(), isEmpty);
      expect(movimientos(), isEmpty);
    });

    test(
      'un producto que existe: fija la existencia y solo cambia lo que trae',
      () {
        importar(plantilla);
        final antes = servicio.porCodigo('7501064191015');

        final r = importar(
          'codigo,nombre,categoria,precio,existencia\n'
          '7501064191015,Victoria Mega,cerveza,45,80\n'
          '7501055300846,Coca-Cola,refresco,18.50,\n'
          '7501011143258,Bolsa de hielo,hielo,35,0\n',
        );
        expect((r.creados, r.actualizados, r.sinCambios), (0, 1, 2));
        expect(r.cambiosExistencia.single.toJson(), {
          'renglon': 2,
          'codigo': '7501064191015',
          'nombre': 'Victoria Mega',
          'antes': 66,
          'despues': 80,
        });

        final despues = servicio.porCodigo('7501064191015');
        expect(despues.id, antes.id);
        expect(despues.precio, 4500);
        expect(despues.existenciaPiezas, 80);
        // Las columnas que no vienen no cambian.
        expect(despues.precioCaja, 48000);
        expect(despues.minimo, 36);
        expect(despues.caducidad, '2027-01-29');
        expect(despues.presentacion, 'Mega 1.2 L');

        final ultimo = movimientos().last;
        expect(ultimo['tipo'], 'ajuste');
        expect(ultimo['piezas'], 14);
        expect(ultimo['existencia_resultante'], 80);
      },
    );

    test('con un renglón con error no guarda ninguno y dice cuál', () {
      final r = importar(
        '$_encabezado\n'
        '1,Bien,cerveza,,42,,,5,,,\n'
        '2,Precio malo,cerveza,,42,50,,5,,,\n'
        '3,Envase raro,cerveza,,42,,,5,,litro,\n'
        '1,Repetido,cerveza,,42,,,5,,,\n'
        ',Sin código,cerveza,,42,,,,,,\n'
        '6,Sin caja,cerveza,,42,480,,,,,31/02/2027\n',
      );
      expect(r.guardado, isFalse);
      expect(servicio.listar(), isEmpty);
      expect(
        {for (final e in r.errores) e.renglon: e.campos.keys.toSet()},
        {
          3: {'piezasPorCaja'}, // "42,50" sin comillas corre las columnas
          4: {'envase'},
          5: {'codigo'},
          6: {'codigo'},
          7: {'piezasPorCaja', 'caducidad'},
        },
      );
      expect(r.errores[2].campos['codigo'], contains('renglón 2'));
      expect(r.errores[3].codigo, isNull);
    });

    test('un archivo que no se puede leer es datos_invalidos en csv', () {
      for (final datos in <Map<String, Object?>>[
        {'csv': 'codigo,nombre\n1,A', 'soloRevisar': true},
        {'csv': '', 'soloRevisar': true},
        {'csv': plantilla},
        {'csv': 'x' * (maxCaracteresCsv + 1), 'soloRevisar': true},
      ]) {
        expect(
          () => servicio.importar(datos, origen: 'Caja'),
          throwsA(
            isA<ErrorApi>().having(
              (e) => e.codigo,
              'codigo',
              'datos_invalidos',
            ),
          ),
        );
      }
    });

    test('ignora productos eliminados: el código se vuelve a crear', () {
      final id = servicio.crear(productoValido(), origen: 'Caja').id;
      servicio.eliminar(id);
      final r = importar(
        'codigo,nombre,categoria,precio\n7501064191015,Victoria,cerveza,42\n',
      );
      expect(r.creados, 1);
      expect(servicio.porCodigo('7501064191015').id, isNot(id));
    });
  });
}
