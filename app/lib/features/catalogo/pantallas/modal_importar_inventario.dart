import 'dart:convert';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';

/// Pide un CSV, lo revisa con el servidor y, si no hay errores, lo aplica.
/// Regresa el resultado guardado o `null` si se canceló.
Future<ResultadoImportacion?> abrirImportarInventario(
  BuildContext context,
) async {
  try {
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (archivo == null) return null;
    final bytes = await archivo.readAsBytes();
    if (!context.mounted) return null;
    if (bytes.length > 2 * 1024 * 1024) {
      avisar(context, 'El archivo pasa de 2 MB. Divídelo en partes.');
      return null;
    }
    final String csv;
    try {
      csv = utf8.decode(bytes);
    } on FormatException {
      avisar(context, 'El archivo no está en UTF-8.');
      return null;
    }
    if (!context.mounted) return null;
    return await showDialog<ResultadoImportacion>(
      context: context,
      builder: (_) =>
          DialogoImportarInventario(csv: csv, nombreArchivo: archivo.name),
    );
  } on Object catch (e) {
    if (context.mounted) {
      avisar(context, 'No se pudo abrir el archivo: ${mensajeDeError(e)}');
    }
    return null;
  }
}

/// Revisa el CSV antes de guardarlo: el servidor dice qué crearía, qué
/// actualizaría y qué renglones tienen error. Todo o nada.
class DialogoImportarInventario extends ConsumerStatefulWidget {
  const DialogoImportarInventario({
    super.key,
    required this.csv,
    required this.nombreArchivo,
  });

  final String csv;
  final String nombreArchivo;

  @override
  ConsumerState<DialogoImportarInventario> createState() =>
      _DialogoImportarInventarioState();
}

class _DialogoImportarInventarioState
    extends ConsumerState<DialogoImportarInventario> {
  ResultadoImportacion? _revision;
  String? _error;
  var _aplicando = false;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    setState(() {
      _error = null;
      _revision = null;
    });
    try {
      final api = await ref.read(apiProvider.future);
      final resultado = await api.importarProductos(
        widget.csv,
        soloRevisar: true,
      );
      if (mounted) setState(() => _revision = resultado);
    } on Object catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
  }

  Future<void> _aplicar() async {
    setState(() => _aplicando = true);
    try {
      final api = await ref.read(apiProvider.future);
      final resultado = await api.importarProductos(
        widget.csv,
        soloRevisar: false,
      );
      if (!mounted) return;
      if (resultado.errores.isEmpty) {
        Navigator.pop(context, resultado);
      } else {
        setState(() {
          _aplicando = false;
          _revision = resultado;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aplicando = false;
        _error = mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final revision = _revision;
    final puedeGuardar =
        revision != null && revision.errores.isEmpty && !revision.guardado;

    return AlertDialog(
      title: const Text('Importar inventario'),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: c.azul),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.nombreArchivo,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            Text(
              'Revisa lo que hará antes de guardar. Si un renglón tiene '
              'error, no se guarda ninguno.',
              style: TextStyle(color: c.tinta2),
            ),
            Expanded(child: _cuerpo(context, revision)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _aplicando ? null : () => Navigator.pop(context),
          child: const Text(Textos.cancelar),
        ),
        if (puedeGuardar)
          FilledButton.icon(
            onPressed: _aplicando ? null : _aplicar,
            icon: _aplicando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: const Text('Aplicar importación'),
          ),
      ],
    );
  }

  Widget _cuerpo(BuildContext context, ResultadoImportacion? revision) {
    final c = context.colores;
    if (_error case final error?) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.alerta),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _aplicando ? null : _revisar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(Textos.reintentar),
          ),
        ],
      );
    }
    if (revision == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final errores = revision.errores;
    return ListView(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Cuenta(
              valor: revision.creados,
              texto: _plural(revision.creados, 'nuevo', 'nuevos'),
              color: c.verde,
            ),
            _Cuenta(
              valor: revision.actualizados,
              texto: _plural(
                revision.actualizados,
                'actualizado',
                'actualizados',
              ),
              color: c.azul,
            ),
            _Cuenta(
              valor: revision.sinCambios,
              texto: _plural(revision.sinCambios, 'sin cambio', 'sin cambios'),
              color: c.tinta2,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (errores.isEmpty)
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: c.verde),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Todo listo para importar.',
                  style: TextStyle(color: c.verde, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          )
        else ...[
          Text(
            'Errores (${errores.length})',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: c.alerta),
          ),
          const SizedBox(height: 8),
          for (final error in errores)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.alertaSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    'Renglón ${error.renglon}'
                    '${error.codigo == null ? '' : ' · ${error.codigo}'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final campo in error.campos.entries)
                    Text('${campo.key}: ${campo.value}'),
                ],
              ),
            ),
        ],
        if (revision.cambiosExistencia.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Cambios de existencia',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final cambio in revision.cambiosExistencia)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${cambio.nombre} · renglón ${cambio.renglon}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${cambio.antes} a ${cambio.despues} pz',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static String _plural(int n, String singular, String plural) =>
      n == 1 ? singular : plural;
}

class _Cuenta extends StatelessWidget {
  const _Cuenta({
    required this.valor,
    required this.texto,
    required this.color,
  });

  final int valor;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$valor $texto',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
}
