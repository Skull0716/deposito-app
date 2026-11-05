import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/pedido.dart';
import '../../../core/formato/formato.dart';
import '../../../core/widgets/estados.dart';
import '../../pdv/estado/carrito.dart';
import '../estado/pedidos_provider.dart';

/// Pedidos que mandaron las terminales y todavía no se cobran.
///
/// Se muestra en Inicio y en Vender para que la caja no los pierda de vista.
/// Cuando no hay pedidos no ocupa espacio.
class PedidosPendientes extends ConsumerWidget {
  const PedidosPendientes({super.key, required this.productos});

  /// Catálogo actual, para calcular el total y cargar el ticket.
  final List<Producto> productos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista =
        ref.watch(pedidosPendientesProvider).value ?? const <Pedido>[];
    if (lista.isEmpty) return const SizedBox.shrink();
    final porId = {for (final p in productos) p.id: p};

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _TarjetaPedidos(
        titulo: lista.length == 1
            ? 'Pedido de terminal'
            : 'Pedidos de terminal',
        accion: IconButton(
          tooltip: 'Actualizar pedidos',
          onPressed: () =>
              ref.read(pedidosPendientesProvider.notifier).refrescar(),
          icon: const Icon(Icons.refresh_rounded),
        ),
        child: Column(
          children: [
            for (var i = 0; i < lista.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.colores.linea),
              _FilaPedido(pedido: lista[i], productos: porId),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaPedido extends ConsumerWidget {
  const _FilaPedido({required this.pedido, required this.productos});

  final Pedido pedido;
  final Map<String, Producto> productos;

  int get _total {
    var total = 0;
    for (final l in pedido.lineas) {
      final p = productos[l.productoId];
      if (p == null) continue;
      final porCaja =
          l.unidad.porCaja && p.precioCaja != null && p.piezasPorCaja != null;
      total += l.cantidad * (porCaja ? p.precioCaja! : p.precio);
    }
    return total;
  }

  Future<void> _descartar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      titulo: 'Descartar pedido',
      mensaje:
          'El pedido de ${pedido.origen} se borrará. Esta acción no se puede deshacer.',
      accion: 'Descartar',
      peligrosa: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(pedidosPendientesProvider.notifier).descartar(pedido);
    } on Object catch (e) {
      if (context.mounted) avisar(context, mensajeDeError(e));
    }
  }

  Future<void> _pasarAlTicket(BuildContext context, WidgetRef ref) async {
    final lineas = <({Producto producto, bool porCaja, int cantidad})>[
      for (final l in pedido.lineas)
        if (productos[l.productoId] case final p?)
          (producto: p, porCaja: l.unidad.porCaja, cantidad: l.cantidad),
    ];
    if (lineas.isEmpty) {
      avisar(
        context,
        'Los productos de este pedido ya no están en el catálogo',
      );
      return;
    }

    final conflictos = ref.read(carritoProvider.notifier).cargarPedido(lineas);
    try {
      await ref.read(pedidosPendientesProvider.notifier).descartar(pedido);
    } on Object catch (e) {
      if (context.mounted) avisar(context, mensajeDeError(e));
    }
    if (!context.mounted) return;

    // Si ya estamos en Vender no hace falta volver a navegar (y se conserva
    // la búsqueda y el filtro que tenía la caja).
    final seccion = GoRouterState.of(context).pathParameters['seccion'];
    if (seccion != 'vender') context.go('/caja/vender');

    avisar(
      context,
      conflictos.isEmpty
          ? 'Pedido cargado al ticket'
          : 'Pedido cargado. Revisa existencias: ${conflictos.join(', ')}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final articulos = pedido.articulos;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.lagerSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, color: c.azul),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido de ${pedido.origen}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$articulos ${articulos == 1 ? 'artículo' : 'artículos'} · '
                  '${dinero(_total)} · ${hora(pedido.fecha)}',
                  style: TextStyle(color: c.tinta2, fontSize: 14),
                ),
                if (pedido.nota case final nota?)
                  Text(
                    'Nota: $nota',
                    style: TextStyle(color: c.tinta2, fontSize: 14),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _descartar(context, ref),
                      child: const Text('Descartar'),
                    ),
                    FilledButton(
                      onPressed: () => _pasarAlTicket(context, ref),
                      child: const Text('Pasar al ticket'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPedidos extends StatelessWidget {
  const _TarjetaPedidos({
    required this.titulo,
    required this.child,
    this.accion,
  });

  final String titulo;
  final Widget child;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
