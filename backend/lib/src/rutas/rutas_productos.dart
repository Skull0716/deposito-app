import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../comun/json.dart';
import '../comun/sesion.dart';
import '../modelos/importacion.dart';
import '../servicios/servicio_productos.dart';

/// Las rutas solo leen la petición y responden; la lógica está en el servicio.
void montarRutasProductos(Router r, ServicioProductos productos) {
  r.get('/api/v1/productos', (Request p) {
    final q = p.url.queryParameters;
    final lista = productos.listar(busqueda: q['q'], categoria: q['categoria']);
    return respuestaJson({
      'productos': [for (final x in lista) x.toJson()],
    });
  });

  r.get('/api/v1/productos/codigo/<codigo>', (Request p, String codigo) {
    return respuestaJson(productos.porCodigo(codigo).toJson());
  });

  r.get('/api/v1/productos/<id>', (Request p, String id) {
    return respuestaJson(productos.obtener(id).toJson());
  });

  r.post('/api/v1/productos', (Request p) async {
    final sesion = exigirCaja(p);
    final producto = productos.crear(
      await leerObjetoJson(p),
      origen: sesion.nombre,
    );
    return respuestaJson(producto.toJson(), estado: 201);
  });

  r.post('/api/v1/productos/importar', (Request p) async {
    final sesion = exigirCaja(p);
    final datos = await leerObjetoJsonHasta(
      p,
      // El CSV viaja dentro de un JSON: escapar comillas y saltos lo crece.
      max: maxCaracteresCsv * 2,
      campo: 'csv',
    );
    return respuestaJson(
      productos.importar(datos, origen: sesion.nombre).toJson(),
    );
  });

  r.put('/api/v1/productos/<id>', (Request p, String id) async {
    exigirCaja(p);
    final producto = productos.editar(id, await leerObjetoJson(p));
    return respuestaJson(producto.toJson());
  });

  r.delete('/api/v1/productos/<id>', (Request p, String id) {
    exigirCaja(p);
    productos.eliminar(id);
    return Response(204);
  });

  r.post('/api/v1/productos/<id>/entradas', (Request p, String id) async {
    final sesion = exigirCaja(p);
    final producto = productos.registrarEntrada(
      id,
      await leerObjetoJson(p),
      origen: sesion.nombre,
    );
    return respuestaJson(producto.toJson());
  });

  r.post('/api/v1/productos/<id>/ajustes', (Request p, String id) async {
    final sesion = exigirCaja(p);
    final producto = productos.ajustar(
      id,
      await leerObjetoJson(p),
      origen: sesion.nombre,
    );
    return respuestaJson(producto.toJson());
  });

  r.get('/api/v1/productos/<id>/movimientos', (Request p, String id) {
    return respuestaJson({
      'movimientos': [for (final m in productos.movimientos(id)) m.toJson()],
    });
  });

  r.get('/api/v1/productos/<id>/foto', (Request p, String id) {
    final foto = productos.leerFoto(id);
    return Response.ok(
      foto.bytes,
      headers: {
        'content-type': foto.tipo,
        // La URL cambia con cada foto nueva (?v=), así que se puede guardar.
        'cache-control': 'private, max-age=31536000, immutable',
      },
    );
  });

  r.put('/api/v1/productos/<id>/foto', (Request p, String id) async {
    exigirCaja(p);
    final bytes = await leerBytes(p, max: maxBytesFoto, campo: 'foto');
    final producto = productos.guardarFoto(
      id,
      p.headers['content-type'],
      bytes,
    );
    return respuestaJson(producto.toJson());
  });

  r.delete('/api/v1/productos/<id>/foto', (Request p, String id) {
    exigirCaja(p);
    return respuestaJson(productos.borrarFoto(id).toJson());
  });
}
