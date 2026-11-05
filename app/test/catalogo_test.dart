import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

/// Alta y edición de productos desde el catálogo de la caja.
void main() {
  testWidgets('la caja edita un producto sin tocar la existencia', (
    tester,
  ) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);

    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Victoria Mega'));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);

    await tester.tap(find.text('Editar producto'));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Victoria Mega 1.2 L',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Precio por pieza'),
      '45.50',
    );
    await tester.pump();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final producto = api.productos.firstWhere((p) => p.id == 'p_1');
    expect(producto.nombre, 'Victoria Mega 1.2 L');
    expect(producto.precio, 4550);
    expect(producto.existenciaPiezas, 66);
    expect(find.text('Victoria Mega 1.2 L'), findsWidgets);
  });
}
