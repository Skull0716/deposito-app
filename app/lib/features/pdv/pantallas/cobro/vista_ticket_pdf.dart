import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/fallo_api.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/textos.dart';
import '../../../../core/ticket/ticket_pdf.dart';
import '../../../../core/widgets/estados.dart';
import 'comun.dart';

// ============================================================================
// 4.9 VISTA PREVIA DEL TICKET
// ============================================================================
/// El ticket como sale en el PDF (ticket_pdf.dart), con imprimir, compartir
/// y cerrar para la siguiente venta.
class VistaTicketPdf extends StatelessWidget {
  const VistaTicketPdf({super.key, required this.venta, required this.negocio});

  final DetalleVenta venta;
  final AjustesNegocio negocio;

  void _nuevaVenta(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  Future<void> _accion(
    BuildContext context,
    Future<void> Function(DetalleVenta, AjustesNegocio) accion,
  ) async {
    try {
      await accion(venta, negocio);
    } catch (e) {
      if (context.mounted) {
        avisar(context, 'No se pudo generar el recibo: ${mensajeDeError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esTablet = MediaQuery.sizeOf(context).width >= 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: SingleChildScrollView(
            child: esTablet
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: _ticket()),
                      const SizedBox(width: 24),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AccionFlotante(
                            icono: Icons.print_rounded,
                            etiqueta: 'Imprimir',
                            alTocar: () => _accion(context, imprimirTicket),
                          ),
                          const SizedBox(height: 12),
                          _AccionFlotante(
                            icono: Icons.share_rounded,
                            etiqueta: 'Compartir',
                            alTocar: () => _accion(context, compartirTicket),
                          ),
                          const SizedBox(height: 24),
                          FloatingActionButton(
                            heroTag: 'cerrar_ticket',
                            tooltip: Textos.cerrar,
                            onPressed: () => _nuevaVenta(context),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.redAccent,
                            elevation: 4,
                            child: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ticket(),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _accion(context, imprimirTicket),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('Imprimir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _accion(context, compartirTicket),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Compartir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _nuevaVenta(context),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text(Textos.cerrar),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: rojoRechazo,
                              foregroundColor: Colors.white,
                            ),
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

  Widget _ticket() {
    const chica = TextStyle(fontSize: 11, color: Colors.black54);
    const renglon = TextStyle(fontSize: 13, color: Colors.black87);
    const divisor = Divider(color: Colors.black87, thickness: 1.2);
    final v = venta;

    Widget fila(String izq, String der, {TextStyle estilo = renglon}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text(izq, style: estilo)),
              Text(der, style: estilo),
            ],
          ),
        );

    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 580),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (negocio.nombreNegocio ?? 'Depósito').toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.black,
                ),
              ),
              if (negocio.direccion != null) ...[
                const SizedBox(height: 4),
                Text(
                  negocio.direccion!,
                  textAlign: TextAlign.center,
                  style: chica,
                ),
              ],
              if (negocio.telefono != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tel. ${negocio.telefono}',
                  textAlign: TextAlign.center,
                  style: chica,
                ),
              ],
              const SizedBox(height: 12),
              divisor,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Folio: #${v.folio}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    fechaHora(v.fecha),
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ],
              ),
              if (v.usuario != null)
                Text(
                  'Atendió: ${v.usuario!.nombre}',
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                ),
              divisor,
              const SizedBox(height: 8),
              for (final l in v.lineas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.cantidad}x ${l.nombre}'
                          '${l.porCaja ? ' (Caja)' : ''}'
                          '${l.descuento > 0 ? ' −${l.descuento}%' : ''}',
                          style: renglon,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dinero(l.subtotal),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              if (v.lineas.isEmpty) fila('Envases vacíos (${v.envN})', ''),
              const SizedBox(height: 8),
              divisor,
              fila('Subtotal:', dinero(v.subtotalProductos)),
              if (v.envMonto > 0)
                fila('Depósito de envases:', '+${dinero(v.envMonto)}'),
              if (v.envCredito > 0)
                fila('Crédito por vacíos:', '-${dinero(v.envCredito)}'),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    dinero(v.total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              fila(
                v.metodo == 'tarjeta' ? 'Tarjeta:' : 'Efectivo:',
                dinero(v.recibido),
              ),
              if (v.cambio > 0) fila('Cambio:', dinero(v.cambio)),
              const SizedBox(height: 16),
              divisor,
              const SizedBox(height: 12),
              Text(
                negocio.mensajeTicket ?? '¡Gracias por su compra!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              const Text(
                'Conserve este comprobante para devoluciones',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccionFlotante extends StatelessWidget {
  const _AccionFlotante({
    required this.icono,
    required this.etiqueta,
    required this.alTocar,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: etiqueta,
          tooltip: etiqueta,
          onPressed: alTocar,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 4,
          child: Icon(icono),
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
