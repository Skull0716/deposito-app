import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/textos.dart';
import '../../../envases/datos/modelos_envases.dart';
import '../../estado/carrito.dart';
import 'comun.dart';

/// La venta en curso (diseño de Pablo): renglones, crédito por vacíos,
/// depósito de envases y total. A la derecha en el iPad; en una hoja en el
/// teléfono.
class PanelVenta extends ConsumerWidget {
  const PanelVenta({
    super.key,
    required this.itemReciente,
    required this.alEditar,
    required this.alRecibirVacios,
    required this.alCobrar,
    this.movil = false,
    this.alCerrar,
  });

  final String? itemReciente;
  final void Function(ItemCarrito) alEditar;
  final VoidCallback alRecibirVacios;
  final VoidCallback alCobrar;
  final bool movil;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final carrito = ref.watch(carritoProvider);
    final precios = ref.watch(preciosEnvasesProvider);
    final deposito = carrito.deposito(precios);
    final credito = carrito.montoCredito(precios);
    final total = carrito.total(precios);
    final vacio = carrito.vacio && carrito.credito.isEmpty;

    Widget renglonTotal(String texto, String monto, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            monto,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    final botonVacios = TextButton.icon(
      onPressed: alRecibirVacios,
      icon: const Icon(Icons.recycling_rounded, size: 16),
      label: Text(
        movil ? '+ Vacíos' : '+ Recibir Vacíos',
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: c.verde,
        backgroundColor: c.verdeSuave,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Column(
      children: [
        if (movil) ...[
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.linea,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: movil ? 14 : 16,
          ),
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.superficie,
            border: Border(bottom: BorderSide(color: c.linea)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  movil
                      ? 'Carrito (${carrito.articulos} items)'
                      : 'Venta Actual',
                  style: TextStyle(
                    fontSize: movil ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: c.tinta,
                  ),
                ),
              ),
              Flexible(child: botonVacios),
              if (alCerrar != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: Textos.cerrar,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: alCerrar,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: vacio
              ? CarritoVacio(c: c)
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final item in carrito.items) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        color: item.clave == itemReciente
                            ? c.azul.withValues(alpha: 0.1)
                            : Colors.transparent,
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            title: Text(
                              nombreItem(item),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: c.tinta,
                              ),
                            ),
                            subtitle: Text(
                              '${dinero(item.precioUnitario)} x ${item.cantidad}'
                              '${item.descuento > 0 ? ' (−${item.descuento}%)' : ''}',
                              style: TextStyle(color: c.tinta2),
                            ),
                            trailing: Text(
                              dinero(item.subtotal),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: c.tinta,
                              ),
                            ),
                            onTap: () => alEditar(item),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    for (final e in carrito.credito.entries)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.verdeSuave,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.verde.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.recycling_rounded,
                              color: c.verde,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Crédito por Envase (${e.value} '
                                    '${FormatoEnvase.de(e.key).etiqueta})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: c.verde,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (!movil)
                                    Text(
                                      'Descontado del subtotal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.verde.withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '-${dinero(e.value * (precios[e.key] ?? 0))}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: c.verde,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Quitar crédito',
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: c.verde,
                              ),
                              onPressed: () => ref
                                  .read(carritoProvider.notifier)
                                  .quitarCredito(e.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    if (carrito.envModo != ModoEnvases.na)
                      AvisoEnvases(
                        modo: carrito.envModo,
                        cliente: carrito.envCliente,
                        deposito: deposito,
                        alCambiar: () => ref
                            .read(carritoProvider.notifier)
                            .resolverEnvases(ModoEnvases.na),
                      ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.superficie,
            border: movil ? Border(top: BorderSide(color: c.linea)) : null,
            boxShadow: movil
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!movil)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(color: c.tinta2, fontSize: 16),
                        ),
                        Text(
                          dinero(carrito.subtotal),
                          style: TextStyle(color: c.tinta, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                if (credito > 0)
                  renglonTotal(
                    movil ? 'Crédito por Envases' : 'Crédito Envases',
                    '-${dinero(credito)}',
                    c.verde,
                  ),
                if (deposito > 0)
                  renglonTotal(
                    movil ? 'Cargo Depósitos' : 'Depósito Envases',
                    '+${dinero(deposito)}',
                    c.alerta,
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        color: c.tinta,
                        fontSize: movil ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dinero(total),
                      style: TextStyle(
                        color: total < 0 ? c.alerta : c.azul,
                        fontSize: movil ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
                if (total < 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'El crédito pasa del total: quita vacíos o usa '
                      '"Devolver depósito" en Envases',
                      style: TextStyle(fontSize: 12, color: c.alerta),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: carrito.vacio || total < 0 ? null : alCobrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.azul,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.linea,
                      padding: EdgeInsets.symmetric(vertical: movil ? 18 : 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      movil ? 'Ir al Pago' : 'Cobrar',
                      style: TextStyle(
                        fontSize: movil ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Qué se decidió con los envases de la venta, con opción de cambiarlo.
class AvisoEnvases extends StatelessWidget {
  const AvisoEnvases({
    super.key,
    required this.modo,
    required this.cliente,
    required this.deposito,
    required this.alCambiar,
  });

  final ModoEnvases modo;
  final String? cliente;
  final int deposito;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Colores de Pablo: depósito en alerta, intercambio en verde y préstamo
    // en azul con el apretón de manos.
    final (icono, texto, color, monto) = switch (modo) {
      ModoEnvases.cobrar => (
        Icons.inventory_2_outlined,
        'Depósito de Envases',
        c.alerta,
        '+${dinero(deposito)}',
      ),
      ModoEnvases.trae => (
        Icons.swap_horiz_rounded,
        'Intercambio: el cliente entrega vacíos',
        c.verde,
        null,
      ),
      ModoEnvases.prestamo => (
        Icons.handshake_outlined,
        'Préstamo a: ${cliente ?? 'cliente'}',
        c.azul,
        null,
      ),
      ModoEnvases.na => (Icons.help_outline, '', c.tinta, null),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: modo == ModoEnvases.cobrar ? c.tinta : color,
                fontSize: 13,
              ),
            ),
          ),
          if (monto != null)
            Text(
              monto,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          TextButton(onPressed: alCambiar, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}

class CarritoVacio extends StatelessWidget {
  const CarritoVacio({super.key, required this.c});
  final ColoresAnaquel c;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_basket_outlined, size: 80, color: c.linea),
        const SizedBox(height: 16),
        Text(
          'Aún no hay productos en la venta',
          style: TextStyle(color: c.tinta2, fontSize: 16),
        ),
      ],
    );
  }
}
