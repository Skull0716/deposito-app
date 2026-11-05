/// Unidad en la que se pide un producto: pieza suelta o caja completa.
enum UnidadPedido {
  pieza('pieza'),
  caja('caja');

  const UnidadPedido(this.valor);

  /// Como viaja en el contrato (`docs/API.md`).
  final String valor;

  bool get porCaja => this == caja;

  static UnidadPedido desde(String valor) =>
      values.firstWhere((u) => u.valor == valor, orElse: () => pieza);
}

/// Un renglón de un pedido de terminal.
class LineaPedido {
  const LineaPedido({
    required this.productoId,
    required this.unidad,
    required this.cantidad,
  });

  final String productoId;
  final UnidadPedido unidad;
  final int cantidad;

  Map<String, Object?> toJson() => {
    'productoId': productoId,
    'unidad': unidad.valor,
    'cantidad': cantidad,
  };

  factory LineaPedido.fromJson(Map<String, Object?> json) => LineaPedido(
    productoId: json['productoId'] as String,
    unidad: UnidadPedido.desde(json['unidad'] as String),
    cantidad: json['cantidad'] as int,
  );
}

/// Pedido que arma una terminal y cobra la caja (`/api/v1/pedidos`).
class Pedido {
  const Pedido({
    required this.id,
    required this.origen,
    required this.fecha,
    required this.lineas,
    this.nota,
  });

  final String id;

  /// Nombre de la terminal que lo mandó.
  final String origen;

  /// Instante ISO en que se creó.
  final String fecha;
  final String? nota;
  final List<LineaPedido> lineas;

  int get articulos => lineas.fold(0, (t, l) => t + l.cantidad);

  factory Pedido.fromJson(Map<String, Object?> json) => Pedido(
    id: json['id'] as String,
    origen: json['origen'] as String,
    fecha: json['fecha'] as String,
    nota: json['nota'] as String?,
    lineas: [
      for (final l in json['lineas'] as List)
        LineaPedido.fromJson((l as Map).cast()),
    ],
  );
}
