import 'package:flutter/material.dart';

import '../../../app/tema/colores.dart';
import '../../../core/textos.dart';
import '../datos/modelos_envases.dart';
import 'selector_envases.dart';

/// Lo que se capturó para el préstamo.
typedef NuevoPrestamo = ({
  String cliente,
  String? telefono,
  FormatoEnvase formato,
  int cantidad,
});

/// 5.4 Registro de préstamo (fiado), diseño de Pablo.
///
/// Con [cantidadEnvases] y [formato] el préstamo viene de una venta y ya
/// tiene cantidad; sin ellos se eligen aquí (vacíos de bodega).
class ModalRegistroPrestamo extends StatefulWidget {
  const ModalRegistroPrestamo({super.key, this.cantidadEnvases, this.formato});

  final int? cantidadEnvases;
  final FormatoEnvase? formato;

  static Future<NuevoPrestamo?> mostrar(
    BuildContext context, {
    int? cantidadEnvases,
    FormatoEnvase? formato,
  }) => showDialog<NuevoPrestamo>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ModalRegistroPrestamo(
      cantidadEnvases: cantidadEnvases,
      formato: formato,
    ),
  );

  @override
  State<ModalRegistroPrestamo> createState() => _ModalRegistroPrestamoState();
}

class _ModalRegistroPrestamoState extends State<ModalRegistroPrestamo> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _nombreValido = false;
  bool _intentoGuardar = false;
  late FormatoEnvase _formato = widget.formato ?? FormatoEnvase.media;
  late int _cantidad = widget.cantidadEnvases ?? 1;

  bool get _deVenta => widget.cantidadEnvases != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(() {
      final valido = _nombreCtrl.text.trim().isNotEmpty;
      if (valido != _nombreValido) {
        setState(() => _nombreValido = valido);
      }
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    setState(() => _intentoGuardar = true);
    if (!_nombreValido) return;
    final telefono = _telefonoCtrl.text.trim();
    Navigator.pop(context, (
      cliente: _nombreCtrl.text.trim(),
      telefono: telefono.isEmpty ? null : telefono,
      formato: _formato,
      cantidad: _cantidad,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final mostrarError = _intentoGuardar && !_nombreValido;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: c.superficie,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
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
                  // Cabecera con icono
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          color: Color(0xFFD97706),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registro de Préstamo',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.tinta,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Fiado / Envases pendientes de devolver',
                              style: TextStyle(fontSize: 13, color: c.tinta2),
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

                  // Resumen del préstamo (de una venta) o qué se presta
                  if (_deVenta)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.superficie2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.linea),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: c.azul,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Préstamo de $_cantidad envases '
                              '(${_formato.etiqueta}) asociado a esta compra.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.tinta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SelectorEnvases(
                      formato: _formato,
                      cantidad: _cantidad,
                      alCambiarFormato: (f) => setState(() => _formato = f),
                      alCambiarCantidad: (n) => setState(() => _cantidad = n),
                      etiquetaCantidad: 'vacíos de bodega',
                    ),
                  const SizedBox(height: 20),

                  // Input Nombre o Apodo
                  Text(
                    'Nombre o Apodo del Cliente *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: mostrarError ? c.alerta : c.tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nombreCtrl,
                    autofocus: _deVenta,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Ej. Don Pedro, Compadre Juan, Taquería...',
                      filled: true,
                      fillColor: mostrarError ? c.alertaSuave : c.superficie2,
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: mostrarError ? c.alerta : c.tinta2,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: mostrarError ? c.alerta : c.linea,
                          width: mostrarError ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: mostrarError ? c.alerta : c.azul,
                          width: 2.0,
                        ),
                      ),
                      errorText: mostrarError
                          ? 'Ingresa el nombre para guardar el préstamo'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input Teléfono (opcional)
                  Text(
                    'Teléfono o WhatsApp (opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 20,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Ej. 55 1234 5678',
                      filled: true,
                      fillColor: c.superficie2,
                      prefixIcon: Icon(Icons.phone_outlined, color: c.tinta2),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.linea),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.azul, width: 2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Botón Acción: "Guardar Préstamo"
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _nombreValido ? _guardar : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.azul,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: c.linea,
                        disabledForegroundColor: c.tinta2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 22),
                      label: const Text(
                        'Guardar Préstamo',
                        style: TextStyle(
                          fontSize: 17,
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
