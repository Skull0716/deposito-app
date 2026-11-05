import 'package:deposito_app/app/tema/tema.dart';
import 'package:deposito_app/core/tiempo_real/tiempo_real.dart';
import 'package:deposito_app/core/widgets/campo_pin.dart';
import 'package:deposito_app/core/widgets/indicador_conexion.dart';
import 'package:deposito_app/core/widgets/teclado_numerico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

void main() {
  testWidgets('el PIN se anuncia como cantidad de dígitos capturados', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(body: CampoPin(longitud: 6, valor: '123')),
      ),
    );

    expect(find.bySemanticsLabel('PIN: 3 de 6'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('el borrar del teclado numérico tiene etiqueta', (tester) async {
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: temaClaro(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TecladoNumerico(alPresionarTecla: (_) {}, alBorrar: () {}),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Borrar'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('el indicador de conexión anuncia el estado', (tester) async {
    final semantica = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          estadoConexionProvider.overrideWith(
            (ref) => Stream.value(EstadoConexion.sinConexion),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: IndicadorConexion())),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Conexión: Sin conexión, reintentando'),
      findsOneWidget,
    );
    semantica.dispose();
  });

  testWidgets('la bienvenida soporta texto grande sin desbordarse', (
    tester,
  ) async {
    await montarApp(tester, tamano: const Size(412, 915), escalaTexto: 1.3);

    expect(find.text('Configura tu punto de venta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la caja y la venta soportan texto grande', (tester) async {
    await montarApp(tester, preferencias: prefsCaja, escalaTexto: 1.3);

    expect(find.text('Anaquel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Vender').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
