import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/ticket/ticket_pdf.dart';
import '../../../core/widgets/estados.dart';

/// 6.3 Re-impresión (diseño de Pablo): panel inferior para imprimir el
/// recibo o compartirlo en PDF (WhatsApp, AirDrop...).
class ModalReimpresion extends ConsumerWidget {
  const ModalReimpresion({super.key, required this.venta});

  final DetalleVenta venta;

  static Future<void> mostrar({
    required BuildContext context,
    required DetalleVenta venta,
  }) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ModalReimpresion(venta: venta),
  );

  Future<void> _accion(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(DetalleVenta, AjustesNegocio) accion,
  ) async {
    final negocio = await ref.read(ajustesNegocioProvider.future);
    if (!context.mounted) return;
    Navigator.pop(context);
    try {
      await accion(venta, negocio);
    } catch (_) {
      if (context.mounted) {
        avisar(context, 'No se pudo generar el recibo. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;

    Widget opcion({
      required IconData icono,
      required Color color,
      required String titulo,
      required String detalle,
      required VoidCallback alTocar,
    }) => Material(
      color: c.superficie2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.linea),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.tinta,
                      ),
                    ),
                    Text(
                      detalle,
                      style: TextStyle(fontSize: 12, color: c.tinta2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.tinta2),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: c.linea,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: c.azul, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opciones de recibo',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: c.tinta,
                        ),
                      ),
                      Text(
                        'Folio #${venta.folio} • ${dinero(venta.total)}',
                        style: TextStyle(fontSize: 13, color: c.tinta2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: Textos.cerrar,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            opcion(
              icono: Icons.print_rounded,
              color: c.azul,
              titulo: 'Imprimir recibo',
              detalle: 'Impresora del sistema o AirPrint',
              alTocar: () => _accion(context, ref, imprimirTicket),
            ),
            const SizedBox(height: 12),
            opcion(
              icono: Icons.share_rounded,
              color: const Color(0xFF16A34A),
              titulo: 'Compartir PDF / WhatsApp',
              detalle: 'Comprobante digital para enviar al cliente',
              alTocar: () => _accion(context, ref, compartirTicket),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                Textos.cerrar,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.tinta2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
