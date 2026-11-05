import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../datos/modelos_envases.dart';
import '../estado/envases_provider.dart';
import 'selector_envases.dart';

/// Para qué se abre el panel de vacíos.
enum ModoVacios {
  /// Entran a bodega sin venta (los deja el proveedor).
  entrada,

  /// Salen de bodega sin cobro: pide el motivo.
  salida,

  /// El cliente los entrega en la venta y se descuenta su depósito.
  credito,
}

/// Lo que se capturó en el panel.
typedef VaciosCapturados = ({
  FormatoEnvase formato,
  int cantidad,
  String? motivo,
});

/// 5.2 Recepción de envases vacíos (diseño de Pablo): panel inferior con
/// formato, cantidad y, en una venta, el crédito que se descuenta del ticket.
class ModalRecepcionEnvases extends ConsumerStatefulWidget {
  const ModalRecepcionEnvases({
    super.key,
    this.modo = ModoVacios.entrada,
    this.cantidadInicial = 1,
    this.formatoInicial = FormatoEnvase.media,
  });

  final ModoVacios modo;
  final int cantidadInicial;
  final FormatoEnvase formatoInicial;

  static Future<VaciosCapturados?> mostrar(
    BuildContext context, {
    ModoVacios modo = ModoVacios.entrada,
    int cantidadInicial = 1,
    FormatoEnvase formatoInicial = FormatoEnvase.media,
  }) => showModalBottomSheet<VaciosCapturados>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ModalRecepcionEnvases(
      modo: modo,
      cantidadInicial: cantidadInicial,
      formatoInicial: formatoInicial,
    ),
  );

  @override
  ConsumerState<ModalRecepcionEnvases> createState() =>
      _ModalRecepcionEnvasesState();
}

class _ModalRecepcionEnvasesState extends ConsumerState<ModalRecepcionEnvases> {
  late int _cantidad = widget.cantidadInicial.clamp(1, 9999);
  late FormatoEnvase _formato = widget.formatoInicial;
  final _motivo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _motivo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _listo =>
      widget.modo != ModoVacios.salida || _motivo.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estado = ref.watch(envasesProvider).value;
    final credito = _cantidad * (estado?.precio(_formato) ?? 0);
    final enBodega = estado?.de(_formato).bodega;

    final (titulo, subtitulo, icono, color) = switch (widget.modo) {
      ModoVacios.entrada => (
        'Recepción de Envases Vacíos',
        'Entran a bodega sin venta, por ejemplo los que deja el proveedor',
        Icons.recycling_rounded,
        c.verde,
      ),
      ModoVacios.salida => (
        'Salida de Envases Vacíos',
        'Salen de bodega sin cobro: al proveedor, rotos o extraviados',
        Icons.outbox_rounded,
        const Color(0xFFD97706),
      ),
      ModoVacios.credito => (
        'Recepción de Envases Vacíos',
        'Descuenta del ticket el valor de los vacíos que entrega el cliente',
        Icons.recycling_rounded,
        c.verde,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Asa de arrastre
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.linea,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cabecera
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
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
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: c.tinta,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          subtitulo,
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

              SelectorEnvases(
                formato: _formato,
                cantidad: _cantidad,
                alCambiarFormato: (f) => setState(() => _formato = f),
                alCambiarCantidad: (n) => setState(() => _cantidad = n),
                etiquetaCantidad: widget.modo == ModoVacios.salida
                    ? 'salen'
                    : 'vacíos',
              ),
              if (widget.modo == ModoVacios.salida) ...[
                if (enBodega != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'En bodega: $enBodega ${_formato.etiqueta}',
                    style: TextStyle(fontSize: 13, color: c.tinta2),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _motivo,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Motivo *',
                    hintText: 'Ej. Cambio con el proveedor, botellas rotas',
                    filled: true,
                    fillColor: c.superficie2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.linea),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Indicador de crédito verde destacado (solo en una venta)
              if (widget.modo == ModoVacios.credito) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: c.verdeSuave,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.verde.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: c.verde,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Crédito a descontar:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.verde,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '-${dinero(credito)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.verde,
                          letterSpacing: -0.5,
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
                  onPressed: _listo
                      ? () => Navigator.pop(context, (
                          formato: _formato,
                          cantidad: _cantidad,
                          motivo: widget.modo == ModoVacios.salida
                              ? _motivo.text.trim()
                              : null,
                        ))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: c.linea,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    widget.modo == ModoVacios.salida
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 22,
                  ),
                  label: Text(switch (widget.modo) {
                    ModoVacios.entrada => 'Recibir $_cantidad vacíos',
                    ModoVacios.salida => 'Sacar $_cantidad vacíos',
                    ModoVacios.credito =>
                      'Aplicar Crédito al Ticket (-${dinero(credito)})',
                  }, style: const TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
