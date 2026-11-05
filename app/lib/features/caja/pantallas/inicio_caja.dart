import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/servidor/servidor_embebido.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';
import '../../catalogo/estado/productos.dart';
import '../../catalogo/pantallas/detalle_producto.dart';
import '../../pedidos/pantallas/pedidos_pendientes.dart';
import '../estado/terminales.dart';
import 'conectar_terminal.dart';

/// Tablero de la caja. Las cifras de ventas llegan en el Sprint 4; por ahora
/// muestra catálogo, alertas, pedidos de terminal y terminales conectadas.
class InicioCaja extends ConsumerWidget {
  const InicioCaja({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(productosProvider);
    return switch (productos) {
      AsyncData(:final value) => _Tablero(productos: value),
      AsyncError(:final error) => EstadoError(
        error: error,
        alReintentar: () => ref.invalidate(productosProvider),
      ),
      _ => const Cargando(),
    };
  }
}

class _Tablero extends ConsumerWidget {
  const _Tablero({required this.productos});

  final List<Producto> productos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final ahora = DateTime.now();
    final terminales =
        ref.watch(terminalesProvider).value ?? const <Terminal>[];
    final ip = ref.watch(direccionLocalProvider).value;

    final bajoMinimo = productos.where((p) => p.bajoMinimo).toList()
      ..sort(
        (a, b) => (a.existenciaPiezas / (a.minimo == 0 ? 1 : a.minimo))
            .compareTo(b.existenciaPiezas / (b.minimo == 0 ? 1 : b.minimo)),
      );
    final porCaducar =
        productos
            .where(
              (p) =>
                  p.caducidad != null && diasHasta(p.caducidad!, ahora) <= 15,
            )
            .toList()
          ..sort((a, b) => a.caducidad!.compareTo(b.caducidad!));
    final atencion = {...bajoMinimo, ...porCaducar}.toList();
    final conectadas = terminales.where((t) => t.conectada).length;
    final piezas = productos.fold<int>(0, (s, p) => s + p.existenciaPiezas);

    final saludo = switch (ahora.hour) {
      < 12 => 'Buenos días',
      < 19 => 'Buenas tardes',
      _ => 'Buenas noches',
    };

    return LayoutBuilder(
      builder: (context, medidas) {
        final ancho = medidas.maxWidth;
        final columnasKpi = ancho > 1000 ? 4 : 2;
        final dosColumnas = ancho > 900;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saludo, style: textos.displaySmall),
                    const SizedBox(height: 4),
                    Text(
                      ip == null
                          ? 'La caja está lista. Conéctala a la Wi-Fi para recibir terminales.'
                          : 'La caja está lista en $ip. ${_textoTerminales(conectadas)}',
                      style: textos.bodyLarge?.copyWith(color: c.tinta2),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/caja/vender'),
                  icon: const Icon(Icons.shopping_cart_rounded),
                  label: const Text('Nueva venta'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 60),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    textStyle: textos.titleMedium?.copyWith(fontSize: 19),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PanelMetricas(
              productos: productos.length,
              piezas: piezas,
              bajoMinimo: bajoMinimo.length,
              porCaducar: porCaducar.length,
              terminales: terminales.length,
              conectadas: conectadas,
              columnas: columnasKpi,
            ),
            const SizedBox(height: 20),
            PedidosPendientes(productos: productos),
            Flex(
              direction: dosColumnas ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 18,
              children: [
                _envolver(
                  dosColumnas,
                  3,
                  _Tarjeta(
                    titulo: 'Necesita atención',
                    accion: TextButton(
                      onPressed: () => context.go('/caja/catalogo'),
                      child: const Text('Ver catálogo'),
                    ),
                    child: atencion.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: EstadoVacio(
                              icono: Icons.check_circle_outline_rounded,
                              titulo: 'Todo en orden',
                              mensaje: 'Ningún producto está bajo su mínimo ni por caducar.',
                            ),
                          )
                        : Column(
                            children: [
                              for (final p in atencion.take(6))
                                _FilaAtencion(producto: p, hoy: ahora),
                            ],
                          ),
                  ),
                ),
                _envolver(
                  dosColumnas,
                  2,
                  _Tarjeta(
                    titulo: 'Terminales',
                    accion: TextButton.icon(
                      onPressed: () => mostrarConectarTerminal(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Vincular'),
                    ),
                    child: terminales.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'Conecta el S24 o el iPhone para escanear productos en los pasillos.',
                              style: TextStyle(color: c.tinta2),
                            ),
                          )
                        : Column(
                            children: [
                              for (final t in terminales)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.smartphone_rounded,
                                    color: c.tinta2,
                                  ),
                                  title: Text(
                                    t.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: t.conectada
                                              ? const Color(0xFF46C281)
                                              : c.linea,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        t.conectada
                                            ? 'En línea'
                                            : 'Fuera de línea',
                                        style: TextStyle(color: c.tinta2),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static Widget _envolver(bool fila, int flex, Widget hijo) =>
      fila ? Expanded(flex: flex, child: hijo) : hijo;

  static String _textoTerminales(int n) => switch (n) {
    0 => 'Ninguna terminal conectada.',
    1 => 'Una terminal conectada.',
    _ => '$n terminales conectadas.',
  };
}

class _PanelMetricas extends StatelessWidget {
  const _PanelMetricas({
    required this.productos,
    required this.piezas,
    required this.bajoMinimo,
    required this.porCaducar,
    required this.terminales,
    required this.conectadas,
    required this.columnas,
  });

  final int productos;
  final int piezas;
  final int bajoMinimo;
  final int porCaducar;
  final int terminales;
  final int conectadas;
  final int columnas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final esCuatroColumnas = columnas >= 4;

    final item1 = _ElementoMetrica(
      icono: Icons.inventory_2_outlined,
      etiqueta: 'Catálogo',
      valor: '$productos',
      unidad: productos == 1 ? 'producto' : 'productos',
      detalle: '$piezas piezas en almacén',
      alTocar: () => context.go('/caja/catalogo'),
    );

    final item2 = _ElementoMetrica(
      icono: Icons.trending_down_rounded,
      etiqueta: 'Bajo mínimo',
      valor: '$bajoMinimo',
      unidad: bajoMinimo == 1 ? 'producto' : 'productos',
      detalle: bajoMinimo == 0 ? 'Inventario en orden' : 'Requiere resurtido',
      alerta: bajoMinimo > 0,
      colorAlerta: c.alerta,
      alTocar: () => context.go('/caja/catalogo'),
    );

    final item3 = _ElementoMetrica(
      icono: Icons.event_outlined,
      etiqueta: 'Por caducar',
      valor: '$porCaducar',
      unidad: porCaducar == 1 ? 'producto' : 'productos',
      detalle: porCaducar == 0 ? 'Sin fechas críticas' : 'Próximos 15 días',
      alerta: porCaducar > 0,
      colorAlerta: const Color(0xFFD97706),
      alTocar: () => context.go('/caja/catalogo'),
    );

    final item4 = _ElementoMetrica(
      icono: Icons.smartphone_rounded,
      etiqueta: 'Terminales',
      valor: '$conectadas',
      unidad: conectadas == 1 ? 'activa' : 'activas',
      detalle: terminales == 0 ? 'Ninguna vinculada' : '$terminales vinculadas',
      alerta: conectadas > 0,
      colorAlerta: c.verde,
      alTocar: () => mostrarConectarTerminal(context),
    );

    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      clipBehavior: Clip.antiAlias,
      child: esCuatroColumnas
          ? IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: item1),
                  VerticalDivider(width: 1, thickness: 1, color: c.linea),
                  Expanded(child: item2),
                  VerticalDivider(width: 1, thickness: 1, color: c.linea),
                  Expanded(child: item3),
                  VerticalDivider(width: 1, thickness: 1, color: c.linea),
                  Expanded(child: item4),
                ],
              ),
            )
          : Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: item1),
                      VerticalDivider(width: 1, thickness: 1, color: c.linea),
                      Expanded(child: item2),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: c.linea),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: item3),
                      VerticalDivider(width: 1, thickness: 1, color: c.linea),
                      Expanded(child: item4),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ElementoMetrica extends StatelessWidget {
  const _ElementoMetrica({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    required this.detalle,
    required this.alTocar,
    this.alerta = false,
    this.colorAlerta,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final String unidad;
  final String detalle;
  final VoidCallback alTocar;
  final bool alerta;
  final Color? colorAlerta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: alTocar,
        hoverColor: c.superficie2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icono, size: 15, color: c.tinta2.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      etiqueta,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.tinta2.withValues(alpha: 0.8),
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (alerta && colorAlerta != null)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colorAlerta,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: c.tinta,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      unidad,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: c.tinta2.withValues(alpha: 0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                detalle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: alerta ? FontWeight.w600 : FontWeight.w400,
                  color: alerta && colorAlerta != null
                      ? colorAlerta
                      : c.tinta2.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child, this.accion});

  final String titulo;
  final Widget child;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _FilaAtencion extends StatelessWidget {
  const _FilaAtencion({required this.producto, required this.hoy});

  final Producto producto;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = producto;
    final dias = p.caducidad == null ? null : diasHasta(p.caducidad!, hoy);
    final (motivo, color, fondo) = p.bajoMinimo
        ? ('Bajo el mínimo', c.alerta, c.alertaSuave)
        : switch (dias!) {
            < 0 => ('Vencido', c.alerta, c.alertaSuave),
            0 => ('Caduca hoy', c.alerta, c.alertaSuave),
            1 => ('Caduca mañana', c.azul, c.superficie3),
            _ => ('Caduca en $dias días', c.azul, c.superficie3),
          };
    return InkWell(
      onTap: () => mostrarDetalleProducto(context, p),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.linea)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: IlustracionProducto(producto: p, radio: 10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${existenciaLegible(p)} · mínimo ${p.minimo} pz',
                    style: TextStyle(color: c.tinta2, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                motivo,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
