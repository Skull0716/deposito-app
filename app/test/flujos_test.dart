import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

void main() {
  testWidgets(
    'sin modo elegido muestra la bienvenida y la terminal se vincula',
    (tester) async {
      await montarApp(tester, tamano: const Size(412, 915));
      expect(find.text('Configura tu punto de venta'), findsOneWidget);

      await tester.tap(find.text('Vincular Celular como Terminal'));
      await tester.pumpAndSettle();

      expect(find.text('Vincula esta terminal'), findsOneWidget);
    },
  );

  testWidgets('la caja abre el tablero con lo que necesita atención', (
    tester,
  ) async {
    await montarApp(tester, preferencias: prefsCaja);

    expect(find.text('Anaquel'), findsOneWidget); // menú lateral
    expect(find.text('Necesita atención'), findsOneWidget);
    // Corona Mega tiene 30 piezas con mínimo 36.
    expect(find.text('Corona Mega'), findsWidgets);
  });

  testWidgets('el catálogo filtra por búsqueda sin acentos y por categoría', (
    tester,
  ) async {
    await montarApp(tester, preferencias: prefsCaja);
    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();

    expect(find.text('Victoria Mega'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'CORONA');
    await tester.pumpAndSettle();
    expect(find.text('Victoria Mega'), findsNothing);
    expect(find.text('Corona Mega'), findsOneWidget);
    expect(find.text('Corona Cuarto'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Botana'));
    await tester.pumpAndSettle();
    expect(find.text('Papas adobadas'), findsOneWidget);
    expect(find.text('Corona Mega'), findsNothing);
  });

  testWidgets('crear un producto valida el precio en pantalla y lo guarda', (
    tester,
  ) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo producto'));
    await tester.pumpAndSettle();

    Finder campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);
    await tester.enterText(campo('Código de barras'), '750999');
    await tester.enterText(campo('Nombre'), 'Tecate Light');
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el precio, por ejemplo 42.50'), findsOneWidget);
    expect(api.productos.where((p) => p.nombre == 'Tecate Light'), isEmpty);

    await tester.enterText(campo('Precio por pieza'), '23.50');
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    final creado = api.productos.singleWhere((p) => p.nombre == 'Tecate Light');
    expect(creado.precio, 2350);
    expect(find.text('Tecate Light quedó en el catálogo'), findsOneWidget);
  });

  testWidgets('la terminal escanea un código y muestra precio y existencia', (
    tester,
  ) async {
    await montarApp(
      tester,
      preferencias: prefsTerminal,
      tamano: const Size(412, 915),
    );
    expect(find.text('Listo para escanear'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '7501064191015');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Victoria Mega'), findsOneWidget);
    expect(find.text(r'$42'), findsOneWidget);
    expect(find.text('Hay 5 cajas + 6 pz'), findsOneWidget);
  });

  testWidgets('un código que no existe lo dice claramente', (tester) async {
    await montarApp(
      tester,
      preferencias: prefsTerminal,
      tamano: const Size(412, 915),
    );
    await tester.enterText(find.byType(TextField), '000');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Código no registrado'), findsOneWidget);
  });

  testWidgets('una terminal sin vincular va a la pantalla de vinculación', (
    tester,
  ) async {
    await montarApp(
      tester,
      preferencias: {'modo': 'terminal'},
      tamano: const Size(412, 915),
    );
    expect(find.text('Vincula esta terminal'), findsOneWidget);
  });

  group('vender', () {
    Future<ApiFalsa> abrirVender(WidgetTester tester) async {
      final api = ApiFalsa();
      await montarApp(tester, preferencias: prefsCaja, api: api);
      await tester.tap(find.text('Vender').first);
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('cobra con tarjeta, descuenta existencias y vacía la venta', (
      tester,
    ) async {
      final api = await abrirVender(tester);

      await tester.tap(find.text('Hielo en bolsa'));
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.pumpAndSettle();
      expect(find.text(r'$70'), findsNWidgets(3)); // renglón, subtotal y total

      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y Pagar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarjeta'));
      // La pantalla de tarjeta tiene una animación que no termina.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Pago aprobado'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('¡Venta Registrada con Éxito!'), findsOneWidget);
      expect(find.text(r'Folio #1001 • Total: $70'), findsOneWidget);
      final venta = api.ventas.values.single;
      expect(venta.total, 7000);
      expect(venta.metodo, 'tarjeta');
      final hielo = api.productos.singleWhere((p) => p.id == 'p_4');
      expect(hielo.existenciaPiezas, 16);

      await tester.tap(find.text('Sin Recibo'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no hay productos en la venta'), findsOneWidget);
    });

    testWidgets('vende una caja al precio de caja y cobra en efectivo', (
      tester,
    ) async {
      final api = await abrirVender(tester);

      await tester.tap(find.text('Victoria Mega'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vender 1 caja (12 pz)'));
      await tester.pumpAndSettle();
      expect(find.text('Victoria Mega (caja)'), findsOneWidget);

      // Es retornable: al cobrar se decide qué pasa con los envases.
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Cómo se manejan los envases de esta compra?'),
        findsOneWidget,
      );
      await tester.tap(find.text('El cliente entregó vacíos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Intercambio: el cliente entrega vacíos'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirmar y Pagar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'Entregar $500'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'Cobrar ($500)'));
      await tester.pumpAndSettle();
      expect(find.text(r'$20'), findsOneWidget); // cambio de $500 - $480
      await tester.tap(find.text('Cerrar Venta'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final venta = api.ventas.values.single;
      expect(venta.total, 48000);
      expect(venta.recibido, 50000);
      expect(venta.cambio, 2000);
      final victoria = api.productos.singleWhere((p) => p.id == 'p_1');
      expect(victoria.existenciaPiezas, 66 - 12);
      expect(api.envases['mega']!.bodega, 84 + 12, reason: 'intercambio');
    });

    Future<void> cobrarConTarjeta(WidgetTester tester) async {
      await tester.tap(find.text('Confirmar y Pagar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarjeta'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Pago aprobado'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    testWidgets('cobrar el depósito suma los envases al total', (tester) async {
      final api = await abrirVender(tester);
      await tester.tap(find.text('Victoria Mega'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vender 1 pieza'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrar depósito del envase'));
      await tester.pumpAndSettle();
      expect(find.text('Cargo por Depósito de Envases'), findsOneWidget);
      expect(find.text(r'$50'), findsOneWidget); // $42 + $8 de depósito
      await cobrarConTarjeta(tester);

      final venta = api.detalles.single;
      expect(
        (venta.total, venta.envModo, venta.envMonto),
        (5000, 'cobrar', 800),
      );
    });

    testWidgets('el descuento por renglón baja el precio por unidad', (
      tester,
    ) async {
      final api = await abrirVender(tester);
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hielo en bolsa').last); // renglón de la venta
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '10');
      await tester.pumpAndSettle();
      expect(find.text(r'$35 → $31.50 c/u'), findsOneWidget);
      Navigator.of(tester.element(find.text('Eliminar producto'))).pop();
      await tester.pumpAndSettle();
      expect(find.text(r'$31.50 x 1 (−10%)'), findsOneWidget);

      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await cobrarConTarjeta(tester);
      final linea = api.detalles.single.lineas.single;
      expect((linea.descuento, linea.precioUnit), (10, 3150));
    });

    testWidgets('los vacíos extra se descuentan del ticket', (tester) async {
      final api = await abrirVender(tester);
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Recibir Vacíos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mega 1.2 L'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.text(r'Aplicar Crédito al Ticket (-$16)'));
      await tester.pumpAndSettle();
      expect(find.text('Crédito por Envase (2 Mega 1.2 L)'), findsOneWidget);
      expect(find.text(r'$54'), findsOneWidget); // $70 - $16

      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await cobrarConTarjeta(tester);
      final venta = api.detalles.single;
      expect((venta.total, venta.envCredito), (5400, 1600));
      expect(api.envases['mega']!.bodega, 84 + 2);
    });

    testWidgets('saldo por envases descuenta los vacíos y cobra el resto', (
      tester,
    ) async {
      final api = await abrirVender(tester);
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y Pagar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saldo por Envases'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mega 1.2 L'));
      await tester.pump();
      await tester.tap(find.text(r'Aplicar Crédito al Ticket (-$8)'));
      await tester.pumpAndSettle();
      expect(find.text('Cobro en Efectivo'), findsOneWidget);
      expect(find.text(r'Monto Exacto ($62)'), findsOneWidget); // $70 - $8
      await tester.tap(find.text(r'Monto Exacto ($62)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'Cobrar ($62)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar Venta'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final venta = api.detalles.single;
      expect((venta.total, venta.envCredito), (6200, 800));
    });

    testWidgets('tarjeta rechazada deja reintentar sin registrar', (
      tester,
    ) async {
      final api = await abrirVender(tester);
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y Pagar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarjeta'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Pago rechazado'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Transacción Declinada'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Transacción Declinada'), findsNothing);
      expect(api.ventas, isEmpty);
    });

    testWidgets('el recibo muestra la vista previa del ticket real', (
      tester,
    ) async {
      await abrirVender(tester);
      await tester.tap(find.text('Hielo en bolsa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      await cobrarConTarjeta(tester);

      await tester.tap(find.text('Imprimir Ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Folio: #1001'), findsOneWidget);
      expect(find.text('1x Hielo en bolsa'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no hay productos en la venta'), findsOneWidget);
    });

    testWidgets('no deja vender más de lo que hay', (tester) async {
      await abrirVender(tester);

      // Hielo: 18 piezas.
      for (var i = 0; i < 19; i++) {
        await tester.tap(find.text('Hielo en bolsa'));
      }
      await tester.pumpAndSettle();

      expect(find.text('Solo hay 18 piezas de Hielo en bolsa'), findsOneWidget);
    });
  });
}
