import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudantes.dart';

/// Personal, inicio de turno y ajustes del negocio (pantallas de Pablo),
/// contra ApiFalsa.
void main() {
  Future<ApiFalsa> conPersonal() async {
    final api = ApiFalsa();
    await api.crearUsuario(nombre: 'Don Beto', rol: 'dueno', pin: '999999');
    await api.crearUsuario(
      nombre: 'Ana',
      rol: 'cajero',
      pin: '1111',
      pinAutoriza: '999999',
    );
    return api;
  }

  Future<void> teclear(WidgetTester tester, String digitos) async {
    for (final d in digitos.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
  }

  Future<void> entrarComo(
    WidgetTester tester,
    String nombre,
    String pin,
  ) async {
    await tester.tap(find.text(nombre));
    await tester.pumpAndSettle();
    await teclear(tester, pin);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('con personal se entra con PIN y la venta queda a su nombre', (
    tester,
  ) async {
    final api = await conPersonal();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    expect(find.text('Selecciona tu usuario para comenzar'), findsOneWidget);
    expect(find.text('Cajero'), findsOneWidget);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await teclear(tester, '0000');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('PIN Incorrecto'), findsOneWidget);
    Navigator.of(tester.element(find.text('Entrar'))).pop();
    await tester.pumpAndSettle();

    await entrarComo(tester, 'Ana', '1111');
    expect(find.text('Selecciona tu usuario para comenzar'), findsNothing);

    await tester.tap(find.text('Vender').first);
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Pago aprobado'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(api.detalles.single.usuario?.nombre, 'Ana');
  });

  testWidgets('dar de alta a alguien pide el PIN del dueño', (tester) async {
    final api = await conPersonal();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await entrarComo(tester, 'Don Beto', '999999');

    await tester.tap(find.text('Ajustes').first);
    await tester.pumpAndSettle();
    expect(find.text('Don Beto'), findsOneWidget); // en la caja
    await tester.tap(find.text('Gestión de personal'));
    await tester.pumpAndSettle();
    expect(find.text('Gestión de Personal'), findsOneWidget);

    await tester.tap(find.text('Agregar Empleado'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Luis Pérez');
    await tester.enterText(find.byType(TextField).at(1), '4321');
    await tester.tap(find.text('Guardar Empleado'));
    await tester.pumpAndSettle();
    expect(find.text('Autorización Requerida'), findsOneWidget);
    await teclear(tester, '999999');
    await tester.tap(find.text('Autorizar'));
    await tester.pumpAndSettle();

    final nuevo = api.usuarios.last;
    expect(
      (nuevo.usuario.nombre, nuevo.usuario.rol, nuevo.pin),
      ('Luis Pérez', 'cajero', '4321'),
    );
    expect(find.text('Luis Pérez'), findsOneWidget);
  });

  testWidgets('la pantalla de respaldo explica qué guarda', (tester) async {
    final api = await conPersonal();
    await montarApp(
      tester,
      preferencias: prefsCaja,
      api: api,
      tamano: const Size(1366, 1200),
    );
    await entrarComo(tester, 'Don Beto', '999999');

    await tester.tap(find.text('Ajustes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguridad y respaldo'));
    await tester.pumpAndSettle();

    expect(find.text('Seguridad y Respaldo'), findsOneWidget);
    expect(find.textContaining('copia completa'), findsOneWidget);
    expect(find.text('Generar respaldo manual'), findsOneWidget);
    expect(find.textContaining('cifrada'), findsNothing);
  });

  testWidgets('los datos del negocio se guardan para el ticket', (
    tester,
  ) async {
    final api = ApiFalsa();
    await montarApp(tester, preferencias: prefsCaja, api: api);
    await tester.tap(find.text('Ajustes').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del negocio'),
      'Depósito Don Beto',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.ajustes.nombreNegocio, 'Depósito Don Beto');
  });

  testWidgets('la cuenta maestra crea al dueño cuando arranca la caja', (
    tester,
  ) async {
    final api = ApiFalsa();
    // iPad vertical: en horizontal el teclado del PIN no cabe completo.
    await montarApp(tester, api: api, tamano: const Size(1024, 1366));
    await tester.tap(find.text('Crear Nuevo Servidor POS'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Depósito La Esquina');
    await tester.enterText(find.byType(TextField).at(1), 'Beto Ruiz');
    await teclear(tester, '246810');
    await tester.scrollUntilVisible(
      find.text('Continuar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await teclear(tester, '246810');
    await tester.scrollUntilVisible(
      find.text('Confirmar PIN'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Confirmar PIN'));
    await tester.pump();
    // Inicializando la base (animación de unos segundos).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final dueno = api.usuarios.single;
    expect(
      (dueno.usuario.nombre, dueno.usuario.rol, dueno.pin),
      ('Beto Ruiz', 'dueno', '246810'),
    );
    expect(api.ajustes.nombreNegocio, 'Depósito La Esquina');
    // El dueño queda en la caja: no se le pide su PIN otra vez.
    expect(find.text('Selecciona tu usuario para comenzar'), findsNothing);
  });
}
