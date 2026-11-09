import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';
import '../../catalogo/estado/productos.dart';
import '../datos/modelos_ventas.dart';
import '../estado/ventas_provider.dart';
import 'modal_autorizacion_numpad.dart';
import 'modal_destino_stock.dart';

/// 6.4 Cancelación o devolución (diseño de Pablo): se eligen qué artículos
/// y cuántos se devuelven, con el reembolso en tiempo real, y luego el
/// destino de la mercancía y la autorización.
///
/// Si se devuelve todo lo que falta, es una cancelación; si no, una
/// devolución parcial.
class FlujoCancelacion extends ConsumerStatefulWidget {
  const FlujoCancelacion({super.key, required this.venta});

  final DetalleVenta venta;

  static Future<bool?> mostrar({
    required BuildContext context,
    required DetalleVenta venta,
  }) => Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FlujoCancelacion(venta: venta),
    ),
  );

  @override
  ConsumerState<FlujoCancelacion> createState() => _FlujoCancelacionState();
}

class _FlujoCancelacionState extends ConsumerState<FlujoCancelacion> {
  late final Map<int, int> _cantidades = {
    for (final l in widget.venta.lineas) l.lineaId: l.porDevolver,
  };
  late final Map<int, bool> _seleccionados = {
    for (final l in widget.venta.lineas) l.lineaId: l.porDevolver > 0,
  };
  bool _procesando = false;

  DetalleVenta get _v => widget.venta;

  /// `lineaId → unidades` que se devuelven.
  Map<int, int> get _aDevolver => {
    for (final l in _v.lineas)
      if ((_seleccionados[l.lineaId] ?? false) &&
          (_cantidades[l.lineaId] ?? 0) > 0)
        l.lineaId: _cantidades[l.lineaId]!,
  };

  /// Se devuelve todo lo que falta: es una cancelación.
  bool get _esTodo =>
      _v.lineas.every((l) => (_aDevolver[l.lineaId] ?? 0) == l.porDevolver);

  int get _totalArticulos => _aDevolver.values.fold(0, (total, n) => total + n);

  /// Como el servidor: si es todo, lo que falta del total (con depósito y
  /// crédito); si no, precio con descuento más depósito de lo devuelto.
  int get _monto {
    if (_esTodo) return _v.total - _v.devuelto;
    var total = 0;
    for (final l in _v.lineas) {
      total += l.reembolso(_aDevolver[l.lineaId] ?? 0);
    }
    return total;
  }

  Future<void> _continuar() async {
    if (_totalArticulos == 0 && !_esTodo) return;
    // 6.5 Destino de la mercancía (obligatorio si se devuelven productos).
    var destino = DestinoStock.regresarInventario;
    if (_totalArticulos > 0) {
      final elegido = await ModalDestinoStock.mostrar(
        context: context,
        totalArticulosDevueltos: _totalArticulos,
      );
      if (elegido == null || !mounted) return;
      destino = elegido;
    }
    // 6.6 Autorización de gerente o dueño, si hay alguno registrado.
    final autorizacion = await pedirAutorizacion(
      context,
      ref,
      tituloAccion: _esTodo ? 'Cancelar Venta' : 'Devolver Artículos',
    );
    if (autorizacion == null || !mounted) return;

    setState(() => _procesando = true);
    final ventas = ref.read(ventasProvider.notifier);
    final monto = _monto;
    try {
      if (_esTodo) {
        await ventas.cancelar(
          _v.id,
          pin: autorizacion.pin,
          destino: destino.clave,
          motivo: 'Devolución de $_totalArticulos artículos',
        );
      } else {
        await ventas.devolver(
          _v.id,
          lineas: _aDevolver,
          pin: autorizacion.pin,
          destino: destino.clave,
          motivo: 'Devolución de $_totalArticulos artículos',
        );
      }
    } on FalloApi catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      avisar(context, e.campos.values.firstOrNull ?? mensajeDeError(e));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, true);
    avisar(
      context,
      _esTodo
          ? 'Ticket #${_v.folio} cancelado. Reembolso: ${dinero(monto)}'
          : 'Devolución del ticket #${_v.folio}. Reembolso: ${dinero(monto)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final puedeContinuar =
        !_procesando && _monto > 0 && (_totalArticulos > 0 || _esTodo);
    final productos = ref.watch(productosProvider).value ?? const [];

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: c.superficie,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancelar Venta / Devolución',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.tinta,
              ),
            ),
            Text(
              'Folio #${_v.folio} • Total original: ${dinero(_v.total)}'
              '${_v.devuelto > 0 ? ' • Ya devuelto: ${dinero(_v.devuelto)}' : ''}',
              style: TextStyle(fontSize: 12, color: c.tinta2),
            ),
          ],
        ),
        leading: IconButton(
          tooltip: Textos.cerrar,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: c.linea, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instrucción superior
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: c.superficie,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: rojoCancelacion.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_return_rounded,
                      color: rojoCancelacion,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccione los artículos a devolver',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.tinta,
                          ),
                        ),
                        Text(
                          'Puedes desmarcar productos o reducir cantidades '
                          'para devoluciones parciales',
                          style: TextStyle(fontSize: 12, color: c.tinta2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Lista interactiva de artículos del ticket
            Expanded(
              child: _v.lineas.isEmpty
                  ? Center(
                      child: Text(
                        'Venta de envases vacíos: se cancela completa',
                        style: TextStyle(color: c.tinta2),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _v.lineas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _fila(
                        c,
                        _v.lineas[i],
                        productos
                            .where((p) => p.id == _v.lineas[i].productoId)
                            .firstOrNull,
                      ),
                    ),
            ),

            // Resumen inferior fijo
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: c.superficie,
                border: Border(top: BorderSide(color: c.linea)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monto a Reembolsar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: rojoCancelacion,
                            ),
                          ),
                          Text(
                            _esTodo
                                ? 'Cancelación completa'
                                : '$_totalArticulos artículos seleccionados',
                            style: TextStyle(fontSize: 12, color: c.tinta2),
                          ),
                        ],
                      ),
                      Text(
                        dinero(_monto),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: rojoCancelacion,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: puedeContinuar ? _continuar : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: rojoCancelacion,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: c.linea,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _procesando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text(
                        'Continuar Cancelación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(ColoresAnaquel c, LineaTicket l, Producto? producto) {
    final seleccionado = _seleccionados[l.lineaId] ?? false;
    final actual = _cantidades[l.lineaId] ?? 0;
    final maximo = l.porDevolver;
    final atenuado = !seleccionado || actual == 0;
    final unidad = l.porCaja ? 'cajas' : 'pzs';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: maximo == 0 ? 0.35 : (atenuado ? 0.45 : 1.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.superficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seleccionado && actual > 0
                ? rojoCancelacion.withValues(alpha: 0.4)
                : c.linea,
            width: seleccionado && actual > 0 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Checkbox(
              value: seleccionado,
              activeColor: rojoCancelacion,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onChanged: maximo == 0
                  ? null
                  : (val) => setState(() {
                      final nuevo = val ?? false;
                      _seleccionados[l.lineaId] = nuevo;
                      if (nuevo && actual == 0) _cantidades[l.lineaId] = maximo;
                    }),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              height: 50,
              child: producto == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.linea),
                      ),
                      child: Icon(Icons.inventory_2_rounded, color: c.tinta2),
                    )
                  : IlustracionProducto(producto: producto, radio: 12),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.nombre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.tinta,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dinero(l.precioUnit)} c/u • Original: ${l.cantidad} $unidad'
                    '${l.devueltas > 0 ? ' • Ya devueltas: ${l.devueltas}' : ''}',
                    style: TextStyle(fontSize: 12, color: c.tinta2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: c.superficie2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.linea),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Menos',
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: actual > 0 && seleccionado
                        ? () => setState(() {
                            _cantidades[l.lineaId] = actual - 1;
                            if (actual - 1 == 0) {
                              _seleccionados[l.lineaId] = false;
                            }
                          })
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$actual',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: c.tinta,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Más',
                    icon: const Icon(Icons.add_rounded, size: 18),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: actual < maximo && seleccionado
                        ? () => setState(
                            () => _cantidades[l.lineaId] = actual + 1,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
