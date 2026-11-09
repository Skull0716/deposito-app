import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';

import '../../app/tema/colores.dart';
import '../../app/tema/tema.dart';
import '../formato/formato.dart';
import 'ilustracion_producto.dart';

/// Mosaico de producto para cuadrículas (catálogo, vender, terminal).
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto, this.alTocar});

  final Producto producto;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final p = producto;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: IlustracionProducto(producto: p)),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InsigniaExistencia(producto: p),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  p.nombre,
                  style: textos.titleMedium?.copyWith(height: 1.15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  p.presentacion ?? capitalizar(p.categoria),
                  style: textos.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Inline como en el diseño: si el precio es largo o el texto
                // está muy grande, "caja $…" baja a otro renglón en vez de
                // desbordar la tarjeta.
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(dinero(p.precio), style: textos.headlineSmall),
                    Text(
                      p.precioCaja == null
                          ? 'pieza'
                          : 'caja ${dinero(p.precioCaja!)}',
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora con la existencia; en rojo si está bajo el mínimo.
class InsigniaExistencia extends StatelessWidget {
  const InsigniaExistencia({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final bajo = producto.bajoMinimo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bajo ? c.alerta : c.superficie.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${producto.existenciaPiezas} pz',
        style: TextStyle(
          fontFamily: fuenteTexto,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: bajo ? Colors.white : c.tinta,
        ),
      ),
    );
  }
}
