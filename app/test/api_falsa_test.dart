import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/core/api/fallo_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// La API falsa debe comportarse como el contrato en lo que las pantallas
/// necesitan para programarse sin el servidor.
void main() {
  group('importarProductos', () {
    const csv =
        'codigo,nombre,categoria,precio,existencia\n'
        '7500000000001,Producto nuevo,botana,12.50,3\n';

    test('soloRevisar no guarda; sin él crea el producto', () async {
      final api = ApiFalsa();
      final antes = api.productos.length;

      final revision = await api.importarProductos(csv, soloRevisar: true);
      expect((revision.guardado, revision.creados), (false, 1));
      expect(api.productos, hasLength(antes));

      final r = await api.importarProductos(csv, soloRevisar: false);
      expect(r.guardado, isTrue);
      final nuevo = api.productos.last;
      expect(
        (nuevo.nombre, nuevo.precio, nuevo.existenciaPiezas),
        ('Producto nuevo', 1250, 3),
      );
    });

    test('con errores no guarda y dice el renglón', () async {
      final api = ApiFalsa();
      final antes = api.productos.length;
      final r = await api.importarProductos(
        '${csv}7500000000002,Sin precio,botana,,1\n',
        soloRevisar: false,
      );
      expect(r.guardado, isFalse);
      expect(r.errores.single.renglon, 3);
      expect(r.errores.single.campos.keys, ['precio']);
      expect(api.productos, hasLength(antes));
    });

    test('un archivo sin columnas obligatorias es datos_invalidos', () {
      expect(
        ApiFalsa().importarProductos('codigo\n1', soloRevisar: true),
        throwsA(
          isA<FalloApi>().having((f) => f.codigo, 'codigo', 'datos_invalidos'),
        ),
      );
    });
  });
}
