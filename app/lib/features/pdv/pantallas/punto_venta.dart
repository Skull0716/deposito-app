import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/widgets/estados.dart';
import '../../catalogo/estado/productos.dart';
import '../../envases/datos/modelos_envases.dart';
import '../../envases/pantallas/modal_recepcion_envases.dart';
import '../../envases/pantallas/modal_registro_prestamo.dart';
import '../../envases/pantallas/modal_salida_envases.dart';
import '../estado/carrito.dart';
import 'escaner_continuo.dart';
import 'flujo_cobro.dart';
import 'venta/edicion_renglon.dart';
import 'venta/filtro_categorias.dart';
import 'venta/panel_venta.dart';
import 'venta/tarjeta_producto.dart';

/// Sección "Vender" de la caja: catálogo real a la izquierda y la venta en
/// curso a la derecha (en pantallas angostas, en un botón flotante).
class PuntoVenta extends ConsumerStatefulWidget {
  const PuntoVenta({super.key});

  @override
  ConsumerState<PuntoVenta> createState() => _PuntoVentaState();
}

class _PuntoVentaState extends ConsumerState<PuntoVenta>
    with SingleTickerProviderStateMixin {
  final _busqueda = TextEditingController();
  String? _categoria;
  String? _itemRecienteClave;

  late final AnimationController _rebote = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void dispose() {
    _rebote.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  void _mostrarAlertaInventario(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.amber[800],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _agregarAlCarrito(Producto prod, {bool porCaja = false}) {
    final motivo = _agregarSinAviso(prod, porCaja: porCaja);
    if (motivo != null) _mostrarAlertaInventario(motivo);
  }

  /// Agrega y resalta el renglón. Regresa el motivo si no alcanza.
  String? _agregarSinAviso(Producto prod, {bool porCaja = false}) {
    final motivo = ref
        .read(carritoProvider.notifier)
        .agregar(prod, porCaja: porCaja);
    if (motivo != null) return motivo;
    final clave = '${prod.id}_${porCaja ? 'caja' : 'pieza'}';
    setState(() => _itemRecienteClave = clave);
    _rebote.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _itemRecienteClave == clave) {
        setState(() => _itemRecienteClave = null);
      }
    });
    return null;
  }

  void _alTocarProducto(Producto prod) {
    if (prod.precioCaja != null && prod.piezasPorCaja != null) {
      _mostrarModalVariante(prod);
    } else {
      _agregarAlCarrito(prod);
    }
  }

  /// Un código exacto (lector de código de barras o Enter) va directo al
  /// carrito; si no, el texto queda como búsqueda.
  void _alEnviarBusqueda(List<Producto> productos, String texto) {
    final p = porCodigo(productos, texto);
    if (p == null) return;
    _agregarAlCarrito(p);
    _busqueda.clear();
    setState(() {});
  }

  /// Escáner continuo: cada código leído entra a la venta sin cerrar la
  /// cámara.
  void _abrirEscaner(List<Producto> productos) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EscanerContinuo(
          alEscanear: (codigo) {
            final p = porCodigo(productos, codigo);
            if (p == null) {
              return (
                agregado: false,
                mensaje: 'El código $codigo no está en el catálogo',
              );
            }
            final motivo = _agregarSinAviso(p);
            return motivo == null
                ? (agregado: true, mensaje: 'Agregado: ${p.nombre}')
                : (agregado: false, mensaje: motivo);
          },
        ),
      ),
    );
  }

  void _mostrarModalVariante(Producto prod) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (contextoHoja) {
        final c = context.colores;
        return Container(
          decoration: BoxDecoration(
            color: c.superficie,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
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
                  prod.nombre,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.tinta,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: BotonVariante(
                        icono: Icons.sports_bar_outlined,
                        texto: 'Vender 1 pieza',
                        precio: prod.precio,
                        alPresionar: () {
                          Navigator.pop(contextoHoja);
                          _agregarAlCarrito(prod);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BotonVariante(
                        icono: Icons.inventory_2_outlined,
                        texto: 'Vender 1 caja (${prod.piezasPorCaja} pz)',
                        precio: prod.precioCaja!,
                        alPresionar: () {
                          Navigator.pop(contextoHoja);
                          _agregarAlCarrito(prod, porCaja: true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarEdicionCarrito(ItemCarrito item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contextoHoja) => EdicionRenglon(
        clave: item.clave,
        alAvisar: (motivo) {
          Navigator.pop(contextoHoja);
          _mostrarAlertaInventario(motivo);
        },
      ),
    );
  }

  /// "+ Recibir Vacíos": vacíos extra que entrega el cliente; su depósito se
  /// descuenta del ticket.
  Future<void> _abrirRecepcionEnvases() async {
    final carrito = ref.read(carritoProvider);
    final r = await ModalRecepcionEnvases.mostrar(
      context,
      modo: ModoVacios.credito,
      cantidadInicial: carrito.totalRetornables > 0
          ? carrito.totalRetornables
          : 1,
      formatoInicial: carrito.retornables.isEmpty
          ? FormatoEnvase.media
          : FormatoEnvase.de(carrito.retornables.keys.first),
    );
    if (r == null || !mounted) return;
    ref
        .read(carritoProvider.notifier)
        .agregarCredito(r.formato.clave, r.cantidad);
  }

  /// 5.3: antes de cobrar, si hay retornables, se decide qué pasa con sus
  /// envases (cobrar depósito, intercambio o préstamo).
  Future<void> _iniciarCobro({BuildContext? contextoHoja}) async {
    if (contextoHoja != null) Navigator.pop(contextoHoja);
    final carrito = ref.read(carritoProvider);
    if (carrito.vacio) return;
    if (carrito.envasesPendientes) {
      final precios = ref.read(preciosEnvasesProvider);
      final accion = await ModalSalidaEnvases.mostrar(
        context: context,
        cantidadRetornables: carrito.totalRetornables,
        formatos: [
          for (final f in carrito.retornables.keys)
            FormatoEnvase.de(f).etiqueta,
        ].join(', '),
        montoDeposito: carrito.retornables.entries.fold(
          0,
          (t, e) => t + e.value * (precios[e.key] ?? 0),
        ),
      );
      if (accion == null || !mounted) return;
      final notificador = ref.read(carritoProvider.notifier);
      switch (accion) {
        case AccionSalidaEnvases.cobrarDeposito:
          notificador.resolverEnvases(ModoEnvases.cobrar);
        case AccionSalidaEnvases.clienteTrajoVacios:
          notificador.resolverEnvases(ModoEnvases.trae);
        case AccionSalidaEnvases.prestarEnvases:
          final retornables = carrito.retornables;
          final prestamo = await ModalRegistroPrestamo.mostrar(
            context,
            cantidadEnvases: carrito.totalRetornables,
            formato: retornables.length == 1
                ? FormatoEnvase.de(retornables.keys.single)
                : null,
          );
          if (prestamo == null || !mounted) return;
          notificador.resolverEnvases(
            ModoEnvases.prestamo,
            cliente: prestamo.cliente,
          );
      }
    }
    if (!mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const ResumenCompra()));
  }

  /// En el teléfono: el carrito en una hoja, con "+ Vacíos" e "Ir al Pago".
  void _abrirCarritoMovil() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      // La agarradera es la del diseño de Pablo, dentro del panel.
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (contextoHoja) => Container(
        height: MediaQuery.of(contextoHoja).size.height * 0.75,
        decoration: BoxDecoration(
          color: contextoHoja.colores.superficie,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: PanelVenta(
          movil: true,
          itemReciente: _itemRecienteClave,
          alEditar: _mostrarEdicionCarrito,
          alRecibirVacios: _abrirRecepcionEnvases,
          alCobrar: () => _iniciarCobro(contextoHoja: contextoHoja),
          alCerrar: () => Navigator.pop(contextoHoja),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider);
    return switch (productos) {
      AsyncData(:final value) => _venta(context, value),
      AsyncError(:final error) => EstadoError(
        error: error,
        alReintentar: () => ref.invalidate(productosProvider),
      ),
      _ => const Cargando(mensaje: 'Cargando productos'),
    };
  }

  Widget _venta(BuildContext context, List<Producto> todos) {
    final c = context.colores;
    final carrito = ref.watch(carritoProvider);
    final total = carrito.total(ref.watch(preciosEnvasesProvider));
    final esAncho = MediaQuery.sizeOf(context).width > 900;
    final categorias = categoriasDe(todos);
    final visibles = filtrarProductos(
      todos,
      busqueda: _busqueda.text,
      categoria: _categoria,
    );

    return Scaffold(
      backgroundColor: c.fondo,
      body: SafeArea(
        child: Row(
          children: [
            // Catálogo
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _busqueda,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (t) => _alEnviarBusqueda(todos, t),
                                decoration: InputDecoration(
                                  hintText: 'Buscar o escanear código...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: c.superficie,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Escanear con la cámara',
                              onPressed: () => _abrirEscaner(todos),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: c.azul.withValues(alpha: 0.1),
                                foregroundColor: c.azul,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final cat in [null, ...categorias])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FiltroCategorias(
                                    texto: cat == null
                                        ? 'Todas'
                                        : capitalizar(cat),
                                    activo: _categoria == cat,
                                    alElegir: () =>
                                        setState(() => _categoria = cat),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibles.isEmpty
                        ? const EstadoVacio(
                            icono: Icons.search_off_rounded,
                            titulo: 'Sin productos',
                            mensaje: 'Prueba con otra búsqueda o categoría.',
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: visibles.length,
                            itemBuilder: (context, i) {
                              final prod = visibles[i];
                              return TarjetaProductoVenta(
                                producto: prod,
                                enCarrito: carrito.piezasDe(prod.id),
                                alTocar: () => _alTocarProducto(prod),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Venta actual (en pantallas anchas)
            if (esAncho)
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: c.superficie2,
                  border: Border(left: BorderSide(color: c.linea)),
                ),
                child: PanelVenta(
                  itemReciente: _itemRecienteClave,
                  alEditar: _mostrarEdicionCarrito,
                  alRecibirVacios: _abrirRecepcionEnvases,
                  alCobrar: _iniciarCobro,
                ),
              ),
          ],
        ),
      ),

      // En pantallas angostas, el total en un botón que abre el carrito.
      floatingActionButton: (!esAncho && !carrito.vacio)
          ? ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.1).animate(
                CurvedAnimation(parent: _rebote, curve: Curves.elasticOut),
              ),
              child: FloatingActionButton.extended(
                onPressed: _abrirCarritoMovil,
                backgroundColor: c.azul,
                icon: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  dinero(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
