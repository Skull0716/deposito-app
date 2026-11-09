import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../datos/modelos_envases.dart';
import '../estado/envases_provider.dart';
import 'selector_envases.dart';

/// Lo que se capturó en el retorno.
typedef RetornoCapturado = ({
  FormatoEnvase formato,
  int cantidad,
  String? cliente,
});

/// 5.6 Retorno de envases (diseño de Pablo).
///
/// Sin [prestamo]: el cliente regresa vacíos por los que pagó depósito y se
/// le entrega el efectivo (retiro de caja). Con [prestamo]: regresa envases
/// prestados, total o parcialmente, sin dinero (el préstamo no cobró
/// depósito).
class ModalRetornoDeposito extends ConsumerStatefulWidget {
  const ModalRetornoDeposito({super.key, this.prestamo});

  final PrestamoEnvase? prestamo;

  static Future<RetornoCapturado?> mostrar(
    BuildContext context, {
    PrestamoEnvase? prestamo,
  }) => showDialog<RetornoCapturado>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ModalRetornoDeposito(prestamo: prestamo),
  );

  @override
  ConsumerState<ModalRetornoDeposito> createState() =>
      _ModalRetornoDepositoState();
}

class _ModalRetornoDepositoState extends ConsumerState<ModalRetornoDeposito> {
  late int _cantidad = widget.prestamo?.cantidad ?? 1;
  late FormatoEnvase _formato = widget.prestamo == null
      ? FormatoEnvase.media
      : FormatoEnvase.de(widget.prestamo!.formato);
  final _clienteCtrl = TextEditingController();

  bool get _esPrestamo => widget.prestamo != null;

  @override
  void dispose() {
    _clienteCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final cliente = _clienteCtrl.text.trim();
    Navigator.pop(context, (
      formato: _formato,
      cantidad: _cantidad,
      cliente: _esPrestamo
          ? widget.prestamo!.cliente
          : (cliente.isEmpty ? null : cliente),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final precio = ref.watch(envasesProvider).value?.precio(_formato) ?? 0;
    final reembolso = _cantidad * precio;
    final p = widget.prestamo;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: c.superficie,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.verde.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _esPrestamo
                              ? Icons.download_rounded
                              : Icons.payments_outlined,
                          color: c.verde,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Retorno de Envases',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: c.tinta,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _esPrestamo
                                  ? 'Préstamo de ${p!.cliente}'
                                  : 'Devolución de Efectivo al Cliente',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.verde,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: Textos.cerrar,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: c.tinta2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_esPrestamo) ...[
                    Text(
                      'Debe ${p!.cantidad} ${_formato.etiqueta}'
                      '${p.devueltos > 0 ? ' (ya regresó ${p.devueltos})' : ''}. '
                      '¿Cuántos regresa?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.tinta,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SelectorEnvases(
                    formato: _formato,
                    cantidad: _cantidad,
                    formatoFijo: _esPrestamo,
                    maximo: p?.cantidad ?? 9999,
                    alCambiarFormato: (f) => setState(() => _formato = f),
                    alCambiarCantidad: (n) => setState(() => _cantidad = n),
                    etiquetaCantidad: _cantidad == 1 ? 'pieza' : 'piezas',
                  ),
                  const SizedBox(height: 20),

                  // Cliente (opcional) cuando no viene de un préstamo
                  if (!_esPrestamo) ...[
                    TextField(
                      controller: _clienteCtrl,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Nombre del Cliente (opcional)',
                        hintText: 'Ej. Juan Pérez',
                        filled: true,
                        fillColor: c.superficie2,
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: c.linea),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Indicador de reembolso: jerarquía alta en el centro
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: c.verdeSuave,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: c.verde.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Monto a reembolsar:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.verde,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dinero(reembolso),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: c.verde,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'Se registrará un retiro en efectivo de la caja',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.verde.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.verde,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(
                        _esPrestamo
                            ? Icons.download_rounded
                            : Icons.payments_rounded,
                        size: 22,
                      ),
                      label: Text(
                        _esPrestamo
                            ? 'Recibir $_cantidad'
                            : 'Confirmar y Entregar Efectivo (${dinero(reembolso)})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
