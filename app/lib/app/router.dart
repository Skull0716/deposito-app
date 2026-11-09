import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/configuracion.dart';
import '../features/ajustes/ajustes.dart';
import '../features/caja/pantallas/secciones_caja.dart';
import '../features/caja/pantallas/shell_caja.dart';
import '../features/catalogo/pantallas/detalle_producto.dart';
import '../features/catalogo/pantallas/vista_catalogo.dart';
import '../features/inicio/elegir_modo.dart';
import '../features/terminal/pantallas/acciones_pedido.dart';
import '../features/terminal/pantallas/escanear.dart';
import '../features/terminal/pantallas/pantalla_pedido.dart';
import '../features/terminal/pantallas/shell_terminal.dart';
import '../features/terminal/pantallas/vincular_terminal.dart';

/// Rutas:
/// - `/inicio`: elegir modo.
/// - `/caja/<sección>`: secciones de la caja (secciones_caja.dart).
/// - `/terminal/vincular` y `/terminal/<pestaña>`.
///
/// La configuración decide a dónde se puede ir: sin modo → `/inicio`;
/// terminal sin vincular → `/terminal/vincular`.
final routerProvider = Provider<GoRouter>((ref) {
  final cambios = ValueNotifier(0);
  ref.listen(configuracionProvider, (_, _) => cambios.value++);
  ref.onDispose(cambios.dispose);

  final router = GoRouter(
    initialLocation: '/inicio',
    refreshListenable: cambios,
    redirect: (context, estado) =>
        _redirigir(ref.read(configuracionProvider), estado.uri.path),
    routes: [
      GoRoute(path: '/inicio', builder: (_, _) => const ElegirModo()),
      ShellRoute(
        builder: (_, estado, hijo) => ShellCaja(
          seccion: estado.pathParameters['seccion'] ?? 'inicio',
          child: hijo,
        ),
        routes: [
          GoRoute(
            path: '/caja/:seccion',
            pageBuilder: (_, estado) {
              final s = seccionCaja(estado.pathParameters['seccion']!);
              return NoTransitionPage(
                key: ValueKey(s.ruta),
                child: s.construir(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/terminal/vincular',
        builder: (_, _) => const VincularTerminal(),
      ),
      ShellRoute(
        builder: (_, estado, hijo) => ShellTerminal(
          seccion: estado.pathParameters['seccion'] ?? 'escanear',
          child: hijo,
        ),
        routes: [
          GoRoute(
            path: '/terminal/:seccion',
            pageBuilder: (_, estado) {
              final seccion = estado.pathParameters['seccion']!;
              return NoTransitionPage(
                key: ValueKey(seccion),
                child: _pestanaTerminal(seccion),
              );
            },
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _redirigir(Configuracion config, String ruta) {
  switch (config.modo) {
    case null:
      return ruta == '/inicio' ? null : '/inicio';
    case ModoDispositivo.caja:
      return ruta.startsWith('/caja/') ? null : '/caja/inicio';
    case ModoDispositivo.terminal:
      if (config.conexion == null) {
        return ruta == '/terminal/vincular' ? null : '/terminal/vincular';
      }
      return ruta.startsWith('/terminal/') && ruta != '/terminal/vincular'
          ? null
          : '/terminal/escanear';
  }
}

Widget _pestanaTerminal(String seccion) => switch (seccion) {
  'productos' => VistaCatalogo(
    relleno: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    alTocarProducto: (context, producto) => mostrarDetalleProducto(
      context,
      producto,
      acciones: [AccionesPedido(producto: producto)],
    ),
  ),
  'pedido' => const PantallaPedido(),
  'ajustes' => const PantallaAjustes(),
  _ => const PantallaEscanear(),
};
