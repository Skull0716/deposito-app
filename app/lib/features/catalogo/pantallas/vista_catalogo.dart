import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/tarjeta_producto.dart';
import '../estado/productos.dart';
import 'detalle_producto.dart';

/// Búsqueda, filtros por categoría y cuadrícula de productos.
/// La usan el Catálogo de la caja y la pestaña Productos de la terminal.
class VistaCatalogo extends ConsumerStatefulWidget {
  const VistaCatalogo({
    super.key,
    this.acciones = const [],
    this.alTocarProducto,
    this.relleno = const EdgeInsets.fromLTRB(24, 20, 24, 0),
  });

  /// Botones a la derecha de la búsqueda (por ejemplo, "Nuevo producto").
  final List<Widget> acciones;

  /// Qué hacer al tocar un producto. Sin esto abre la ficha de solo lectura
  /// (la terminal la usa para agregar al pedido).
  final void Function(BuildContext context, Producto producto)? alTocarProducto;
  final EdgeInsets relleno;

  @override
  ConsumerState<VistaCatalogo> createState() => _VistaCatalogoState();
}

class _VistaCatalogoState extends ConsumerState<VistaCatalogo> {
  final _busqueda = TextEditingController();
  String? _categoria;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider);
    final c = context.colores;

    return Padding(
      padding: widget.relleno,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busqueda,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código',
                    prefixIcon: Icon(Icons.search_rounded, color: c.tinta2),
                    suffixIcon: _busqueda.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_busqueda.clear),
                          ),
                  ),
                ),
              ),
              for (final a in widget.acciones) ...[
                const SizedBox(width: 10),
                a,
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (productos.value case final lista? when lista.isNotEmpty)
            _Categorias(
              categorias: categoriasDe(lista),
              seleccion: _categoria,
              alElegir: (cat) => setState(() => _categoria = cat),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: switch (productos) {
              AsyncData(:final value) => _Cuadricula(
                productos: filtrarProductos(
                  value,
                  busqueda: _busqueda.text,
                  categoria: _categoria,
                ),
                hayCatalogo: value.isNotEmpty,
                alTocarProducto: widget.alTocarProducto,
              ),
              AsyncError(:final error) => EstadoError(
                error: error,
                alReintentar: () => ref.invalidate(productosProvider),
              ),
              _ => const Cargando(mensaje: 'Cargando catálogo'),
            },
          ),
        ],
      ),
    );
  }
}

class _Categorias extends StatelessWidget {
  const _Categorias({
    required this.categorias,
    required this.seleccion,
    required this.alElegir,
  });

  final List<String> categorias;
  final String? seleccion;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    Widget chip(String texto, String? valor) {
      final activo = seleccion == valor;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: activo,
          onSelected: (_) => alElegir(valor),
          labelStyle: TextStyle(
            fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
            color: activo ? c.seleccionTinta : c.tinta,
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Todos', null),
          for (final cat in categorias) chip(capitalizar(cat), cat),
        ],
      ),
    );
  }
}

class _Cuadricula extends ConsumerWidget {
  const _Cuadricula({
    required this.productos,
    required this.hayCatalogo,
    required this.alTocarProducto,
  });

  final List<Producto> productos;
  final bool hayCatalogo;
  final void Function(BuildContext context, Producto producto)? alTocarProducto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productos.isEmpty) {
      return hayCatalogo
          ? const EstadoVacio(
              icono: Icons.search_off_rounded,
              titulo: 'Sin resultados',
              mensaje: 'Ningún producto coincide con la búsqueda.',
            )
          : const EstadoVacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'El catálogo está vacío',
              mensaje: 'Agrega el primer producto desde la caja.',
            );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(productosProvider.notifier).refrescar(),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 250,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: productos.length,
        itemBuilder: (context, i) => TarjetaProducto(
          key: ValueKey(productos[i].id),
          producto: productos[i],
          alTocar: () => alTocarProducto == null
              ? mostrarDetalleProducto(context, productos[i])
              : alTocarProducto!(context, productos[i]),
        ),
      ),
    );
  }
}
