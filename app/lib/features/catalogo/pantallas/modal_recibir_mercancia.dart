import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';

/// Pide cajas y piezas para registrar una entrada de mercancía.
/// Regresa `true` si el servidor aceptó la entrada.
Future<bool> mostrarRecibirMercancia(
  BuildContext context,
  Producto producto,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => RecibirMercancia(producto: producto),
    ) ??
    false;

class RecibirMercancia extends ConsumerStatefulWidget {
  const RecibirMercancia({super.key, required this.producto});

  final Producto producto;

  @override
  ConsumerState<RecibirMercancia> createState() => _RecibirMercanciaState();
}

class _RecibirMercanciaState extends ConsumerState<RecibirMercancia> {
  final _cajas = TextEditingController();
  final _piezas = TextEditingController();
  final _nota = TextEditingController();
  DateTime? _caducidad;
  String? _error;
  var _guardando = false;

  @override
  void dispose() {
    for (final c in [_cajas, _piezas, _nota]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final cajas = int.tryParse(_cajas.text.trim()) ?? 0;
    final piezas = int.tryParse(_piezas.text.trim()) ?? 0;
    if (cajas == 0 && piezas == 0) {
      setState(() => _error = 'Escribe al menos una caja o una pieza.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final api = await ref.read(apiProvider.future);
      await api.registrarEntrada(
        widget.producto.id,
        cajas: cajas,
        piezas: piezas,
        caducidad: _iso(_caducidad),
        nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  static String? _iso(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}'
            '-${fecha.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = widget.producto;
    final porCaja = p.piezasPorCaja;

    return AlertDialog(
      title: const Text('Recibir mercancía'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${existenciaLegible(p)} · mínimo ${p.minimo} pz',
                style: TextStyle(color: c.tinta2),
              ),
              const SizedBox(height: 18),
              if (porCaja != null) ...[
                TextField(
                  controller: _cajas,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Cajas',
                    helperText: '$porCaja piezas por caja',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _piezas,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Piezas sueltas'),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _guardando
                    ? null
                    : () async {
                        final hoy = DateTime.now();
                        final f = await showDatePicker(
                          context: context,
                          firstDate: hoy,
                          lastDate: DateTime(hoy.year + 5),
                          initialDate:
                              _caducidad ?? hoy.add(const Duration(days: 90)),
                        );
                        if (f != null) setState(() => _caducidad = f);
                      },
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  _caducidad == null
                      ? 'Agregar caducidad (opcional)'
                      : 'Caduca el ${fechaCorta(_iso(_caducidad)!)} '
                            '${_caducidad!.year}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nota,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(error, style: TextStyle(color: c.alerta)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text(Textos.cancelar),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Recibir mercancía'),
        ),
      ],
    );
  }
}
