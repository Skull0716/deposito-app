import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';
import '../../catalogo/estado/productos.dart';
import '../datos/modelos_ventas.dart';
import '../estado/ventas_provider.dart';
import 'flujo_cancelacion.dart';
import 'modal_reimpresion.dart';

const _ambar = Color(0xFFD97706);

/// 6.2 Detalle de un ticket (diseño de Pablo): embebido en el panel
/// derecho del iPad o en pantalla completa en el teléfono.
class DetalleTicket extends ConsumerWidget {
  const DetalleTicket({
    super.key,
    required this.ventaId,
    this.esModalOEmbebido = false,
  });

  final String ventaId;
  final bool esModalOEmbebido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final detalle = ref.watch(detalleVentaProvider(ventaId));
    final folio = detalle.value?.folio;

    return Scaffold(
      backgroundColor: c.superficie,
      appBar: esModalOEmbebido
          ? null
          : AppBar(
              backgroundColor: c.superficie,
              elevation: 0,
              title: Text(
                folio == null ? 'Detalle de Venta' : 'Detalle de Venta #$folio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.tinta,
                ),
              ),
              leading: IconButton(
                tooltip: Textos.volver,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: c.linea, height: 1),
              ),
            ),
      body: SafeArea(
        child: switch (detalle) {
          AsyncData(:final value) => _Ticket(venta: value),
          AsyncError(:final error) => EstadoError(
            error: error,
            alReintentar: () => ref.invalidate(detalleVentaProvider(ventaId)),
          ),
          _ => const Cargando(),
        },
      ),
    );
  }
}

class _Ticket extends ConsumerWidget {
  const _Ticket({required this.venta});

  final DetalleVenta venta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final metodo = MetodoPago.de(venta.metodo);
    final cancelada = venta.cancelada;
    final parcial = !cancelada && venta.devuelto > 0;
    final productos = ref.watch(productosProvider).value ?? const [];

    Widget renglon(
      String izq,
      String der, {
      Color? color,
      bool fuerte = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(izq, style: TextStyle(color: color ?? c.tinta2)),
          Text(
            der,
            style: TextStyle(
              fontWeight: fuerte ? FontWeight.w700 : FontWeight.w600,
              color: color ?? c.tinta,
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        // Cabecera: folio, método, estado, fecha y cajero
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.superficie,
            border: Border(bottom: BorderSide(color: c.linea)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cancelada
                          ? rojoCancelacion.withValues(alpha: 0.12)
                          : c.azul.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${venta.folio}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: cancelada ? rojoCancelacion : c.azul,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Etiqueta(
                    icono: metodo.icono,
                    texto: metodo.etiqueta,
                    color: metodo.color,
                  ),
                  const Spacer(),
                  if (cancelada)
                    const _Etiqueta(
                      icono: Icons.cancel_rounded,
                      texto: 'CANCELADO',
                      color: rojoCancelacion,
                      borde: true,
                    )
                  else if (parcial)
                    const _Etiqueta(
                      icono: Icons.assignment_return_rounded,
                      texto: 'DEVOLUCIÓN PARCIAL',
                      color: _ambar,
                      borde: true,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Dato(
                    icono: Icons.access_time_rounded,
                    texto: fechaHora(venta.fecha),
                  ),
                  _Dato(
                    icono: Icons.person_outline_rounded,
                    texto: venta.usuario?.nombre ?? venta.origen,
                    fuerte: true,
                  ),
                ],
              ),

              // Devoluciones y cancelación
              for (final d in venta.devoluciones) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: rojoCancelacion.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rojoCancelacion.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: rojoCancelacion,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cancelada && d == venta.devoluciones.last
                                  ? 'Venta Cancelada / Reembolsada'
                                  : 'Devolución parcial',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: rojoCancelacion,
                              ),
                            ),
                          ),
                          Text(
                            '-${dinero(d.monto)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: rojoCancelacion,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: ${d.motivo ?? 'Devolución'}'
                        ' • Destino: ${DestinoStock.de(d.destino).titulo}'
                        '${d.autorizo != null ? ' • Autorizó: ${d.autorizo!.nombre}' : ''}'
                        ' • ${fechaHora(d.fecha)}',
                        style: TextStyle(fontSize: 12, color: c.tinta2),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Desglose de artículos
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'DESGLOSE DE ARTÍCULOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c.tinta2,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              if (venta.lineas.isEmpty)
                Text(
                  'Venta de ${venta.envN} envases vacíos',
                  style: TextStyle(color: c.tinta),
                ),
              for (final l in venta.lineas)
                _LineaDesglose(
                  linea: l,
                  producto: productos
                      .where((p) => p.id == l.productoId)
                      .firstOrNull,
                ),
              const SizedBox(height: 12),
              const Divider(),
              renglon('Subtotal productos', dinero(venta.subtotalProductos)),
              if (venta.envCredito > 0)
                renglon(
                  'Crédito por envases vacíos',
                  '-${dinero(venta.envCredito)}',
                  color: c.verde,
                  fuerte: true,
                ),
              if (venta.envMonto > 0)
                renglon(
                  'Depósito de envases',
                  '+${dinero(venta.envMonto)}',
                  color: _ambar,
                  fuerte: true,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total pagado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: c.tinta,
                    ),
                  ),
                  Text(
                    dinero(venta.total),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: cancelada ? rojoCancelacion : c.tinta,
                      letterSpacing: -0.5,
                      decoration: cancelada ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
              if (venta.metodo == 'efectivo') ...[
                renglon('Recibido', dinero(venta.recibido)),
                renglon('Cambio', dinero(venta.cambio)),
              ],
              if (venta.devuelto > 0)
                renglon(
                  'Devuelto',
                  '-${dinero(venta.devuelto)}',
                  color: rojoCancelacion,
                  fuerte: true,
                ),
            ],
          ),
        ),

        // Acciones fijas: re-imprimir y cancelar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.superficie,
            border: Border(top: BorderSide(color: c.linea)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => ModalReimpresion.mostrar(
                      context: context,
                      venta: venta,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.linea),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 20),
                    label: Text(
                      'Re-imprimir Recibo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.tinta,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: venta.devolvible
                        ? () => FlujoCancelacion.mostrar(
                            context: context,
                            venta: venta,
                          )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: rojoCancelacion,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.linea,
                      disabledForegroundColor: c.tinta2,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: Text(
                      cancelada ? 'Ya Cancelado' : 'Cancelar Venta',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineaDesglose extends StatelessWidget {
  const _LineaDesglose({required this.linea, required this.producto});

  final LineaTicket linea;
  final Producto? producto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final l = linea;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.superficie2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.linea),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: producto == null
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.linea),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: c.tinta2),
                  )
                : IlustracionProducto(producto: producto!, radio: 10),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.tinta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l.cantidad} ${l.porCaja ? 'caja(s) de ${l.piezasPorUnidad} pzs' : 'pza(s)'}'
                  ' x ${dinero(l.precioUnit)}'
                  '${l.descuento > 0 ? ' (−${l.descuento}% de ${dinero(l.precioLista)})' : ''}',
                  style: TextStyle(fontSize: 12, color: c.tinta2),
                ),
                if (l.devueltas > 0)
                  Text(
                    'Devueltas: ${l.devueltas}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rojoCancelacion,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            dinero(l.subtotal),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icono,
    required this.texto,
    required this.color,
    this.borde = false,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final bool borde;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: borde ? 0.15 : 0.12),
      borderRadius: BorderRadius.circular(borde ? 8 : 6),
      border: borde ? Border.all(color: color.withValues(alpha: 0.4)) : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: borde ? 11 : 12,
            fontWeight: borde ? FontWeight.w900 : FontWeight.w700,
            color: color,
            letterSpacing: borde ? 0.5 : 0,
          ),
        ),
      ],
    ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.fuerte = false});

  final IconData icono;
  final String texto;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: c.tinta2),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
            color: fuerte ? c.tinta : c.tinta2,
          ),
        ),
      ],
    );
  }
}
