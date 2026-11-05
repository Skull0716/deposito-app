import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';
import '../../catalogo/estado/productos.dart';
import '../estado/pedido_borrador.dart';
import 'escaner.dart';

/// Escanear un producto para ver precio y existencia al momento.
///
/// Busca en el catálogo que ya está en memoria (se mantiene al día por
/// WebSocket). `GET /productos/codigo/{codigo}` llega en el Sprint 2.
class PantallaEscanear extends ConsumerStatefulWidget {
  const PantallaEscanear({super.key});

  @override
  ConsumerState<PantallaEscanear> createState() => _PantallaEscanearState();
}

class _PantallaEscanearState extends ConsumerState<PantallaEscanear> {
  final _codigo = TextEditingController();
  String? _buscado;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _abrirCamara() async {
    final codigo = await escanearCodigo(context, titulo: 'Escanear producto');
    if (codigo != null) _buscar(codigo);
  }

  void _buscar(String codigo) {
    _codigo.text = codigo.trim();
    setState(() => _buscado = codigo.trim());
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final productos = ref.watch(productosProvider);
    final buscado = _buscado;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Material(
          color: c.superficie,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _abrirCamara,
            child: CustomPaint(
              painter: _BordePunteado(c.lager),
              child: SizedBox(
                height: 140,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: c.tinta,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Abrir cámara',
                      style: textos.titleMedium?.copyWith(fontSize: 19),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codigo,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: _buscar,
                decoration: const InputDecoration(
                  hintText: 'O escribe el código',
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => _buscar(_codigo.text),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: const Text(Textos.buscar),
            ),
          ],
        ),
        const SizedBox(height: 18),
        switch ((productos, buscado)) {
          (AsyncError(:final error), _) => EstadoError(
            error: error,
            alReintentar: () => ref.invalidate(productosProvider),
          ),
          (_, null) => const EstadoVacio(
            icono: Icons.inventory_2_outlined,
            titulo: 'Listo para escanear',
            mensaje: 'Escanea un producto para ver su precio y existencia en tiempo real.',
          ),
          (AsyncData(:final value), final String codigo) => switch (porCodigo(
            value,
            codigo,
          )) {
            final Producto p => _Resultado(producto: p),
            null => EstadoVacio(
              icono: Icons.search_off_rounded,
              titulo: 'Código no registrado',
              mensaje:
                  'El código $codigo no está en el catálogo. Pide en la caja que lo den de alta.',
            ),
          },
          _ => const Padding(padding: EdgeInsets.all(32), child: Cargando()),
        },
      ],
    );
  }
}

class _Resultado extends ConsumerWidget {
  const _Resultado({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final p = producto;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 104,
                child: IlustracionProducto(producto: p),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: textos.headlineSmall),
                    if (p.presentacion != null)
                      Text(p.presentacion!, style: textos.bodySmall),
                    const SizedBox(height: 6),
                    Text(dinero(p.precio), style: textos.displaySmall),
                    if (p.precioCaja != null)
                      Text(
                        'Caja de ${p.piezasPorCaja}: ${dinero(p.precioCaja!)}',
                        style: textos.bodyMedium?.copyWith(color: c.tinta2),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.bajoMinimo ? c.alertaSuave : c.verdeSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  p.bajoMinimo
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_rounded,
                  color: p.bajoMinimo ? c.alerta : c.verde,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hay ${existenciaLegible(p)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p.bajoMinimo ? c.alerta : c.verde,
                    ),
                  ),
                ),
                Text(
                  '${p.existenciaPiezas} pz',
                  style: textos.titleLarge?.copyWith(
                    color: p.bajoMinimo ? c.alerta : c.verde,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _agregar(context, ref, porCaja: false),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar 1 pieza'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          if (p.piezasPorCaja != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _agregar(context, ref, porCaja: true),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text('Agregar 1 caja de ${p.piezasPorCaja}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _agregar(BuildContext context, WidgetRef ref, {required bool porCaja}) {
    ref
        .read(pedidoBorradorProvider.notifier)
        .agregar(producto, porCaja: porCaja);
    avisar(
      context,
      '${producto.nombre} se agregó al pedido. '
      'Revisa la pestaña Pedido.',
    );
  }
}

class _BordePunteado extends CustomPainter {
  _BordePunteado(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final ruta = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(18)),
      );
    for (final m in ruta.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d, d + 8), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_BordePunteado old) => old.color != color;
}
