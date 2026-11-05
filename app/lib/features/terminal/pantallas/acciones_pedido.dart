import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/pedido_borrador.dart';

/// Botones para agregar un producto al pedido desde la ficha de la terminal.
class AccionesPedido extends ConsumerWidget {
  const AccionesPedido({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porCaja = producto.piezasPorCaja;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _agregar(context, ref, porCaja: false),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar 1 pieza'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        if (porCaja != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _agregar(context, ref, porCaja: true),
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text('Agregar 1 caja de $porCaja'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ],
    );
  }

  void _agregar(BuildContext context, WidgetRef ref, {required bool porCaja}) {
    ref
        .read(pedidoBorradorProvider.notifier)
        .agregar(producto, porCaja: porCaja);
    final mensajero = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${producto.nombre} se agregó al pedido')),
      );
  }
}
