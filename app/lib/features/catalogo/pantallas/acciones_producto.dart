import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../estado/productos.dart';
import 'formulario_producto.dart';
import 'modal_ajuste_existencia.dart';
import 'modal_movimientos.dart';
import 'modal_recibir_mercancia.dart';

/// Lo que la caja puede hacer con un producto desde su ficha: recibir
/// mercancía, editarlo, ajustar la existencia, ver movimientos o eliminarlo.
/// La terminal no muestra estos botones.
class AccionesProductoCaja extends ConsumerWidget {
  const AccionesProductoCaja({super.key, required this.producto});

  /// El producto con el que se abrió la ficha; si el catálogo ya tiene una
  /// versión más nueva, se usa esa.
  final Producto producto;

  Producto _actual(WidgetRef ref) =>
      ref
          .watch(productosProvider)
          .value
          ?.firstWhere((p) => p.id == producto.id, orElse: () => producto) ??
      producto;

  Future<void> _refrescar(WidgetRef ref) =>
      ref.read(productosProvider.notifier).refrescar();

  Future<void> _recibir(
    BuildContext context,
    WidgetRef ref,
    Producto actual,
  ) async {
    final listo = await mostrarRecibirMercancia(context, actual);
    if (!listo) return;
    await _refrescar(ref);
    if (context.mounted) avisar(context, 'Entrada registrada');
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Producto actual,
  ) async {
    final guardado = await abrirFormularioProducto(context, producto: actual);
    if (guardado != null) await _refrescar(ref);
  }

  Future<void> _ajustar(
    BuildContext context,
    WidgetRef ref,
    Producto actual,
  ) async {
    final listo = await mostrarAjusteExistencia(context, actual);
    if (!listo) return;
    await _refrescar(ref);
    if (context.mounted) avisar(context, 'Existencia ajustada');
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Producto actual,
  ) async {
    final confirmado = await confirmar(
      context,
      titulo: '¿Eliminar ${actual.nombre}?',
      mensaje:
          'Se quita del catálogo. Las ventas y los movimientos anteriores '
          'se conservan.',
      accion: 'Eliminar',
      peligrosa: true,
    );
    if (!confirmado || !context.mounted) return;

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final api = await ref.read(apiProvider.future);
      await api.eliminarProducto(actual.id);
      await _refrescar(ref);
      navegador.pop();
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${actual.nombre} se eliminó')));
    } on Object catch (e) {
      if (!context.mounted) return;
      avisar(context, 'No se pudo eliminar: ${mensajeDeError(e)}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final actual = _actual(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _recibir(context, ref, actual),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Recibir mercancía'),
            ),
            OutlinedButton.icon(
              onPressed: () => _editar(context, ref, actual),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar producto'),
            ),
            OutlinedButton.icon(
              onPressed: () => _ajustar(context, ref, actual),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ajustar existencia'),
            ),
            OutlinedButton.icon(
              onPressed: () => mostrarMovimientos(context, actual),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Movimientos'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _eliminar(context, ref, actual),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text(Textos.eliminar),
            style: TextButton.styleFrom(foregroundColor: c.alerta),
          ),
        ),
      ],
    );
  }
}
