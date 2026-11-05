// Genera capturas PNG de las pantallas principales para revisar el diseño.
// No corre en el CI: solo cuando se define CAPTURAS con la carpeta de salida.
//
//   CAPTURAS=/tmp/capturas flutter test test/capturas_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/core/api/pedido.dart';

import 'ayudantes.dart';

final _salida = Platform.environment['CAPTURAS'];

void main() {
  const ipad = Size(1366, 1024);
  const telefono = Size(412, 915);

  setUpAll(cargarFuentes);

  Future<void> capturar(
    WidgetTester tester,
    String nombre, {
    bool esperar = true,
  }) async {
    if (esperar) await tester.pumpAndSettle();
    final vista = tester.binding.renderViews.first;
    final capa = vista.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final imagen = await capa.toImage(Offset.zero & vista.size);
      final png = await imagen.toByteData(format: ImageByteFormat.png);
      File('$_salida/$nombre.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  final omitir = _salida == null
      ? 'Define CAPTURAS para generar capturas'
      : null;

  ApiFalsa cajaConPedido() => ApiFalsa(
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
          LineaPedido(
            productoId: 'p_2',
            unidad: UnidadPedido.caja,
            cantidad: 1,
          ),
        ],
      ),
    ],
  );

  testWidgets('bienvenida', skip: omitir != null, (tester) async {
    await montarApp(tester, tamano: ipad, tema: ThemeMode.dark);
    await capturar(tester, '01_bienvenida_oscuro');
  });

  testWidgets('caja inicio', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await capturar(tester, '02_caja_inicio_claro');
  });

  testWidgets('caja inicio oscuro', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.dark,
    );
    await capturar(tester, '03_caja_inicio_oscuro');
  });

  testWidgets('caja catálogo', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Catálogo').first);
    await capturar(tester, '04_caja_catalogo');
  });

  testWidgets('caja nuevo producto', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo producto'));
    await capturar(tester, '05_caja_nuevo_producto');
  });

  testWidgets('caja vincular terminal', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Vincular Terminal').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // Sin pumpAndSettle: el diálogo tiene un reloj que nunca se detiene.
    await capturar(tester, '06_caja_vincular_terminal', esperar: false);
    // Cierra el diálogo para cancelar sus temporizadores.
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
  });

  testWidgets('caja vertical', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: const Size(820, 1180),
      tema: ThemeMode.light,
    );
    await tester.tap(find.byTooltip('Catálogo'));
    await capturar(tester, '07_caja_ipad_vertical');
  });

  testWidgets('terminal escanear', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsTerminal,
      tamano: telefono,
      tema: ThemeMode.dark,
    );
    await tester.enterText(find.byType(TextField), '7501064191022');
    await tester.tap(find.text('Buscar'));
    await capturar(tester, '08_terminal_escanear');
  });

  testWidgets('terminal productos', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsTerminal,
      tamano: telefono,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Productos'));
    await capturar(tester, '09_terminal_productos');
  });

  testWidgets('terminal vincular', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: {'modo': 'terminal'},
      tamano: telefono,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Escribir los datos a mano'));
    await capturar(tester, '10_terminal_vincular');
  });

  testWidgets('caja alertas', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Alertas').first);
    await capturar(tester, '11_caja_alertas');
  });

  testWidgets('terminal pedido', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsTerminal,
      tamano: telefono,
      tema: ThemeMode.light,
    );
    await tester.enterText(find.byType(TextField), '7501064191015');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Agregar 1 pieza'));
    await tester.tap(find.text('Agregar 1 pieza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedido').last);
    await capturar(tester, '12_terminal_pedido');
  });

  testWidgets('caja pedido pendiente', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      api: cajaConPedido(),
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await capturar(tester, '13_caja_pedido_pendiente');
  });

  testWidgets('caja vender con pedido pendiente', skip: omitir != null, (
    tester,
  ) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      api: cajaConPedido(),
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Vender').first);
    await capturar(tester, '14_caja_vender_pedido');
  });

  testWidgets('caja diagnóstico', skip: omitir != null, (tester) async {
    await montarApp(
      tester,
      preferencias: prefsCaja,
      tamano: ipad,
      tema: ThemeMode.light,
    );
    await tester.tap(find.text('Ajustes').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Diagnóstico del servidor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnóstico del servidor'));
    await capturar(tester, '15_caja_diagnostico');
  });
}
