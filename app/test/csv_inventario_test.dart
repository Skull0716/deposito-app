import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/features/catalogo/datos/csv_inventario.dart';
import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el CSV exportado se puede volver a importar', () async {
    final originales = productosDePrueba();
    final csv = csvInventario(originales);

    expect(csv.startsWith('\uFEFFcodigo,nombre,categoria'), isTrue);

    final api = ApiFalsa(productos: []);
    final revision = await api.importarProductos(csv, soloRevisar: false);

    expect(revision.guardado, isTrue);
    expect(revision.creados, originales.length);
    expect(api.productos.length, originales.length);

    final original = originales.first;
    final copia = api.productos.firstWhere((p) => p.codigo == original.codigo);
    expect(copia.nombre, original.nombre);
    expect(copia.categoria, original.categoria);
    expect(copia.presentacion, original.presentacion);
    expect(copia.precio, original.precio);
    expect(copia.precioCaja, original.precioCaja);
    expect(copia.piezasPorCaja, original.piezasPorCaja);
    expect(copia.existenciaPiezas, original.existenciaPiezas);
    expect(copia.minimo, original.minimo);
    expect(copia.envase, original.envase);
    expect(copia.caducidad, original.caducidad);
  });

  test('las comillas y comas del nombre viajan entre comillas', () {
    final base = productosDePrueba().first;
    final raro = Producto.fromJson({
      ...base.toJson(),
      'nombre': 'Cerveza "Especial", grande',
    });

    final csv = csvInventario([raro]);

    expect(csv, contains('"Cerveza ""Especial"", grande"'));
  });
}
