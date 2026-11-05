import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/productos.dart';
import 'detalle_producto.dart';
import 'formulario_producto.dart';
import 'vista_catalogo.dart';

/// Catálogo de la caja: el mismo de la terminal, más el alta y la edición
/// de productos.
class PantallaCatalogo extends ConsumerWidget {
  const PantallaCatalogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => VistaCatalogo(
    acciones: [
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
      alEditar: () async {
        // Cierra la ficha y abre el formulario sobre el catálogo, para que la
        // cuadrícula se actualice al guardar.
        Navigator.pop(context);
        final actualizado = await abrirFormularioProducto(
          context,
          producto: producto,
        );
        if (actualizado != null) {
          await ref.read(productosProvider.notifier).refrescar();
        }
      },
    ),
  );
}
