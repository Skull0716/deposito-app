import 'dart:io';

import 'package:deposito_app/app/app.dart';
import 'package:deposito_app/core/api/api.dart';
import 'package:deposito_app/core/api/api_falsa.dart';
import 'package:deposito_app/core/api/proveedores.dart';
import 'package:deposito_app/core/config/configuracion.dart';
import 'package:deposito_app/core/servidor/servidor_embebido.dart';
import 'package:deposito_app/core/tiempo_real/tiempo_real.dart';
import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const prefsCaja = {'modo': 'caja'};
const prefsTerminal = {
  'modo': 'terminal',
  'conexion.host': '192.168.1.50',
  'conexion.puerto': 8080,
  'conexion.clave': 'clave',
  'conexion.nombre': 'Terminal S24',
};

/// Monta la app completa con [ApiFalsa], sin servidor ni WebSocket reales.
Future<void> montarApp(
  WidgetTester tester, {
  Map<String, Object> preferencias = const {},
  Api? api,
  Size tamano = const Size(1366, 1024),
  ThemeMode? tema,
  double? escalaTexto,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (escalaTexto != null) {
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  SharedPreferences.setMockInitialValues({
    if (tema != null) 'tema': tema.name,
    ...preferencias,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenciasProvider.overrideWithValue(prefs),
        apiProvider.overrideWith((ref) async => api ?? ApiFalsa()),
        servidorEmbebidoProvider.overrideWith(
          (ref) async => DepositoServer(rutaBaseDatos: enMemoria),
        ),
        direccionLocalProvider.overrideWith((ref) async => '192.168.1.50'),
        estadoConexionProvider.overrideWith(
          (ref) => Stream.value(EstadoConexion.enLinea),
        ),
        eventosProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: const AnaquelApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Carga Barlow e íconos para que las capturas se vean como en el dispositivo
/// (flutter_test usa una fuente de cuadros por omisión).
Future<void> cargarFuentes() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final cargador = FontLoader(familia);
    for (final r in rutas) {
      cargador.addFont(
        Future.value(ByteData.sublistView(File(r).readAsBytesSync())),
      );
    }
    await cargador.load();
  }

  await cargar('Barlow', [
    for (final p in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Barlow-$p.ttf',
  ]);
  await cargar('Barlow Condensed', [
    for (final p in ['SemiBold', 'Bold']) 'assets/fonts/BarlowCondensed-$p.ttf',
  ]);
  final flutterRaiz = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .parent
      .path;
  final iconos = File(
    '$flutterRaiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconos.existsSync()) await cargar('MaterialIcons', [iconos.path]);
}
