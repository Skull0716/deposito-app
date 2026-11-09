import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/api/fallo_api.dart';
import '../../../../core/api/proveedores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/ticket/ticket_pdf.dart';
import '../../../../core/widgets/estados.dart';
import 'comun.dart';
import 'vista_ticket_pdf.dart';

// ============================================================================
// 4.7 VENTA EXITOSA Y 4.8 OPCIONES DE RECIBO
// ============================================================================
class VentaExitosa extends ConsumerStatefulWidget {
  const VentaExitosa({super.key, required this.venta});

  final VentaRegistrada venta;

  @override
  ConsumerState<VentaExitosa> createState() => _VentaExitosaState();
}

class _VentaExitosaState extends ConsumerState<VentaExitosa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  bool _mostrarOpciones = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    // Pasa sola a las opciones de recibo.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _mostrarOpciones = true);
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  void _nuevaVenta() {
    HapticFeedback.lightImpact();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Pide el ticket completo y los datos del negocio para [accion].
  Future<void> _conTicket(
    Future<void> Function(DetalleVenta, AjustesNegocio) accion,
  ) async {
    try {
      final api = await ref.read(apiProvider.future);
      final detalle = await api.obtenerVenta(widget.venta.id);
      final negocio = await ref.read(ajustesNegocioProvider.future);
      await accion(detalle, negocio);
    } catch (e) {
      if (mounted) {
        avisar(context, 'No se pudo generar el recibo: ${mensajeDeError(e)}');
      }
    }
  }

  /// 4.9: vista previa del ticket, con imprimir y compartir.
  void _verTicket() => _conTicket(
    (detalle, negocio) => showDialog<void>(
      context: context,
      builder: (_) => VistaTicketPdf(venta: detalle, negocio: negocio),
    ),
  );

  /// La hoja de compartir del sistema, donde está WhatsApp.
  void _whatsApp() => _conTicket(compartirTicket);

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final v = widget.venta;

    // 4.7 Cobro exitoso: palomita animada.
    if (!_mostrarOpciones) {
      return Scaffold(
        backgroundColor: c.fondo,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _checkCtrl,
                  curve: Curves.elasticOut,
                ),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: verdeExito.withValues(alpha: 0.12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 180,
                      color: verdeExito,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '¡Cobro Exitoso!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: verdeExito,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4.8 Opciones de recibo.
    final opciones = [
      (
        Icons.print_rounded,
        'Imprimir Ticket',
        'Imprimir Ticket',
        c.azul,
        _verTicket,
      ),
      (
        Icons.chat_rounded,
        'WhatsApp',
        'Enviar por WhatsApp',
        const Color(0xFF25D366),
        _whatsApp,
      ),
      (
        Icons.do_not_disturb_alt_rounded,
        'Sin Recibo',
        'Sin Recibo (Listo)',
        c.tinta2,
        _nuevaVenta,
      ),
    ];
    final ancho = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: c.fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: verdeExito,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¡Venta Registrada con Éxito!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: c.tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Folio #${v.folio} • Total: ${dinero(v.total)}'
                    '${v.cambio > 0 ? ' • Cambio: ${dinero(v.cambio)}' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: c.tinta2),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    '¿Cómo desea su recibo?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: c.tinta,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (ancho >= 650)
                    Row(
                      children: [
                        for (final (i, o) in opciones.indexed) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(
                            child: _BotonRecibo(
                              icono: o.$1,
                              texto: o.$2,
                              colorIcono: o.$4,
                              alTocar: o.$5,
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (final (i, o) in opciones.indexed) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _BotonReciboHorizontal(
                            icono: o.$1,
                            texto: o.$3,
                            colorIcono: o.$4,
                            alTocar: o.$5,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonRecibo extends StatelessWidget {
  const _BotonRecibo({
    required this.icono,
    required this.texto,
    required this.colorIcono,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final Color colorIcono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: c.superficie,
          border: Border.all(color: c.linea),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 54, color: colorIcono),
            const SizedBox(height: 14),
            Text(
              texto,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.tinta,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonReciboHorizontal extends StatelessWidget {
  const _BotonReciboHorizontal({
    required this.icono,
    required this.texto,
    required this.colorIcono,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final Color colorIcono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: c.superficie,
          border: Border.all(color: c.linea),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icono, size: 30, color: colorIcono),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.tinta,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: c.tinta2),
          ],
        ),
      ),
    );
  }
}
