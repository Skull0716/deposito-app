import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/pedido.dart';

/// Un renglón del pedido que se arma en la terminal.
class LineaBorrador {
  const LineaBorrador({
    required this.producto,
    required this.porCaja,
    required this.cantidad,
  });

  final Producto producto;
  final bool porCaja;
  final int cantidad;

  String get clave => '${producto.id}_${porCaja ? 'caja' : 'pieza'}';

  int get precioUnitario =>
      porCaja ? producto.precioCaja ?? 0 : producto.precio;

  int get subtotal => precioUnitario * cantidad;

  int get piezas =>
      porCaja ? (producto.piezasPorCaja ?? 1) * cantidad : cantidad;

  LineaPedido get linea => LineaPedido(
    productoId: producto.id,
    unidad: porCaja ? UnidadPedido.caja : UnidadPedido.pieza,
    cantidad: cantidad,
  );

  LineaBorrador con(int cantidad) =>
      LineaBorrador(producto: producto, porCaja: porCaja, cantidad: cantidad);
}

/// Pedido en construcción de la terminal. No revisa existencias: el contrato
/// dice que se revisan al cobrar en la caja.
class PedidoBorrador {
  const PedidoBorrador(this.lineas);

  final List<LineaBorrador> lineas;

  bool get vacio => lineas.isEmpty;

  /// Cajas y piezas pedidas, para la insignia de la pestaña.
  int get articulos => lineas.fold(0, (t, l) => t + l.cantidad);

  int get subtotal => lineas.fold(0, (t, l) => t + l.subtotal);
}

final pedidoBorradorProvider =
    NotifierProvider<PedidoBorradorNotifier, PedidoBorrador>(
      PedidoBorradorNotifier.new,
    );

class PedidoBorradorNotifier extends Notifier<PedidoBorrador> {
  @override
  PedidoBorrador build() => const PedidoBorrador([]);

  /// Agrega uno; si ya estaba, sube la cantidad.
  void agregar(Producto producto, {bool porCaja = false}) {
    final clave = '${producto.id}_${porCaja ? 'caja' : 'pieza'}';
    final i = state.lineas.indexWhere((l) => l.clave == clave);
    if (i < 0) {
      state = PedidoBorrador([
        ...state.lineas,
        LineaBorrador(producto: producto, porCaja: porCaja, cantidad: 1),
      ]);
    } else {
      _cambiar(state.lineas[i], state.lineas[i].cantidad + 1);
    }
  }

  /// Pone [cantidad] en el renglón; `0` lo quita.
  void cambiarCantidad(LineaBorrador linea, int cantidad) {
    if (cantidad < 1) return quitar(linea);
    _cambiar(linea, cantidad);
  }

  void quitar(LineaBorrador linea) {
    state = PedidoBorrador([
      for (final l in state.lineas)
        if (l.clave != linea.clave) l,
    ]);
  }

  void vaciar() => state = const PedidoBorrador([]);

  void _cambiar(LineaBorrador linea, int cantidad) {
    final i = state.lineas.indexWhere((l) => l.clave == linea.clave);
    if (i < 0) return;
    final lineas = [...state.lineas];
    lineas[i] = linea.con(cantidad);
    state = PedidoBorrador(lineas);
  }
}
