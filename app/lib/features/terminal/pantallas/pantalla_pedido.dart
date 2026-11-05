import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';
import '../estado/pedido_borrador.dart';

/// Arma el pedido del cliente y lo manda a la caja para cobrarlo.
class PantallaPedido extends ConsumerStatefulWidget {
  const PantallaPedido({super.key});

  @override
  ConsumerState<PantallaPedido> createState() => _PantallaPedidoState();
}

class _PantallaPedidoState extends ConsumerState<PantallaPedido> {
  final _nota = TextEditingController();
  String? _error;
  var _enviando = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _enviar(PedidoBorrador pedido) async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final api = await ref.read(apiProvider.future);
      await api.crearPedido(
        lineas: [for (final l in pedido.lineas) l.linea],
        nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
      );
      if (!mounted) return;
      ref.read(pedidoBorradorProvider.notifier).vaciar();
      _nota.clear();
      avisar(context, 'Pedido enviado a la caja');
      context.go('/terminal/escanear');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoBorradorProvider);
    if (pedido.vacio) {
      return EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'El pedido está vacío',
        mensaje: 'Escanea o elige productos para agregarlos. Al enviarlo, la caja lo cobra.',
        accion: FilledButton.icon(
          onPressed: () => context.go('/terminal/productos'),
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('Ver productos'),
        ),
      );
    }

    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: c.superficie,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.linea),
            boxShadow: c.sombra,
          ),
          child: Column(
            children: [
              for (var i = 0; i < pedido.lineas.length; i++)
                _FilaPedido(
                  linea: pedido.lineas[i],
                  primera: i == 0,
                  alCambiar: (cantidad) => ref
                      .read(pedidoBorradorProvider.notifier)
                      .cambiarCantidad(pedido.lineas[i], cantidad),
                  alQuitar: () => ref
                      .read(pedidoBorradorProvider.notifier)
                      .quitar(pedido.lineas[i]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                pedido.articulos == 1
                    ? '1 artículo'
                    : '${pedido.articulos} artículos',
                style: textos.titleMedium?.copyWith(color: c.tinta2),
              ),
            ),
            Text(dinero(pedido.subtotal), style: textos.displaySmall),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _nota,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nota para la caja (opcional)',
            hintText: 'Ej. cliente de la camioneta roja',
          ),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          Text(error, style: TextStyle(color: c.alerta)),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _enviando ? null : () => _enviar(pedido),
          icon: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: const Text('Enviar pedido a la caja'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
        ),
      ],
    );
  }
}

class _FilaPedido extends StatelessWidget {
  const _FilaPedido({
    required this.linea,
    required this.primera,
    required this.alCambiar,
    required this.alQuitar,
  });

  final LineaBorrador linea;
  final bool primera;
  final ValueChanged<int> alCambiar;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = linea.producto;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        border: primera ? null : Border(top: BorderSide(color: c.linea)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 54,
            child: IlustracionProducto(producto: p, radio: 10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  linea.porCaja
                      ? 'Caja de ${p.piezasPorCaja} · ${dinero(linea.precioUnitario)}'
                      : 'Pieza · ${dinero(linea.precioUnitario)}',
                  style: TextStyle(color: c.tinta2, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar ${p.nombre}',
            onPressed: alQuitar,
            icon: const Icon(Icons.delete_outline_rounded),
            color: c.tinta2,
          ),
          _Cantidad(
            cantidad: linea.cantidad,
            alRestar: () => alCambiar(linea.cantidad - 1),
            alSumar: () => alCambiar(linea.cantidad + 1),
          ),
        ],
      ),
    );
  }
}

class _Cantidad extends StatelessWidget {
  const _Cantidad({
    required this.cantidad,
    required this.alRestar,
    required this.alSumar,
  });

  final int cantidad;
  final VoidCallback alRestar;
  final VoidCallback alSumar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.superficie2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Quitar uno',
            onPressed: alRestar,
            icon: const Icon(Icons.remove_rounded),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$cantidad',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: c.tinta,
              fontSize: 16,
            ),
          ),
          IconButton(
            tooltip: 'Agregar uno',
            onPressed: alSumar,
            icon: const Icon(Icons.add_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
