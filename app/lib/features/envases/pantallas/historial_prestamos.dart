import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../datos/modelos_envases.dart';
import '../estado/envases_provider.dart';
import 'acciones_envases.dart';

const _ambar = Color(0xFFD97706);
const _ambarOscuro = Color(0xFFB45309);
const _ambarBorde = Color(0xFFF59E0B);
const _ambarFondo = Color(0xFFFEF3C7);

bool _vencido(PrestamoEnvase p) =>
    diasDesde(p.fecha, DateTime.now()) >= diasPrestamoVencido;

/// 5.5 Historial de préstamos activos (diseño de Pablo): clientes que deben
/// envases, con búsqueda por nombre o teléfono, en ámbar los de más de 7
/// días y la acción rápida "Recibir".
class HistorialPrestamos extends ConsumerStatefulWidget {
  const HistorialPrestamos({super.key});

  @override
  ConsumerState<HistorialPrestamos> createState() => _HistorialPrestamosState();
}

class _HistorialPrestamosState extends ConsumerState<HistorialPrestamos> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final esIpad = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: c.superficie,
        elevation: 0,
        title: Text(
          'Préstamos de Envases Activos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: c.tinta,
          ),
        ),
        leading: IconButton(
          tooltip: Textos.volver,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => prestarEnvases(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Prestar'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: c.linea, height: 1),
        ),
      ),
      body: SafeArea(
        child: switch (ref.watch(envasesProvider)) {
          AsyncData(:final value) => _contenido(value.prestamos, esIpad),
          AsyncError(:final error) => EstadoError(
            error: error,
            alReintentar: () => ref.read(envasesProvider.notifier).refrescar(),
          ),
          _ => const Cargando(),
        },
      ),
    );
  }

  Widget _contenido(List<PrestamoEnvase> prestamos, bool esIpad) {
    final c = context.colores;
    final q = normalizarBusqueda(_busqueda);
    final filtrados = [
      for (final p in prestamos)
        if (q.isEmpty ||
            normalizarBusqueda(p.cliente).contains(q) ||
            (p.telefono ?? '').contains(_busqueda.trim()))
          p,
    ];

    return Column(
      children: [
        // Buscador: "Buscar por nombre del cliente o teléfono"
        Container(
          padding: const EdgeInsets.all(20),
          color: c.superficie,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _busqueda = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre del cliente o teléfono...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: c.superficie2,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.linea),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.linea),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.azul, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: c.superficie2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.linea),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 20, color: c.azul),
                    const SizedBox(width: 8),
                    Text(
                      '${filtrados.length} pendientes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.tinta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: c.linea,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _busqueda.isEmpty
                            ? 'No hay préstamos activos'
                            : 'No se encontraron clientes con "$_busqueda"',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: c.tinta2,
                        ),
                      ),
                    ],
                  ),
                )
              : esIpad
              ? _TablaPrestamosIpad(
                  prestamos: filtrados,
                  alRecibir: (p) => recibirPrestamo(context, ref, p),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _TarjetaPrestamoMovil(
                    prestamo: filtrados[i],
                    alRecibir: () =>
                        recibirPrestamo(context, ref, filtrados[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Inicial del cliente en un círculo, ámbar si está vencido.
class _Inicial extends StatelessWidget {
  const _Inicial({required this.prestamo, required this.radio});

  final PrestamoEnvase prestamo;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final vencido = _vencido(prestamo);
    return CircleAvatar(
      radius: radio,
      backgroundColor: vencido ? _ambarFondo : c.azul.withValues(alpha: 0.1),
      child: Text(
        prestamo.cliente.isNotEmpty ? prestamo.cliente[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: vencido ? _ambar : c.azul,
          fontSize: radio * 0.85,
        ),
      ),
    );
  }
}

/// Tarjeta para el teléfono.
class _TarjetaPrestamoMovil extends StatelessWidget {
  const _TarjetaPrestamoMovil({
    required this.prestamo,
    required this.alRecibir,
  });

  final PrestamoEnvase prestamo;
  final VoidCallback alRecibir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final vencido = _vencido(prestamo);
    final dias = diasDesde(prestamo.fecha, DateTime.now());
    final formato = FormatoEnvase.de(prestamo.formato);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: vencido ? _ambarBorde : c.linea,
          width: vencido ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Inicial(prestamo: prestamo, radio: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prestamo.cliente,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: vencido ? _ambarOscuro : c.tinta,
                      ),
                    ),
                    if (prestamo.telefono != null)
                      Text(
                        prestamo.telefono!,
                        style: TextStyle(fontSize: 13, color: c.tinta2),
                      ),
                  ],
                ),
              ),
              if (vencido)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ambarFondo,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _ambarBorde),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: _ambar,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$dias días',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _ambarOscuro,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${prestamo.cantidad} envases (${formato.etiqueta})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.tinta,
                      ),
                    ),
                    Text(
                      fechaHora(prestamo.fecha),
                      style: TextStyle(fontSize: 12, color: c.tinta2),
                    ),
                  ],
                ),
              ),
              _BotonRecibir(alTocar: alRecibir),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonRecibir extends StatelessWidget {
  const _BotonRecibir({required this.alTocar, this.compacto = false});

  final VoidCallback alTocar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ElevatedButton.icon(
      onPressed: alTocar,
      style: ElevatedButton.styleFrom(
        backgroundColor: c.verde,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 14 : 18,
          vertical: compacto ? 10 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compacto ? 10 : 12),
        ),
      ),
      icon: Icon(Icons.download_rounded, size: compacto ? 16 : 18),
      label: const Text(
        'Recibir',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Tabla para el iPad, con columnas ordenadas.
class _TablaPrestamosIpad extends StatelessWidget {
  const _TablaPrestamosIpad({required this.prestamos, required this.alRecibir});

  final List<PrestamoEnvase> prestamos;
  final void Function(PrestamoEnvase p) alRecibir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    const encabezado = TextStyle(fontWeight: FontWeight.bold);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: c.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.linea),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(c.superficie2),
            horizontalMargin: 20,
            columnSpacing: 24,
            dataRowMinHeight: 68,
            dataRowMaxHeight: 80,
            columns: const [
              DataColumn(label: Text('Cliente', style: encabezado)),
              DataColumn(label: Text('Fecha / Antigüedad', style: encabezado)),
              DataColumn(label: Text('Formato', style: encabezado)),
              DataColumn(label: Text('Pendientes', style: encabezado)),
              DataColumn(label: Text('Acción', style: encabezado)),
            ],
            rows: [
              for (final p in prestamos)
                _fila(c, p, _vencido(p), diasDesde(p.fecha, DateTime.now())),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _fila(ColoresAnaquel c, PrestamoEnvase p, bool vencido, int dias) =>
      DataRow(
        color: vencido
            ? WidgetStateProperty.all(const Color(0xFFFFFBEB))
            : null,
        cells: [
          DataCell(
            Row(
              children: [
                _Inicial(prestamo: p, radio: 16),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.cliente,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: vencido ? _ambarOscuro : c.tinta,
                      ),
                    ),
                    if (p.telefono != null)
                      Text(
                        p.telefono!,
                        style: TextStyle(fontSize: 12, color: c.tinta2),
                      ),
                  ],
                ),
              ],
            ),
          ),
          DataCell(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(fechaHora(p.fecha), style: const TextStyle(fontSize: 13)),
                if (vencido)
                  Text(
                    'Hace $dias días (vencido)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _ambar,
                    ),
                  ),
              ],
            ),
          ),
          DataCell(Text(FormatoEnvase.de(p.formato).etiqueta)),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: vencido ? _ambarFondo : c.superficie2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: vencido ? _ambarBorde : c.linea),
              ),
              child: Text(
                '${p.cantidad} pzs',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: vencido ? _ambarOscuro : c.tinta,
                ),
              ),
            ),
          ),
          DataCell(_BotonRecibir(alTocar: () => alRecibir(p), compacto: true)),
        ],
      );
}
