import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/widgets/ilustracion_producto.dart';

Future<void> mostrarDetalleProducto(
  BuildContext context,
  Producto p, {
  List<Widget> acciones = const [],
  VoidCallback? alEditar,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) =>
      DetalleProducto(producto: p, acciones: acciones, alEditar: alEditar),
);

/// Ficha del producto: precio, existencia y datos del catálogo.
class DetalleProducto extends StatelessWidget {
  const DetalleProducto({
    super.key,
    required this.producto,
    this.acciones = const [],
    this.alEditar,
  });

  final Producto producto;

  /// Botones al final de la ficha (por ejemplo, agregar al pedido).
  final List<Widget> acciones;

  /// En la caja, abre el formulario para editar el producto.
  final VoidCallback? alEditar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final p = producto;
    final hoy = DateTime.now();
    final diasCaducidad = p.caducidad == null
        ? null
        : diasHasta(p.caducidad!, hoy);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 120,
                    child: IlustracionProducto(producto: p),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capitalizar(p.categoria).toUpperCase(),
                          style: textos.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(p.nombre, style: textos.headlineMedium),
                        if (p.presentacion != null)
                          Text(
                            p.presentacion!,
                            style: textos.bodyMedium?.copyWith(color: c.tinta2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'Pieza',
                      valor: dinero(p.precio),
                      resaltada: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Cifra(
                      etiqueta: p.piezasPorCaja == null
                          ? 'Caja'
                          : 'Caja de ${p.piezasPorCaja}',
                      valor: p.precioCaja == null ? '—' : dinero(p.precioCaja!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Cifra(
                etiqueta: 'Existencia',
                valor: existenciaLegible(p),
                detalle: p.bajoMinimo
                    ? 'Bajo el mínimo de ${p.minimo} pz'
                    : 'Mínimo ${p.minimo} pz',
                alerta: p.bajoMinimo,
              ),
              const SizedBox(height: 16),
              _Dato(
                icono: Icons.qr_code_2_rounded,
                etiqueta: 'Código',
                valor: p.codigo,
              ),
              if (p.envase != null)
                _Dato(
                  icono: Icons.recycling_rounded,
                  etiqueta: 'Envase retornable',
                  valor: capitalizar(p.envase!),
                ),
              if (p.caducidad != null)
                _Dato(
                  icono: Icons.event_rounded,
                  etiqueta: 'Caducidad',
                  valor:
                      '${fechaCorta(p.caducidad!)} · ${_textoDias(diasCaducidad!)}',
                  alerta: diasCaducidad <= 15,
                ),
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 18),
                ...acciones,
              ],
              if (alEditar != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: alEditar,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar producto'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _textoDias(int d) => switch (d) {
    < 0 => 'caducado',
    0 => 'caduca hoy',
    1 => 'mañana',
    _ => 'en $d días',
  };
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.valor,
    this.detalle,
    this.resaltada = false,
    this.alerta = false,
  });

  final String etiqueta;
  final String valor;
  final String? detalle;
  final bool resaltada;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final fondo = alerta
        ? c.alertaSuave
        : (resaltada ? c.lagerSuave : c.superficie2);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: textos.bodySmall),
          Text(
            valor,
            style: textos.headlineLarge?.copyWith(
              color: alerta ? c.alerta : null,
            ),
          ),
          if (detalle != null)
            Text(
              detalle!,
              style: textos.bodySmall?.copyWith(
                color: alerta ? c.alerta : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.alerta = false,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.linea)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 20, color: c.tinta2),
          const SizedBox(width: 12),
          Expanded(
            child: Text(etiqueta, style: TextStyle(color: c.tinta2)),
          ),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: alerta ? c.alerta : c.tinta,
            ),
          ),
        ],
      ),
    );
  }
}
