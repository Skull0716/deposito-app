import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/idempotencia.dart';
import '../../envases/estado/envases_provider.dart';

/// Un renglón del carrito: piezas sueltas o cajas completas de un producto.
class ItemCarrito {
  const ItemCarrito({
    required this.producto,
    required this.porCaja,
    required this.cantidad,
    this.descuento = 0,
  });

  final Producto producto;
  final bool porCaja;
  final int cantidad;

  /// Porcentaje de 0 a 99.
  final int descuento;

  String get clave => '${producto.id}_${porCaja ? 'caja' : 'pieza'}';

  /// Centavos por pieza o por caja, antes del descuento.
  int get precioLista => porCaja ? producto.precioCaja! : producto.precio;

  /// Centavos por pieza o por caja, con el descuento por unidad truncado al
  /// centavo: la misma cuenta que hace el servidor (docs/API.md).
  int get precioUnitario => precioLista - precioLista * descuento ~/ 100;

  int get subtotal => precioUnitario * cantidad;

  int get piezas => porCaja ? producto.piezasPorCaja! * cantidad : cantidad;

  LineaVenta get linea => LineaVenta(
    productoId: producto.id,
    porCaja: porCaja,
    cantidad: cantidad,
    descuento: descuento,
  );

  ItemCarrito con({int? cantidad, int? descuento}) => ItemCarrito(
    producto: producto,
    porCaja: porCaja,
    cantidad: cantidad ?? this.cantidad,
    descuento: descuento ?? this.descuento,
  );
}

/// Qué pasa con los envases retornables de la venta (`envModo`).
enum ModoEnvases {
  /// Aún no se decide (o no hay retornables).
  na,

  /// Se cobra el depósito.
  cobrar,

  /// El cliente entrega la misma cantidad de vacíos: intercambio sin costo.
  trae,

  /// Se le prestan a un cliente.
  prestamo,
}

class Carrito {
  const Carrito(
    this.items,
    this.claveCobro, {
    this.envModo = ModoEnvases.na,
    this.envCliente,
    this.credito = const {},
  });

  final List<ItemCarrito> items;

  /// `X-Clave-Idempotencia` del cobro. Cambia cada vez que cambia el carrito:
  /// reintentar el mismo carrito no cobra dos veces, y uno distinto sí cobra.
  final String claveCobro;

  final ModoEnvases envModo;

  /// Cliente del préstamo, con [ModoEnvases.prestamo].
  final String? envCliente;

  /// Vacíos extra que entrega el cliente, por formato: se descuenta su
  /// depósito del ticket.
  final Map<String, int> credito;

  bool get vacio => items.isEmpty;

  /// Productos, ya con descuento, en centavos.
  int get subtotal => items.fold(0, (t, i) => t + i.subtotal);

  int get articulos => items.fold(0, (t, i) => t + i.cantidad);

  int piezasDe(String productoId) => items
      .where((i) => i.producto.id == productoId)
      .fold(0, (t, i) => t + i.piezas);

  /// Piezas retornables por formato (`mega`, `media`, `cuarto`).
  Map<String, int> get retornables {
    final r = <String, int>{};
    for (final i in items) {
      final f = i.producto.envase;
      if (f != null) r[f] = (r[f] ?? 0) + i.piezas;
    }
    return r;
  }

  int get totalRetornables => retornables.values.fold(0, (t, n) => t + n);

  /// Depósito que se cobra con [ModoEnvases.cobrar], con los precios del
  /// balance (formato → centavos).
  int deposito(Map<String, int> precios) => envModo == ModoEnvases.cobrar
      ? retornables.entries.fold(
          0,
          (t, e) => t + e.value * (precios[e.key] ?? 0),
        )
      : 0;

  int montoCredito(Map<String, int> precios) =>
      credito.entries.fold(0, (t, e) => t + e.value * (precios[e.key] ?? 0));

  /// Lo que se cobra: productos + depósito − crédito.
  int total(Map<String, int> precios) =>
      subtotal + deposito(precios) - montoCredito(precios);

  List<LineaVenta> get lineas => [for (final i in items) i.linea];

  /// Hay retornables y todavía no se dijo qué pasa con sus envases.
  bool get envasesPendientes =>
      totalRetornables > 0 && envModo == ModoEnvases.na;
}

final carritoProvider = NotifierProvider<CarritoNotifier, Carrito>(
  CarritoNotifier.new,
);

class CarritoNotifier extends Notifier<Carrito> {
  @override
  Carrito build() => Carrito(const [], nuevaClaveIdempotencia());

  /// Agrega uno. Regresa el motivo si no alcanza la existencia.
  String? agregar(Producto p, {bool porCaja = false}) {
    final actual = state.items.where(
      (i) => i.producto.id == p.id && i.porCaja == porCaja,
    );
    return cambiarCantidad(
      actual.isEmpty
          ? ItemCarrito(producto: p, porCaja: porCaja, cantidad: 0)
          : actual.first,
      (actual.isEmpty ? 0 : actual.first.cantidad) + 1,
    );
  }

  /// Carga un pedido de terminal al ticket. No frena por existencias: el
  /// servidor las revisa al cobrar (docs/API.md). Regresa los nombres de los
  /// productos que quedaron por encima de la existencia, para avisar.
  List<String> cargarPedido(
    List<({Producto producto, bool porCaja, int cantidad})> lineas,
  ) {
    final items = [...state.items];
    for (final l in lineas) {
      final porCaja =
          l.porCaja &&
          l.producto.piezasPorCaja != null &&
          l.producto.precioCaja != null;
      final clave = '${l.producto.id}_${porCaja ? 'caja' : 'pieza'}';
      final i = items.indexWhere((x) => x.clave == clave);
      final base = i < 0
          ? ItemCarrito(producto: l.producto, porCaja: porCaja, cantidad: 0)
          : items[i];
      final nuevo = base.con(cantidad: base.cantidad + l.cantidad);
      if (i < 0) {
        items.add(nuevo);
      } else {
        items[i] = nuevo;
      }
    }
    _cambiar(items: items);

    final conflictos = <String>{};
    for (final l in lineas) {
      final piezas = state.items
          .where((i) => i.producto.id == l.producto.id)
          .fold(0, (t, i) => t + i.piezas);
      if (piezas > l.producto.existenciaPiezas) {
        conflictos.add(l.producto.nombre);
      }
    }
    return conflictos.toList();
  }

  /// Pone [cantidad] en el renglón de [item]; `0` lo quita. Regresa el
  /// motivo si no alcanza la existencia.
  String? cambiarCantidad(ItemCarrito item, int cantidad) {
    final otros = state.items.where((i) => i.clave != item.clave).toList();
    if (cantidad > 0) {
      final nuevo = item.con(cantidad: cantidad);
      final piezas =
          nuevo.piezas +
          otros
              .where((i) => i.producto.id == item.producto.id)
              .fold(0, (t, i) => t + i.piezas);
      if (piezas > item.producto.existenciaPiezas) {
        return item.producto.existenciaPiezas == 0
            ? 'No hay ${item.producto.nombre} en existencia'
            : 'Solo hay ${item.producto.existenciaPiezas} piezas de '
                  '${item.producto.nombre}';
      }
      _reemplazar(item.clave, nuevo);
    } else {
      _cambiar(items: otros);
    }
    return null;
  }

  /// Descuento de 0 a 99 % en el renglón de [item].
  void ponerDescuento(ItemCarrito item, int porcentaje) {
    final i = state.items.indexWhere((x) => x.clave == item.clave);
    if (i < 0) return;
    _reemplazar(
      item.clave,
      state.items[i].con(descuento: porcentaje.clamp(0, 99)),
    );
  }

  /// Suma [cantidad] vacíos de [formato] al crédito del ticket.
  void agregarCredito(String formato, int cantidad) {
    if (cantidad <= 0) return;
    _cambiar(
      credito: {
        ...state.credito,
        formato: (state.credito[formato] ?? 0) + cantidad,
      },
    );
  }

  void quitarCredito(String formato) =>
      _cambiar(credito: {...state.credito}..remove(formato));

  /// Decide qué pasa con los envases de la venta.
  void resolverEnvases(ModoEnvases modo, {String? cliente}) =>
      _cambiar(envModo: modo, envCliente: cliente, cambiarCliente: true);

  void vaciar() => state = Carrito(const [], nuevaClaveIdempotencia());

  void _reemplazar(String clave, ItemCarrito nuevo) {
    final items = [...state.items];
    final i = items.indexWhere((x) => x.clave == clave);
    if (i < 0) {
      items.add(nuevo);
    } else {
      items[i] = nuevo;
    }
    _cambiar(items: items);
  }

  void _cambiar({
    List<ItemCarrito>? items,
    ModoEnvases? envModo,
    String? envCliente,
    bool cambiarCliente = false,
    Map<String, int>? credito,
  }) {
    final nuevosItems = items ?? state.items;
    state = Carrito(
      nuevosItems,
      nuevaClaveIdempotencia(),
      // Sin retornables no hay nada que decidir.
      envModo: nuevosItems.any((i) => i.producto.envase != null)
          ? (envModo ?? state.envModo)
          : ModoEnvases.na,
      envCliente: cambiarCliente ? envCliente : state.envCliente,
      credito: credito ?? state.credito,
    );
  }
}

/// Depósito por envase de cada formato, del balance (formato → centavos).
final preciosEnvasesProvider = Provider<Map<String, int>>((ref) {
  final estado = ref.watch(envasesProvider).value;
  return {
    for (final b in estado?.balance.values ?? const <BalanceEnvase>[])
      b.formato: b.precio,
  };
});

/// Lo que se cobra del carrito: productos + depósito − crédito, en centavos.
final totalCarritoProvider = Provider<int>(
  (ref) => ref.watch(carritoProvider).total(ref.watch(preciosEnvasesProvider)),
);
