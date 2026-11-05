import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';

enum _Modo { conteo, merma }

/// Ajusta la existencia: fija lo que se contó físicamente o saca piezas
/// rotas, caducadas o regaladas. Regresa `true` si el servidor lo aceptó.
Future<bool> mostrarAjusteExistencia(
  BuildContext context,
  Producto producto,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AjusteExistencia(producto: producto),
    ) ??
    false;

class AjusteExistencia extends ConsumerStatefulWidget {
  const AjusteExistencia({super.key, required this.producto});

  final Producto producto;

  @override
  ConsumerState<AjusteExistencia> createState() => _AjusteExistenciaState();
}

class _AjusteExistenciaState extends ConsumerState<AjusteExistencia> {
  final _cantidad = TextEditingController();
  final _nota = TextEditingController();
  var _modo = _Modo.conteo;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cantidad.text = widget.producto.existenciaPiezas.toString();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final p = widget.producto;
    final cantidad = int.tryParse(_cantidad.text.trim());
    if (cantidad == null || cantidad < 0) {
      setState(
        () => _error = _modo == _Modo.conteo
            ? 'Escribe cuántas piezas contaste'
            : 'Escribe cuántas piezas sacar',
      );
      return;
    }
    if (_modo == _Modo.merma && cantidad == 0) {
      setState(() => _error = 'Escribe cuántas piezas sacar');
      return;
    }
    if (_modo == _Modo.merma && cantidad > p.existenciaPiezas) {
      setState(
        () => _error = 'Solo hay ${p.existenciaPiezas} piezas de ${p.nombre}',
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final api = await ref.read(apiProvider.future);
      final nota = _nota.text.trim();
      if (_modo == _Modo.conteo) {
        await api.registrarConteo(
          p.id,
          existenciaPiezas: cantidad,
          nota: nota.isEmpty ? null : nota,
        );
      } else {
        await api.registrarMerma(
          p.id,
          piezas: cantidad,
          nota: nota.isEmpty ? null : nota,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = widget.producto;
    final conteo = _modo == _Modo.conteo;

    return AlertDialog(
      title: const Text('Ajustar existencia'),
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
                'Hay ${existenciaLegible(p)} · mínimo ${p.minimo} pz',
                style: TextStyle(color: c.tinta2),
              ),
              const SizedBox(height: 18),
              SegmentedButton<_Modo>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Modo.conteo,
                    icon: Icon(Icons.fact_check_outlined),
                    label: Text('Conteo'),
                  ),
                  ButtonSegment(
                    value: _Modo.merma,
                    icon: Icon(Icons.delete_outline_rounded),
                    label: Text('Merma'),
                  ),
                ],
                selected: {_modo},
                onSelectionChanged: _guardando
                    ? null
                    : (s) => setState(() {
                        _modo = s.first;
                        _error = null;
                        _cantidad.text = s.first == _Modo.conteo
                            ? p.existenciaPiezas.toString()
                            : '';
                      }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cantidad,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: conteo ? 'Piezas contadas' : 'Piezas a sacar',
                  helperText: conteo
                      ? 'La existencia quedará en este número'
                      : 'Rotas, caducadas o regaladas',
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
              : const Text('Guardar ajuste'),
        ),
      ],
    );
  }
}
