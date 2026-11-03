import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import 'ayudantes/servidor_prueba.dart';

/// Pruebas e2e: servidor real en un puerto libre, como lo usará la app.
void main() {
  late ServidorPrueba s;

  setUp(() async => s = await crearServidorDePrueba());
  tearDown(() => s.cerrar());

  group('salud y errores generales', () {
    test('GET /salud responde ok sin clave', () async {
      final r = await s.get('/salud', clave: '');
      expect(r.statusCode, 200);
      expect(r.body, 'ok');
    });

    test('sin clave responde 401 con el formato del contrato', () async {
      final r = await s.get('/api/v1/productos', clave: '');
      expect(r.statusCode, 401);
      expect(codigoError(r), 'no_autorizado');
      expect(r.headers['content-type'], contains('application/json'));
    });

    test('una clave inventada es 401', () async {
      final r = await s.get('/api/v1/productos', clave: 'inventada');
      expect(r.statusCode, 401);
    });

    test('una ruta que no existe es 404 no_encontrado', () async {
      final r = await s.get('/api/v1/nada');
      expect(r.statusCode, 404);
      expect(codigoError(r), 'no_encontrado');
    });

    test('un cuerpo que no es JSON es 400 json_invalido', () async {
      final r = await s.post('/api/v1/productos', '{no es json');
      expect(r.statusCode, 400);
      expect(codigoError(r), 'json_invalido');
    });
  });

  group('productos', () {
    test('la caja crea, consulta y lista', () async {
      final creado = await s.post('/api/v1/productos', productoValido());
      expect(creado.statusCode, 201);
      final id = json(creado)['id'];

      final detalle = await s.get('/api/v1/productos/$id');
      expect(detalle.statusCode, 200);
      expect(json(detalle)['precio'], 4200);

      final lista = json(await s.get('/api/v1/productos?q=victoria'));
      expect((lista['productos'] as List).single['id'], id);
    });

    test('datos_invalidos dice qué campo falló', () async {
      final r = await s.post(
        '/api/v1/productos',
        productoValido({'precio': 42.5}),
      );
      expect(r.statusCode, 400);
      expect(codigoError(r), 'datos_invalidos');
      expect((json(r)['error'] as Map)['campos'], contains('precio'));
    });

    test('código repetido es 409 codigo_duplicado', () async {
      await s.post('/api/v1/productos', productoValido());
      final r = await s.post('/api/v1/productos', productoValido());
      expect(r.statusCode, 409);
      expect(codigoError(r), 'codigo_duplicado');
    });

    test('una terminal consulta pero no crea', () async {
      final clave = await s.registrarTerminal();
      expect((await s.get('/api/v1/productos', clave: clave)).statusCode, 200);
      final r = await s.post(
        '/api/v1/productos',
        productoValido(),
        clave: clave,
      );
      expect(r.statusCode, 403);
      expect(codigoError(r), 'solo_caja');
    });
  });

  group('catálogo', () {
    Future<String> crear([Map<String, Object?> cambios = const {}]) async =>
        json(await s.post('/api/v1/productos', productoValido(cambios)))['id']
            as String;

    test('busca por código de barras exacto', () async {
      final id = await crear();
      final r = await s.get('/api/v1/productos/codigo/7501064191015');
      expect(r.statusCode, 200);
      expect(json(r)['id'], id);
      final parcial = await s.get('/api/v1/productos/codigo/750106');
      expect(parcial.statusCode, 404);
      expect(codigoError(parcial), 'no_encontrado');
    });

    test('la caja edita y la existencia no cambia', () async {
      final id = await crear();
      final r = await s.put(
        '/api/v1/productos/$id',
        productoValido({'precio': 4500, 'existenciaPiezas': 0}),
      );
      expect(r.statusCode, 200);
      expect(json(r)['precio'], 4500);
      expect(json(r)['existenciaPiezas'], 66);
    });

    test('eliminar responde 204 y luego 404', () async {
      final id = await crear();
      expect((await s.delete('/api/v1/productos/$id')).statusCode, 204);
      expect((await s.get('/api/v1/productos/$id')).statusCode, 404);
      expect((await s.delete('/api/v1/productos/$id')).statusCode, 404);
    });

    test('entradas, ajustes y su historial de movimientos', () async {
      final id = await crear();
      final entrada = await s.post('/api/v1/productos/$id/entradas', {
        'cajas': 1,
        'piezas': 2,
      });
      expect(entrada.statusCode, 200);
      expect(json(entrada)['existenciaPiezas'], 80);

      final merma = await s.post('/api/v1/productos/$id/ajustes', {
        'motivo': 'merma',
        'piezas': 100,
      });
      expect(merma.statusCode, 409);
      expect(codigoError(merma), 'stock_insuficiente');

      final conteo = await s.post('/api/v1/productos/$id/ajustes', {
        'motivo': 'conteo',
        'existenciaPiezas': 75,
      });
      expect(json(conteo)['existenciaPiezas'], 75);

      final m =
          json(await s.get('/api/v1/productos/$id/movimientos'))['movimientos']
              as List;
      expect(m.map((x) => (x as Map)['tipo']), [
        'ajuste',
        'entrada',
        'inicial',
      ]);
    });

    test('sube, sirve y borra la foto', () async {
      final id = await crear();
      final subida = await s.putBytes(
        '/api/v1/productos/$id/foto',
        pngPrueba,
        tipo: 'image/png',
      );
      expect(subida.statusCode, 200);
      final ruta = json(subida)['foto'] as String;
      expect(ruta, startsWith('/api/v1/productos/$id/foto?v='));

      final foto = await s.get(ruta);
      expect(foto.statusCode, 200);
      expect(foto.headers['content-type'], 'image/png');
      expect(foto.bodyBytes, pngPrueba);

      final borrada = await s.delete('/api/v1/productos/$id/foto');
      expect(json(borrada)['foto'], isNull);
      expect((await s.get(ruta)).statusCode, 404);
    });

    test('una foto que pasa de 5 MB es datos_invalidos', () async {
      final id = await crear();
      final r = await s.putBytes('/api/v1/productos/$id/foto', [
        ...pngPrueba,
        ...List.filled(5 * 1024 * 1024, 0),
      ], tipo: 'image/png');
      expect(r.statusCode, 400);
      expect(camposError(r), contains('foto'));
    });

    test('una terminal consulta pero no modifica el catálogo', () async {
      final id = await crear();
      final clave = await s.registrarTerminal();
      expect(
        (await s.get(
          '/api/v1/productos/codigo/7501064191015',
          clave: clave,
        )).statusCode,
        200,
      );
      expect(
        (await s.get(
          '/api/v1/productos/$id/movimientos',
          clave: clave,
        )).statusCode,
        200,
      );
      final intentos = [
        await s.put('/api/v1/productos/$id', productoValido(), clave: clave),
        await s.delete('/api/v1/productos/$id', clave: clave),
        await s.post('/api/v1/productos/$id/entradas', {
          'piezas': 1,
        }, clave: clave),
        await s.post('/api/v1/productos/$id/ajustes', {
          'motivo': 'merma',
          'piezas': 1,
        }, clave: clave),
        await s.putBytes(
          '/api/v1/productos/$id/foto',
          pngPrueba,
          tipo: 'image/png',
          clave: clave,
        ),
      ];
      for (final r in intentos) {
        expect(r.statusCode, 403, reason: r.request?.url.toString());
      }
    });
  });

  group('terminales', () {
    test('se empareja con el código del QR y su clave funciona', () async {
      final clave = await s.registrarTerminal('Terminal S24');
      expect(clave, hasLength(43));
      final lista = json(await s.get('/api/v1/terminales'));
      expect((lista['terminales'] as List).single['nombre'], 'Terminal S24');
      expect((await s.get('/api/v1/productos', clave: clave)).statusCode, 200);
    });

    test('un código sirve para una sola terminal', () async {
      final codigo = json(
        await s.post('/api/v1/terminales/codigo', null),
      )['codigo'];
      final cuerpo = {'nombre': 'A', 'codigo': codigo};
      expect(
        (await s.post(
          '/api/v1/terminales/registro',
          cuerpo,
          clave: '',
        )).statusCode,
        201,
      );
      final r = await s.post('/api/v1/terminales/registro', cuerpo, clave: '');
      expect(r.statusCode, 401);
      expect(codigoError(r), 'codigo_invalido');
    });

    test('cinco intentos fallidos invalidan el código', () async {
      final codigo =
          json(await s.post('/api/v1/terminales/codigo', null))['codigo']
              as String;
      final incorrecto = codigo == '000000' ? '111111' : '000000';
      for (var i = 0; i < 5; i++) {
        await s.post('/api/v1/terminales/registro', {
          'nombre': 'X',
          'codigo': incorrecto,
        }, clave: '');
      }
      final r = await s.post('/api/v1/terminales/registro', {
        'nombre': 'X',
        'codigo': codigo,
      }, clave: '');
      expect(r.statusCode, 401);
    });

    test(
      'una terminal no puede generar códigos ni listar terminales',
      () async {
        final clave = await s.registrarTerminal();
        expect(
          (await s.post(
            '/api/v1/terminales/codigo',
            null,
            clave: clave,
          )).statusCode,
          403,
        );
        expect(
          (await s.get('/api/v1/terminales', clave: clave)).statusCode,
          403,
        );
      },
    );

    test('revocar deja la clave sin efecto', () async {
      final clave = await s.registrarTerminal();
      final id =
          ((json(await s.get('/api/v1/terminales'))['terminales'] as List)
                  .single
              as Map)['id'];
      expect((await s.delete('/api/v1/terminales/$id')).statusCode, 204);
      expect((await s.get('/api/v1/productos', clave: clave)).statusCode, 401);
      expect((await s.delete('/api/v1/terminales/$id')).statusCode, 404);
    });
  });

  group('importar CSV', () {
    const csv =
        'codigo,nombre,categoria,precio,existencia,minimo\n'
        '7501064191015,Victoria Mega,cerveza,42.00,66,36\n'
        '7501055300846,Coca-Cola,refresco,18.50,24,12\n';

    test('revisa, guarda y responde con el formato del contrato', () async {
      final revisar = await s.post('/api/v1/productos/importar', {
        'csv': csv,
        'soloRevisar': true,
      });
      expect(revisar.statusCode, 200, reason: revisar.body);
      expect(json(revisar), {
        'guardado': false,
        'creados': 2,
        'actualizados': 0,
        'sinCambios': 0,
        'cambiosExistencia': <Object?>[],
        'errores': <Object?>[],
      });
      expect(json(await s.get('/api/v1/productos'))['productos'], isEmpty);

      final guardar = await s.post('/api/v1/productos/importar', {
        'csv': csv,
        'soloRevisar': false,
      });
      expect(json(guardar)['guardado'], isTrue);
      final productos = json(await s.get('/api/v1/productos'))['productos'];
      expect((productos as List).map((p) => (p as Map)['precio']), [
        1850,
        4200,
      ]);
    });

    test('una terminal no puede importar', () async {
      final clave = await s.registrarTerminal();
      final r = await s.post('/api/v1/productos/importar', {
        'csv': csv,
        'soloRevisar': true,
      }, clave: clave);
      expect(r.statusCode, 403);
      expect(codigoError(r), 'solo_caja');
    });

    test('un archivo sin columna obligatoria es 400 en csv', () async {
      final r = await s.post('/api/v1/productos/importar', {
        'csv': 'codigo,nombre\n1,A\n',
        'soloRevisar': true,
      });
      expect(r.statusCode, 400);
      expect(camposError(r), {'csv': 'Faltan las columnas: categoria, precio'});
    });
  });

  group('alertas', () {
    test(
      'una terminal lista las alertas con el formato del contrato',
      () async {
        final hoy = diaNegocio(
          DateTime.now().toUtc(),
          const Duration(hours: -6),
        );
        await s.post(
          '/api/v1/productos',
          productoValido({'existenciaPiezas': 0, 'minimo': 12}),
        );
        final clave = await s.registrarTerminal();

        final r = await s.get('/api/v1/alertas', clave: clave);
        expect(r.statusCode, 200);
        final cuerpo = json(r);
        expect(cuerpo['dia'], hoy);
        expect(cuerpo['dias'], 15);
        final alerta = (cuerpo['alertas'] as List).single as Map;
        expect(alerta.keys, ['tipo', 'producto', 'diasParaCaducar']);
        expect(alerta['tipo'], 'agotado');
        expect((alerta['producto'] as Map)['codigo'], '7501064191015');
      },
    );

    test('dias inválido es 400 datos_invalidos en dias', () async {
      final r = await s.get('/api/v1/alertas?dias=0');
      expect(r.statusCode, 400);
      expect(camposError(r).keys, ['dias']);
      expect((await s.get('/api/v1/alertas?dias=365')).statusCode, 200);
    });
  });

  group('WebSocket', () {
    Future<StreamIterator<Map<String, Object?>>> conectar(String clave) async {
      final canal = IOWebSocketChannel.connect(
        s.uri('/api/v1/ws').replace(scheme: 'ws'),
        headers: {'x-clave-terminal': clave},
      );
      await canal.ready;
      addTearDown(canal.sink.close);
      return StreamIterator(
        canal.stream.map(
          (m) => jsonDecode(m as String) as Map<String, Object?>,
        ),
      );
    }

    test(
      'saluda con conexion.lista y avisa cuando se crea un producto',
      () async {
        final clave = await s.registrarTerminal();
        final eventos = await conectar(clave);

        expect(await eventos.moveNext(), isTrue);
        expect(eventos.current['tipo'], 'conexion.lista');

        final terminales =
            json(await s.get('/api/v1/terminales'))['terminales'] as List;
        expect((terminales.single as Map)['conectada'], isTrue);

        await s.post('/api/v1/productos', productoValido());
        expect(await eventos.moveNext(), isTrue);
        expect(eventos.current['tipo'], 'producto.actualizado');
        expect(
          ((eventos.current['datos'] as Map)['producto'] as Map)['codigo'],
          '7501064191015',
        );
      },
    );

    test('avisa producto.eliminado con el id', () async {
      final clave = await s.registrarTerminal();
      final id = json(
        await s.post('/api/v1/productos', productoValido()),
      )['id'];
      final eventos = await conectar(clave);
      expect(await eventos.moveNext(), isTrue); // conexion.lista

      await s.delete('/api/v1/productos/$id');
      expect(await eventos.moveNext(), isTrue);
      expect(eventos.current['tipo'], 'producto.eliminado');
      expect(eventos.current['datos'], {'id': id});
    });

    test(
      'una venta que deja el producto bajo su mínimo avisa alerta.nueva',
      () async {
        final clave = await s.registrarTerminal();
        final id = json(
          await s.post(
            '/api/v1/productos',
            productoValido({'existenciaPiezas': 37, 'minimo': 36}),
          ),
        )['id'];
        await s.abrirCaja();
        final eventos = await conectar(clave);
        expect(await eventos.moveNext(), isTrue); // conexion.lista

        final venta = await s.post(
          '/api/v1/ventas',
          {
            'metodo': 'efectivo',
            'envModo': 'na',
            'lineas': [
              {'productoId': id, 'unidad': 'pieza', 'cantidad': 2},
            ],
          },
          cabeceras: {cabeceraIdempotencia: 'alerta-1'},
        );
        expect(venta.statusCode, 201, reason: venta.body);

        final tipos = <String>[];
        Map<String, Object?>? alerta;
        while (alerta == null && await eventos.moveNext()) {
          tipos.add(eventos.current['tipo'] as String);
          if (eventos.current['tipo'] == 'alerta.nueva') {
            alerta = ((eventos.current['datos'] as Map)['alerta'] as Map)
                .cast();
          }
        }
        expect(
          tipos.indexOf('producto.actualizado'),
          lessThan(tipos.length - 1),
        );
        expect(alerta!['tipo'], 'poco_stock');
        expect((alerta['producto'] as Map)['existenciaPiezas'], 35);
        expect(alerta['diasParaCaducar'], isNull);
      },
    );

    test('sin clave no conecta', () async {
      final canal = IOWebSocketChannel.connect(
        s.uri('/api/v1/ws').replace(scheme: 'ws'),
      );
      await expectLater(canal.ready, throwsA(anything));
    });
  });

  test(
    'con datos de ejemplo arranca con los productos del prototipo',
    () async {
      final conEjemplos = await crearServidorDePrueba(datosEjemplo: true);
      addTearDown(conEjemplos.cerrar);
      final lista =
          json(await conEjemplos.get('/api/v1/productos'))['productos'] as List;
      expect(lista, hasLength(12));
    },
  );

  test(
    'con datos de ejemplo los productos traen las fotos de la app',
    () async {
      final carpeta = '../app/$carpetaFotosEjemplo';
      final fotos = {
        for (final archivo in fotosDeEjemplo.values.toSet())
          archivo: File('$carpeta/$archivo').readAsBytesSync(),
      };
      final demo = await crearServidorDePrueba(
        datosEjemplo: true,
        fotosEjemplo: fotos,
      );
      addTearDown(demo.cerrar);

      final productos =
          json(await demo.get('/api/v1/productos'))['productos'] as List;
      final porCodigo = {
        for (final p in productos.cast<Map<String, Object?>>()) p['codigo']: p,
      };
      for (final codigo in fotosDeEjemplo.keys) {
        expect(porCodigo[codigo]!['foto'], isNotNull, reason: codigo);
      }
      expect(porCodigo['7502000000024']!['foto'], isNull, reason: 'Coca-Cola');

      final victoria = porCodigo['7501064191015']!;
      final foto = await demo.get(victoria['foto'] as String);
      expect(foto.statusCode, 200);
      expect(foto.headers['content-type'], 'image/webp');
      expect(foto.bodyBytes, fotos['victoria.webp']);
    },
  );
}
