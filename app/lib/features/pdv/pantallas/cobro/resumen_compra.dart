import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../../envases/datos/modelos_envases.dart';
import '../../estado/carrito.dart';
import 'comun.dart';
import 'metodo_pago.dart';

// ============================================================================
// 4.1 RESUMEN FINAL DE COMPRA
// ============================================================================
class ResumenCompra extends ConsumerWidget {
  const ResumenCompra({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final ancho = MediaQuery.sizeOf(context).width;
    final carrito = ref.watch(carritoProvider);
    final precios = ref.watch(preciosEnvasesProvider);
    final deposito = carrito.deposito(precios);
    final divisor = Divider(height: 24, color: c.linea.withValues(alpha: 0.5));

    Widget renglonEnvase(
      IconData icono,
      String texto,
      String monto,
      Color co,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, color: co, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: co,
              ),
            ),
          ),
          Text(
            monto,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: co,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: c.superficie,
        elevation: 0,
        title: Text(
          'Resumen de Compra',
          style: TextStyle(
            color: c.tinta,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        leading: BackButton(color: c.tinta),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: c.linea, height: 1),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ancho > 700 ? 600 : double.infinity,
            ),
            child: Column(
              children: [
                Expanded(
                  child: carrito.vacio
                      ? Center(
                          child: Text(
                            'No hay artículos en la venta',
                            style: TextStyle(color: c.tinta2, fontSize: 16),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          children: [
                            for (final item in carrito.items) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.azul.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${item.cantidad}x',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: c.azul,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        nombreItem(item),
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: c.tinta,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      dinero(item.subtotal),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: c.tinta,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              divisor,
                            ],
                            if (deposito > 0) ...[
                              renglonEnvase(
                                Icons.inventory_2_outlined,
                                'Cargo por Depósito de Envases',
                                '+${dinero(deposito)}',
                                c.azul,
                              ),
                              divisor,
                            ],
                            if (carrito.envModo == ModoEnvases.trae) ...[
                              renglonEnvase(
                                Icons.swap_horiz_rounded,
                                'Intercambio: el cliente entrega vacíos',
                                'Sin costo',
                                c.verde,
                              ),
                              divisor,
                            ],
                            for (final e in carrito.credito.entries) ...[
                              renglonEnvase(
                                Icons.recycling_rounded,
                                'Crédito por Envases (${e.value} pzs '
                                    '${FormatoEnvase.de(e.key).etiqueta})',
                                '-${dinero(e.value * (precios[e.key] ?? 0))}',
                                c.verde,
                              ),
                              divisor,
                            ],
                            if (carrito.envModo == ModoEnvases.prestamo)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.handshake_outlined,
                                      color: Color(0xFFD97706),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Envases asociados como préstamo a: '
                                        '${carrito.envCliente ?? 'cliente'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),

                // Bloque del total, fijo abajo.
                Container(
                  decoration: BoxDecoration(
                    color: c.superficie,
                    border: Border(top: BorderSide(color: c.linea, width: 3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total a Pagar',
                        style: TextStyle(
                          fontSize: 18,
                          color: c.tinta2,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(
                          dinero(ref.watch(totalCarritoProvider)),
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: c.azul,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: carrito.vacio
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MetodoPago(),
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.azul,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: c.linea,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirmar y Pagar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
