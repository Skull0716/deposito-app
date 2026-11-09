import 'dart:async';

import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/features/catalogo/pantallas/modal_importar_inventario.dart';
import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

/// Alta, edición y ajustes de inventario desde el catálogo de la caja.
void main() {
  Future<void> abrirFicha(WidgetTester tester, String nombre) async {
    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).first);
    await tester.pumpAndSettle();
  }

  testWidgets('la caja edita un producto sin tocar la existencia', (
    tester,
  ) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await abrirFicha(tester, 'Victoria Mega');

    expect(find.text('Editar producto'), findsOneWidget);
    await tester.tap(find.text('Editar producto'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Editar producto'),
      ),
      findsOneWidget,
    );

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

  testWidgets('recibir mercancía suma cajas y piezas', (tester) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await abrirFicha(tester, 'Victoria Mega');

    await tester.tap(find.text('Recibir mercancía').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cajas'), '1');
    await tester.enterText(
      find.widgetWithText(TextField, 'Piezas sueltas'),
      '2',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Recibir mercancía'),
      ),
    );
    await tester.pumpAndSettle();

    final producto = api.productos.firstWhere((p) => p.id == 'p_1');
    expect(producto.existenciaPiezas, 66 + 12 + 2);
    expect(find.text('6 cajas + 8 pz'), findsOneWidget);
  });

  testWidgets('ajustar existencia con conteo y ver movimientos', (
    tester,
  ) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await abrirFicha(tester, 'Victoria Mega');

    await tester.tap(find.text('Ajustar existencia'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Piezas contadas'),
      '50',
    );
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();

    expect(api.productos.firstWhere((p) => p.id == 'p_1').existenciaPiezas, 50);
    expect(find.text('4 cajas + 2 pz'), findsOneWidget);

    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    expect(find.text('Ajuste de conteo'), findsOneWidget);
    expect(find.text('-16 pz'), findsOneWidget);
    expect(find.text('quedan 50'), findsOneWidget);
  });

  testWidgets('la merma saca piezas y queda en los movimientos', (
    tester,
  ) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await abrirFicha(tester, 'Victoria Mega');

    await tester.tap(find.text('Ajustar existencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merma'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Piezas a sacar'),
      '5',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nota (opcional)'),
      'Botellas rotas',
    );
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();

    expect(api.productos.firstWhere((p) => p.id == 'p_1').existenciaPiezas, 61);
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    expect(find.text('Merma'), findsOneWidget);
    expect(find.text('-5 pz'), findsOneWidget);
    expect(find.text('Botellas rotas'), findsOneWidget);
  });

  testWidgets('eliminar pide confirmación y quita el producto', (tester) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await abrirFicha(tester, 'Victoria Mega');

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Victoria Mega?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Eliminar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.productos.any((p) => p.id == 'p_1'), isFalse);
    expect(find.text('Victoria Mega se eliminó'), findsOneWidget);
  });

  testWidgets('quitar la foto se guarda con el producto', (tester) async {
    final base = productosDePrueba().first;
    final api = ApiFalsa(
      productos: [
        Producto.fromJson({
          ...base.toJson(),
          'foto': '/api/v1/productos/p_1/foto?v=1',
        }),
      ],
    );
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await abrirFicha(tester, 'Victoria Mega');

    await tester.tap(find.text('Editar producto'));
    await tester.pumpAndSettle();
    expect(find.text('Foto actual'), findsOneWidget);

    await tester.tap(find.text('Quitar foto'));
    await tester.pump();
    expect(find.text('Se usará una ilustración'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(api.productos.first.foto, isNull);
  });

  testWidgets('la importación revisa el CSV antes de guardar', (tester) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    final context = tester.element(find.byType(Scaffold).first);

    unawaited(
      showDialog<ResultadoImportacion>(
        context: context,
        builder: (_) => const DialogoImportarInventario(
          nombreArchivo: 'inventario.csv',
          csv:
              'codigo,nombre,categoria,precio,existencia\n'
              '7501064191015,Victoria Mega,cerveza,42.00,80\n'
              '7509999999999,Nueva Cerveza,cerveza,30,10\n',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importar inventario'), findsOneWidget);
    expect(find.text('inventario.csv'), findsOneWidget);
    expect(find.text('1 nuevo'), findsOneWidget);
    expect(find.text('1 actualizado'), findsOneWidget);
    expect(find.text('Todo listo para importar.'), findsOneWidget);
    expect(find.text('Cambios de existencia'), findsOneWidget);
    expect(find.text('66 a 80 pz'), findsOneWidget);

    await tester.tap(find.text('Aplicar importación'));
    await tester.pumpAndSettle();

    expect(api.productos.length, 7);
    expect(api.productos.firstWhere((p) => p.id == 'p_1').existenciaPiezas, 80);
    expect(
      api.productos.firstWhere((p) => p.codigo == '7509999999999').nombre,
      'Nueva Cerveza',
    );
  });

  testWidgets('la importación con errores no deja guardar', (tester) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    final context = tester.element(find.byType(Scaffold).first);

    unawaited(
      showDialog<ResultadoImportacion>(
        context: context,
        builder: (_) => const DialogoImportarInventario(
          nombreArchivo: 'inventario.csv',
          csv:
              'codigo,nombre,categoria,precio\n'
              '7501064191015,Victoria Mega,cerveza,\n',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Errores (1)'), findsOneWidget);
    expect(find.text('Renglón 2 · 7501064191015'), findsOneWidget);
    expect(find.text('precio: Es obligatorio'), findsOneWidget);
    expect(find.text('Aplicar importación'), findsNothing);
    expect(api.productos.first.existenciaPiezas, 66);
  });
}
