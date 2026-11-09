import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../estado/carrito.dart';
import 'comun.dart';

/// Edición de un renglón (diseño de Pablo): cantidad, descuento y quitar.
class EdicionRenglon extends ConsumerStatefulWidget {
  const EdicionRenglon({
    super.key,
    required this.clave,
    required this.alAvisar,
  });

  final String clave;
  final ValueChanged<String> alAvisar;

  @override
  ConsumerState<EdicionRenglon> createState() => _EdicionRenglonState();
}

class _EdicionRenglonState extends ConsumerState<EdicionRenglon> {
  late final _descuento = TextEditingController(
    text: () {
      final d = _actual?.descuento ?? 0;
      return d == 0 ? '' : '$d';
    }(),
  );

  ItemCarrito? get _actual => ref
      .read(carritoProvider)
      .items
      .where((i) => i.clave == widget.clave)
      .firstOrNull;

  @override
  void dispose() {
    _descuento.dispose();
    super.dispose();
  }

  void _cambiar(ItemCarrito actual, int n) {
    final motivo = ref
        .read(carritoProvider.notifier)
        .cambiarCantidad(actual, n);
    if (motivo != null) {
      widget.alAvisar(motivo);
    } else if (n == 0) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final actual = ref
        .watch(carritoProvider)
        .items
        .where((i) => i.clave == widget.clave)
        .firstOrNull;
    if (actual == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.linea,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              nombreItem(actual),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: c.tinta,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Quitar uno',
                  onPressed: () => _cambiar(actual, actual.cantidad - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 48,
                  color: c.tinta2,
                ),
                const SizedBox(width: 24),
                Text(
                  '${actual.cantidad}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: c.tinta,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  tooltip: 'Agregar uno',
                  onPressed: () => _cambiar(actual, actual.cantidad + 1),
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 48,
                  color: c.azul,
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _descuento,
              keyboardType: TextInputType.number,
              maxLength: 2,
              onChanged: (t) => ref
                  .read(carritoProvider.notifier)
                  .ponerDescuento(actual, int.tryParse(t) ?? 0),
              decoration: InputDecoration(
                labelText: 'Aplicar descuento (%)',
                counterText: '',
                helperText: actual.descuento > 0
                    ? '${dinero(actual.precioLista)} a '
                          '${dinero(actual.precioUnitario)} c/u'
                    : 'De 0 a 99 %',
                filled: true,
                fillColor: c.fondo,
                prefixIcon: const Icon(Icons.discount_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _cambiar(actual, 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.alerta.withValues(alpha: 0.1),
                  foregroundColor: c.alerta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Eliminar producto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
