import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';
import '../../catalogo/estado/productos.dart';
import '../../catalogo/pantallas/detalle_producto.dart';
import '../../catalogo/pantallas/modal_recibir_mercancia.dart';
import '../estado/alertas_provider.dart';

const _ambar = Color(0xFFD97706);
const _ambarFondo = Color(0xFFFEF3C7);

/// Alertas de inventario de la caja (docs/API.md): productos agotados, bajo
/// su mínimo o con caducidad próxima. Se recalculan en cada petición.
class PantallaAlertas extends ConsumerWidget {
  const PantallaAlertas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasProvider);
    final valor = alertas.value;
    if (valor != null) {
      return _Contenido(alertas: valor, actualizando: alertas.isLoading);
    }
    return switch (alertas) {
      AsyncError(:final error) => EstadoError(
        error: error,
        alReintentar: () => ref.invalidate(alertasProvider),
      ),
      _ => const Cargando(),
    };
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.alertas, required this.actualizando});

  final AlertasDelDia alertas;
  final bool actualizando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final dias = ref.watch(diasAlertasProvider);
    final stock = [
      for (final a in alertas.alertas)
        if (a.esDeExistencia) a,
    ];
    final caducan = [
      for (final a in alertas.alertas)
        if (!a.esDeExistencia) a,
    ];
    final total = alertas.alertas.length;

    return RefreshIndicator(
      onRefresh: () => ref.read(alertasProvider.notifier).refrescar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        children: [
          if (actualizando) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 1
                        ? '1 producto necesita atención'
                        : '$total productos necesitan atención',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Inventario del ${fechaCorta(alertas.dia)}',
                    style: TextStyle(color: c.tinta2),
                  ),
                ],
              ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 días')),
                  ButtonSegment(value: 15, label: Text('15 días')),
                  ButtonSegment(value: 30, label: Text('30 días')),
                ],
                selected: {dias},
                onSelectionChanged: (seleccion) => ref
                    .read(diasAlertasProvider.notifier)
                    .cambiar(seleccion.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (total == 0)
            _TodoEnOrden(dias: dias)
          else
            LayoutBuilder(
              builder: (context, medidas) {
                final columnas = medidas.maxWidth >= 900;
                final pocoStock = _ColumnaAlertas(
                  titulo: 'Poco stock',
                  icono: Icons.inventory_2_outlined,
                  color: c.alerta,
                  vacio: 'Todo está sobre su mínimo.',
                  items: stock,
                  dias: dias,
                );
                final porCaducar = _ColumnaAlertas(
                  titulo: 'Caducan pronto',
                  icono: Icons.event_busy_outlined,
                  color: _ambar,
                  vacio: 'Nada vence en los próximos $dias días.',
                  items: caducan,
                  dias: dias,
                );
                if (!columnas) {
                  return Column(
                    children: [
                      pocoStock,
                      const SizedBox(height: 16),
                      porCaducar,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pocoStock),
                    const SizedBox(width: 16),
                    Expanded(child: porCaducar),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          Text(
            'Se avisa $dias días antes de la caducidad y cuando un producto '
            'baja de su mínimo.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: c.tinta2),
          ),
        ],
      ),
    );
  }
}

class _ColumnaAlertas extends StatelessWidget {
  const _ColumnaAlertas({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.vacio,
    required this.items,
    required this.dias,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final String vacio;
  final List<Alerta> items;
  final int dias;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Icon(icono, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _Cantidad(total: items.length, color: color),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
              child: Text(vacio, style: TextStyle(color: c.tinta2)),
            )
          else
            for (var i = 0; i < items.length; i++)
              _FilaAlerta(alerta: items[i], dias: dias, primera: i == 0),
        ],
      ),
    );
  }
}

class _FilaAlerta extends ConsumerWidget {
  const _FilaAlerta({
    required this.alerta,
    required this.dias,
    required this.primera,
  });

  final Alerta alerta;
  final int dias;
  final bool primera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final p = alerta.producto;
    final motivo = _motivo(alerta, c);
    final esStock = alerta.esDeExistencia;

    return InkWell(
      onTap: () => mostrarDetalleProducto(context, p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: primera ? null : Border(top: BorderSide(color: c.linea)),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    esStock
                        ? '${existenciaLegible(p)} · mínimo ${p.minimo} pz'
                        : '${fechaCorta(p.caducidad!)} · '
                              '${existenciaLegible(p)}',
                    style: TextStyle(color: c.tinta2, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  _Etiqueta(texto: motivo.texto, color: motivo.color),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (esStock)
              FilledButton.tonal(
                onPressed: () async {
                  final listo = await mostrarRecibirMercancia(context, p);
                  if (!listo || !context.mounted) return;
                  avisar(context, '${p.nombre}: entrada registrada');
                  ref.invalidate(productosProvider);
                  ref.invalidate(alertasProvider);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text(Textos.recibir),
              )
            else
              OutlinedButton(
                onPressed: () => mostrarDetalleProducto(context, p),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text(Textos.ver),
              ),
          ],
        ),
      ),
    );
  }

  static ({String texto, Color color}) _motivo(Alerta a, ColoresAnaquel c) {
    final dias = a.diasParaCaducar ?? 0;
    return switch (a.tipo) {
      TiposAlerta.agotado => (texto: 'Agotado', color: c.alerta),
      TiposAlerta.pocoStock => (texto: 'Poco stock', color: _ambar),
      TiposAlerta.caducado => (texto: 'Vencido', color: c.alerta),
      _ when dias <= 0 => (texto: 'Vence hoy', color: c.alerta),
      _ when dias <= 7 => (texto: 'En $dias días', color: _ambar),
      _ => (texto: 'En $dias días', color: c.azul),
    };
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color == _ambar ? _ambarFondo : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Cantidad extends StatelessWidget {
  const _Cantidad({required this.total, required this.color});

  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$total',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TodoEnOrden extends StatelessWidget {
  const _TodoEnOrden({required this.dias});

  final int dias;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 46, color: c.verde),
          const SizedBox(height: 12),
          Text('Todo en orden', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'No hay productos bajo su mínimo ni caducidades en los próximos '
            '$dias días.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.tinta2),
          ),
        ],
      ),
    );
  }
}
