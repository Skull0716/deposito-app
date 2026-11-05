import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/core/api/pedido.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

/// Pedidos que arma la terminal y cobra la caja (docs/API.md).
void main() {
  Future<ApiFalsa> abrirTerminal(
    WidgetTester tester, {
    double? escalaTexto,
  }) async {
    final api = ApiFalsa();
    await montarApp(
      tester,
      preferencias: prefsTerminal,
      api: api,
      tamano: const Size(412, 915),
      escalaTexto: escalaTexto,
    );
    return api;
  }

  testWidgets('la terminal arma un pedido y lo manda a la caja', (
    tester,
  ) async {
    final api = await abrirTerminal(tester);

    await tester.enterText(find.byType(TextField), '7501064191015');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar 1 pieza'));
    await tester.tap(find.text('Agregar 1 pieza'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedido').last);
    await tester.pumpAndSettle();
    expect(find.text('Victoria Mega'), findsOneWidget);
    expect(find.text(r'$42'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mesa 3');
    await tester.tap(find.text('Enviar pedido a la caja'));
    await tester.pumpAndSettle();

    expect(api.pedidos, hasLength(1));
    final pedido = api.pedidos.single;
    expect(pedido.nota, 'Mesa 3');
    expect(pedido.lineas.single.productoId, 'p_1');
    expect(pedido.lineas.single.unidad, UnidadPedido.pieza);
    expect(pedido.lineas.single.cantidad, 1);
    expect(find.text('Pedido enviado a la caja'), findsOneWidget);
    expect(find.text('El pedido está vacío'), findsNothing);
  });

  testWidgets('desde Productos se agrega una caja completa', (tester) async {
    await abrirTerminal(tester);

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Victoria');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Victoria Mega'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar 1 caja de 12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar 1 caja de 12'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedido').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Caja de 12'), findsOneWidget);
    expect(find.text(r'$480'), findsOneWidget);
  });

  testWidgets('el pedido soporta texto grande', (tester) async {
    await abrirTerminal(tester, escalaTexto: 1.3);

    await tester.enterText(find.byType(TextField), '7501064191015');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar 1 pieza'));
    await tester.tap(find.text('Agregar 1 pieza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedido').last);
    await tester.pumpAndSettle();

    expect(find.text('Enviar pedido a la caja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la caja descarta un pedido pendiente', (tester) async {
    final api = await montarConPedido(tester);

    expect(find.text('Pedido de Terminal S24'), findsOneWidget);
    expect(find.textContaining(r'$84'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Pedido de Terminal S24'), findsNothing);
    expect(api.pedidos, isEmpty);
  });

  testWidgets('la caja pasa el pedido al ticket y lo quita de pendientes', (
    tester,
  ) async {
    final api = await montarConPedido(tester);

    await tester.tap(find.text('Pasar al ticket'));
    await tester.pumpAndSettle();

    expect(api.pedidos, isEmpty);
    expect(find.text('Victoria Mega'), findsWidgets);
    expect(find.text('Pedido cargado al ticket'), findsOneWidget);
  });

  testWidgets('Vender muestra los pedidos pendientes y los carga al ticket', (
    tester,
  ) async {
    final api = await montarConPedido(tester);

    await tester.tap(find.text('Vender').first);
    await tester.pumpAndSettle();

    expect(find.text('Pedido de Terminal S24'), findsOneWidget);
    await tester.tap(find.text('Pasar al ticket'));
    await tester.pumpAndSettle();

    expect(api.pedidos, isEmpty);
    expect(find.text('Pedido de Terminal S24'), findsNothing);
    expect(find.text('Pedido cargado al ticket'), findsOneWidget);
    expect(find.text('Victoria Mega'), findsWidgets);
  });

  testWidgets('el pedido pendiente se lee con texto grande en Vender', (
    tester,
  ) async {
    await montarConPedido(tester, escalaTexto: 1.3);

    await tester.tap(find.text('Vender').first);
    await tester.pumpAndSettle();

    expect(find.text('Pedido de Terminal S24'), findsOneWidget);
    expect(find.text('Pasar al ticket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Caja con un pedido pendiente de 2 piezas de Victoria Mega.
Future<ApiFalsa> montarConPedido(
  WidgetTester tester, {
  double? escalaTexto,
}) async {
  final api = ApiFalsa(
    pedidos: [
      const Pedido(
        id: 'ped_1',
        origen: 'Terminal S24',
        fecha: '2026-10-02T18:30:00Z',
        nota: 'Mesa 3',
        lineas: [
          LineaPedido(
            productoId: 'p_1',
            unidad: UnidadPedido.pieza,
            cantidad: 2,
          ),
        ],
      ),
    ],
  );
  await montarApp(
    tester,
    preferencias: prefsCaja,
    api: api,
    escalaTexto: escalaTexto,
  );
  return api;
}
