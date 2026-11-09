import 'dart:convert';
import 'dart:typed_data';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/formato/formato.dart';

/// Encabezado de la plantilla (`docs/plantilla_inventario.csv`). El archivo
/// que exporta la app se puede volver a importar sin cambios.
const columnasInventario = [
  'codigo',
  'nombre',
  'categoria',
  'presentacion',
  'precio',
  'precioCaja',
  'piezasPorCaja',
  'existencia',
  'minimo',
  'envase',
  'caducidad',
];

/// Inventario en CSV, con los precios en pesos como los lee el servidor.
String csvInventario(List<Producto> productos) {
  final renglones = <String>[
    columnasInventario.join(','),
    for (final p in productos)
      [
        _celda(p.codigo),
        _celda(p.nombre),
        _celda(p.categoria),
        _celda(p.presentacion),
        _celda(pesosEditables(p.precio)),
        _celda(p.precioCaja == null ? null : pesosEditables(p.precioCaja!)),
        _celda(p.piezasPorCaja),
        _celda(p.existenciaPiezas),
        _celda(p.minimo),
        _celda(p.envase),
        _celda(p.caducidad),
      ].join(','),
  ];
  // El BOM hace que Excel abra los acentos bien; el servidor lo ignora.
  return '\uFEFF${renglones.join('\n')}\n';
}

String _celda(Object? valor) {
  final texto = valor == null ? '' : '$valor';
  return '"${texto.replaceAll('"', '""')}"';
}

/// Pide dónde guardar el CSV del inventario. Regresa `false` si se canceló.
Future<bool> exportarInventario(List<Producto> productos) async {
  final hoy = DateTime.now();
  final fecha =
      '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}'
      '-${hoy.day.toString().padLeft(2, '0')}';
  final destino = await FilePicker.saveFile(
    fileName: 'inventario-$fecha.csv',
    bytes: Uint8List.fromList(utf8.encode(csvInventario(productos))),
    mimeType: 'text/csv',
  );
  return destino != null;
}
