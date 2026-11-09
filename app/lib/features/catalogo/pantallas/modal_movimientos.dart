import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/widgets/estados.dart';
import '../estado/movimientos_producto.dart';

/// Historial de existencias del producto (`GET /productos/{id}/movimientos`).
Future<void> mostrarMovimientos(BuildContext context, Producto producto) =>
    showDialog<void>(
      context: context,
      builder: (_) => MovimientosProducto(producto: producto),
    );

class MovimientosProducto extends ConsumerWidget {
  const MovimientosProducto({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final estado = ref.watch(movimientosProductoProvider(producto.id));

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Movimientos'),
          const SizedBox(height: 2),
          Text(
            producto.nombre,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: c.tinta2),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: switch (estado) {
          AsyncData(:final value) =>
            value.isEmpty
                ? const EstadoVacio(
                    icono: Icons.history_rounded,
                    titulo: 'Sin movimientos',
                    mensaje:
                        'Todavía no cambia la existencia de este producto.',
                  )
                : ListView.separated(
                    itemCount: value.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: c.linea),
                    itemBuilder: (_, i) => _Fila(movimiento: value[i]),
                  ),
          AsyncError(:final error) => EstadoError(
            error: error,
            alReintentar: () =>
                ref.invalidate(movimientosProductoProvider(producto.id)),
          ),
          _ => const Cargando(mensaje: 'Leyendo los movimientos'),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.movimiento});

  final Movimiento movimiento;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final m = movimiento;
    final (etiqueta, icono) = _tipo(m.tipo);
    final positivo = m.piezas >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 22, color: positivo ? c.verde : c.tinta2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: textos.titleSmall),
                Text(
                  [
                    fechaHora(m.fecha),
                    if (m.origen.isNotEmpty) m.origen,
                    ?m.referencia,
                  ].join(' · '),
                  style: textos.bodySmall,
                ),
                if (m.nota case final nota?)
                  Text(nota, style: textos.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positivo ? '+' : ''}${m.piezas} pz',
                style: textos.titleSmall?.copyWith(
                  color: positivo ? c.verde : c.tinta,
                ),
              ),
              Text('quedan ${m.existenciaResultante}', style: textos.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  static (String, IconData) _tipo(String tipo) => switch (tipo) {
    'inicial' => ('Existencia inicial', Icons.flag_outlined),
    'entrada' => ('Entrada', Icons.add_box_outlined),
    'venta' => ('Venta', Icons.point_of_sale_rounded),
    'cancelacion' => ('Cancelación', Icons.undo_rounded),
    'ajuste' => ('Ajuste de conteo', Icons.tune_rounded),
    'merma' => ('Merma', Icons.delete_outline_rounded),
    _ => ('Movimiento', Icons.swap_vert_rounded),
  };
}
