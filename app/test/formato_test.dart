import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/core/formato/formato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dinero', () {
    test('pesos enteros sin decimales', () => expect(dinero(4200), r'$42'));
    test('con centavos', () => expect(dinero(4250), r'$42.50'));
    test('un centavo', () => expect(dinero(1), r'$0.01'));
    test('miles con coma', () => expect(dinero(123456), r'$1,234.56'));
    test('millones', () => expect(dinero(123456700), r'$1,234,567'));
    test('negativos', () => expect(dinero(-4250), r'-$42.50'));
  });

  group('centavosDesdeTexto', () {
    test('lee pesos exactos sin pasar por double', () {
      expect(centavosDesdeTexto('42'), 4200);
      expect(centavosDesdeTexto('42.5'), 4250);
      expect(centavosDesdeTexto('42.50'), 4250);
      expect(centavosDesdeTexto(r'$1,234.56'), 123456);
      // 0.29 * 100 en double da 28.999999999999996.
      expect(centavosDesdeTexto('0.29'), 29);
    });

    test('rechaza lo que no es dinero', () {
      expect(centavosDesdeTexto(''), isNull);
      expect(centavosDesdeTexto('42.505'), isNull);
      expect(centavosDesdeTexto('abc'), isNull);
      expect(centavosDesdeTexto('-5'), isNull);
    });
  });

  group('existenciaLegible', () {
    final victoria = productosDePrueba().first; // 66 piezas, cajas de 12.

    test(
      'cajas y piezas sueltas',
      () => expect(existenciaLegible(victoria), '5 cajas + 6 pz'),
    );

    test('producto sin caja', () {
      final hielo = productosDePrueba().firstWhere(
        (p) => p.piezasPorCaja == null,
      );
      expect(existenciaLegible(hielo), '18 pz');
    });
  });

  test('diasHasta cuenta días de calendario', () {
    final hoy = DateTime(2026, 10, 2, 23, 59);
    expect(diasHasta('2026-10-02', hoy), 0);
    expect(diasHasta('2026-10-03', hoy), 1);
    expect(diasHasta('2026-09-30', hoy), -2);
  });

  group('tamanoLegible', () {
    test('bytes', () => expect(tamanoLegible(512), '512 B'));
    test('kilobytes con un decimal', () {
      expect(tamanoLegible(1024), '1.0 KB');
    });
    test('kilobytes sin decimales', () {
      expect(tamanoLegible(500 * 1024), '500 KB');
    });
    test('megabytes con un decimal', () {
      expect(tamanoLegible(1843200), '1.8 MB');
    });
    test('megabytes grandes sin decimales', () {
      expect(tamanoLegible(10 * 1024 * 1024), '10 MB');
    });
  });
}
