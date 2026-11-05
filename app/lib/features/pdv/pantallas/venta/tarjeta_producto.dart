import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/widgets/ilustracion_producto.dart';

class TarjetaProductoVenta extends StatelessWidget {
  const TarjetaProductoVenta({
    super.key,
    required this.producto,
    required this.enCarrito,
    required this.alTocar,
  });

  final Producto producto;

  /// Piezas de este producto que ya están en la venta.
  final int enCarrito;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final agotado = producto.existenciaPiezas - enCarrito <= 0;
    return Opacity(
      opacity: agotado ? 0.5 : 1,
      child: Material(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: enCarrito > 0 ? c.azul : c.linea),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: IlustracionProducto(producto: producto, radio: 0),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.tinta,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agotado ? 'Agotado' : existenciaLegible(producto),
                        style: TextStyle(
                          fontSize: 12,
                          color: agotado ? c.alerta : c.tinta2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dinero(producto.precio),
                            style: TextStyle(
                              color: c.azul,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (producto.precioCaja != null)
                            Icon(
                              Icons.layers_outlined,
                              size: 16,
                              color: c.tinta2,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BotonVariante extends StatelessWidget {
  const BotonVariante({
    super.key,
    required this.icono,
    required this.texto,
    required this.precio,
    required this.alPresionar,
  });

  final IconData icono;
  final String texto;

  /// Centavos.
  final int precio;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: c.linea),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icono, size: 40, color: c.azul),
            const SizedBox(height: 12),
            Text(
              texto,
              style: TextStyle(fontWeight: FontWeight.bold, color: c.tinta),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(dinero(precio), style: TextStyle(color: c.tinta2)),
          ],
        ),
      ),
    );
  }
}
