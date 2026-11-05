import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/config/configuracion.dart';
import '../../../core/widgets/indicador_conexion.dart';
import '../../catalogo/estado/productos.dart';
import '../estado/pedido_borrador.dart';

class _Pestana {
  const _Pestana(this.ruta, this.titulo, this.icono, this.iconoActivo);

  final String ruta;
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
}

const _pestanas = [
  _Pestana(
    'escanear',
    'Escanear',
    Icons.qr_code_scanner_outlined,
    Icons.qr_code_scanner_rounded,
  ),
  _Pestana(
    'productos',
    'Productos',
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
  ),
  _Pestana('pedido', 'Pedido', Icons.receipt_outlined, Icons.receipt_rounded),
  _Pestana(
    'ajustes',
    'Ajustes',
    Icons.settings_outlined,
    Icons.settings_rounded,
  ),
];

/// Marco de la terminal: encabezado café con el estado de la conexión y
/// pestañas abajo, a la mano del pulgar.
class ShellTerminal extends ConsumerWidget {
  const ShellTerminal({super.key, required this.seccion, required this.child});

  final String seccion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final nombre =
        ref.watch(configuracionProvider).conexion?.nombre ?? 'Terminal';
    final indice = _pestanas
        .indexWhere((p) => p.ruta == seccion)
        .clamp(0, _pestanas.length - 1);
    final error = ref.watch(productosProvider).error;
    final revocada = error is FalloApi && error.noAutorizado;
    final enPedido = ref.watch(pedidoBorradorProvider).articulos;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: c.vidrio,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pestanas[indice].titulo,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(color: c.vidrioTinta),
                          ),
                          const SizedBox(height: 4),
                          IndicadorConexion(
                            colorTexto: c.vidrioTinta2,
                            etiquetaEnLinea: '$nombre, conectada a la caja',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (revocada)
            MaterialBanner(
              backgroundColor: c.alertaSuave,
              content: Text(
                'La caja desvinculó esta terminal. Vuelve a escanear el código de la caja.',
                style: TextStyle(color: c.alerta, fontWeight: FontWeight.w500),
              ),
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(configuracionProvider.notifier)
                      .olvidarConexion(),
                  child: const Text('Vincular de nuevo'),
                ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: (i) =>
            context.go('/terminal/${_pestanas[i].ruta}'),
        destinations: [
          for (final p in _pestanas)
            NavigationDestination(
              icon: p.ruta == 'pedido' && enPedido > 0
                  ? Badge(label: Text('$enPedido'), child: Icon(p.icono))
                  : Icon(p.icono),
              selectedIcon: p.ruta == 'pedido' && enPedido > 0
                  ? Badge(label: Text('$enPedido'), child: Icon(p.iconoActivo))
                  : Icon(p.iconoActivo),
              label: p.titulo,
            ),
        ],
      ),
    );
  }
}
