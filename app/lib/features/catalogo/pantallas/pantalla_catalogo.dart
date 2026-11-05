import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/fallo_api.dart';
import '../../../core/widgets/estados.dart';
import '../datos/csv_inventario.dart';
import '../estado/productos.dart';
import 'acciones_producto.dart';
import 'detalle_producto.dart';
import 'formulario_producto.dart';
import 'modal_importar_inventario.dart';
import 'vista_catalogo.dart';

enum _AccionInventario { importar, exportar }

/// Catálogo de la caja: el mismo de la terminal, más el alta, la edición,
/// los ajustes de inventario y la importación/exportación en CSV.
class PantallaCatalogo extends ConsumerWidget {
  const PantallaCatalogo({super.key});

  Future<void> _importar(BuildContext context, WidgetRef ref) async {
    final resultado = await abrirImportarInventario(context);
    if (resultado == null) return;
    await ref.read(productosProvider.notifier).refrescar();
    if (!context.mounted) return;
    avisar(
      context,
      'Inventario importado: ${resultado.creados} nuevos, '
      '${resultado.actualizados} actualizados',
    );
  }

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    final productos = ref.read(productosProvider).value;
    if (productos == null || productos.isEmpty) {
      avisar(context, 'El catálogo está vacío');
      return;
    }
    try {
      final guardado = await exportarInventario(productos);
      if (guardado && context.mounted) avisar(context, 'Inventario exportado');
    } on Object catch (e) {
      if (context.mounted) {
        avisar(context, 'No se pudo exportar: ${mensajeDeError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => VistaCatalogo(
    acciones: [
      PopupMenuButton<_AccionInventario>(
        tooltip: 'Importar o exportar inventario',
        icon: const Icon(Icons.swap_vert_rounded),
        onSelected: (accion) => switch (accion) {
          _AccionInventario.importar => _importar(context, ref),
          _AccionInventario.exportar => _exportar(context, ref),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _AccionInventario.importar,
            child: Row(
              spacing: 12,
              children: [
                Icon(Icons.upload_file_outlined),
                Text('Importar desde CSV'),
              ],
            ),
          ),
          PopupMenuItem(
            value: _AccionInventario.exportar,
            child: Row(
              spacing: 12,
              children: [
                Icon(Icons.download_outlined),
                Text('Exportar inventario'),
              ],
            ),
          ),
        ],
      ),
      FilledButton.icon(
        onPressed: () => abrirFormularioProducto(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo producto'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
      ),
    ],
    alTocarProducto: (context, producto) => mostrarDetalleProducto(
      context,
      producto,
      accionesCaja: AccionesProductoCaja(producto: producto),
    ),
  );
}
