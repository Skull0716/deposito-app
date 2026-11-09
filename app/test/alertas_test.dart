import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

/// Alertas en caja (docs/API.md): productos agotados o bajo su mínimo y
/// caducidades próximas, contra ApiFalsa.
void main() {
  Future<ApiFalsa> abrirAlertas(
    WidgetTester tester, {
    List<Producto>? productos,
    double? escalaTexto,
  }) async {
    final api = ApiFalsa(productos: productos)..hoy = '2026-10-02';
    await montarApp(
      tester,
      preferencias: prefsCaja,
      api: api,
      escalaTexto: escalaTexto,
    );
    await tester.tap(find.text('Alertas').first);
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('muestra poco stock y caducidades próximas', (tester) async {
    await abrirAlertas(tester);

    expect(find.text('Poco stock'), findsWidgets);
    expect(find.text('Caducan pronto'), findsOneWidget);
    expect(find.text('Corona Mega'), findsOneWidget);
    expect(find.text('Papas adobadas'), findsOneWidget);
    expect(find.text('Recibir'), findsOneWidget);
  });

  testWidgets('recibir mercancía actualiza la existencia y la alerta', (
    tester,
  ) async {
    final api = await abrirAlertas(tester);
    expect(api.productos.firstWhere((p) => p.id == 'p_2').existenciaPiezas, 30);

    await tester.tap(find.text('Recibir'));
    await tester.pumpAndSettle();
    expect(find.text('Recibir mercancía'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Cajas'), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Recibir mercancía'));
    await tester.pumpAndSettle();

    expect(api.productos.firstWhere((p) => p.id == 'p_2').existenciaPiezas, 66);
    expect(find.text('Corona Mega'), findsNothing);
    expect(find.textContaining('entrada registrada'), findsOneWidget);
  });

  testWidgets('sin alertas muestra que todo está en orden', (tester) async {
    await abrirAlertas(tester, productos: []);

    expect(find.text('Todo en orden'), findsOneWidget);
    expect(find.text('Poco stock'), findsNothing);
    expect(find.text('Caducan pronto'), findsNothing);
  });

  testWidgets('soporta texto grande sin desbordarse', (tester) async {
    await abrirAlertas(tester, escalaTexto: 1.3);

    expect(find.text('Poco stock'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
