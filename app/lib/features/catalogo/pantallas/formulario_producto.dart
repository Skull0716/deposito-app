import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';

Future<Producto?> abrirFormularioProducto(BuildContext context) =>
    showDialog<Producto>(
      context: context,
      builder: (_) => const FormularioProducto(),
    );

/// Alta de producto. Valida lo básico en pantalla; las reglas finales las
/// pone el servidor y sus errores se muestran en el campo que corresponde.
class FormularioProducto extends ConsumerStatefulWidget {
  const FormularioProducto({super.key});

  @override
  ConsumerState<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends ConsumerState<FormularioProducto> {
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _categoria = TextEditingController(text: 'cerveza');
  final _presentacion = TextEditingController();
  final _precio = TextEditingController();
  final _precioCaja = TextEditingController();
  final _piezasPorCaja = TextEditingController();
  final _existencia = TextEditingController(text: '0');
  final _minimo = TextEditingController(text: '0');
  var _porCaja = false;
  String? _envase;
  DateTime? _caducidad;
  var _guardando = false;
  Map<String, String> _errores = {};

  @override
  void dispose() {
    for (final c in [
      _codigo,
      _nombre,
      _categoria,
      _presentacion,
      _precio,
      _precioCaja,
      _piezasPorCaja,
      _existencia,
      _minimo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final errores = <String, String>{};
    final precio = centavosDesdeTexto(_precio.text);
    if (precio == null || precio == 0) {
      errores['precio'] = 'Escribe el precio, por ejemplo 42.50';
    }
    final precioCaja = _porCaja ? centavosDesdeTexto(_precioCaja.text) : null;
    if (_porCaja && (precioCaja == null || precioCaja == 0)) {
      errores['precioCaja'] = 'Escribe el precio de la caja';
    }
    setState(() => _errores = errores);
    if (errores.isNotEmpty) return;

    final caducidad = _caducidad;
    final datos = <String, Object?>{
      'codigo': _codigo.text.trim(),
      'nombre': _nombre.text.trim(),
      'categoria': _categoria.text.trim().toLowerCase(),
      if (_presentacion.text.trim().isNotEmpty)
        'presentacion': _presentacion.text.trim(),
      'precio': precio,
      if (_porCaja) 'precioCaja': precioCaja,
      if (_porCaja) 'piezasPorCaja': int.tryParse(_piezasPorCaja.text) ?? 0,
      'existenciaPiezas': int.tryParse(_existencia.text) ?? 0,
      'minimo': int.tryParse(_minimo.text) ?? 0,
      'envase': _envase,
      if (caducidad != null)
        'caducidad':
            '${caducidad.year}-${caducidad.month.toString().padLeft(2, '0')}-${caducidad.day.toString().padLeft(2, '0')}',
    };

    setState(() => _guardando = true);
    try {
      final api = await ref.read(apiProvider.future);
      final producto = await api.crearProducto(datos);
      if (!mounted) return;
      Navigator.pop(context, producto);
      avisar(context, '${producto.nombre} quedó en el catálogo');
    } on FalloApi catch (e) {
      setState(() {
        _guardando = false;
        _errores = e.campos.isNotEmpty ? e.campos : {'codigo': e.mensaje};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final soloNumeros = [FilteringTextInputFormatter.digitsOnly];
    final dinero = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,$]'))];

    Widget campo(
      String clave,
      String etiqueta,
      TextEditingController ctrl, {
      List<TextInputFormatter>? formato,
      TextInputType? teclado,
      String? ayuda,
      String? prefijo,
    }) => TextField(
      controller: ctrl,
      inputFormatters: formato,
      keyboardType: teclado,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        prefixText: prefijo,
        errorText: _errores[clave],
        errorMaxLines: 2,
      ),
    );

    Widget fila(List<Widget> hijos) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < hijos.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: hijos[i]),
        ],
      ],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Nuevo producto', style: textos.headlineMedium),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: Textos.cerrar,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    campo(
                      'codigo',
                      'Código de barras',
                      _codigo,
                      teclado: TextInputType.number,
                    ),
                    campo('nombre', 'Nombre', _nombre),
                    fila([
                      campo(
                        'categoria',
                        'Categoría',
                        _categoria,
                        ayuda: 'cerveza, refresco, botana, hielo…',
                      ),
                      campo(
                        'presentacion',
                        'Presentación',
                        _presentacion,
                        ayuda: 'Mega 1.2 L',
                      ),
                    ]),
                    fila([
                      campo(
                        'precio',
                        'Precio por pieza',
                        _precio,
                        formato: dinero,
                        prefijo: '\$ ',
                        teclado: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      campo(
                        'minimo',
                        'Mínimo (piezas)',
                        _minimo,
                        formato: soloNumeros,
                        teclado: TextInputType.number,
                      ),
                    ]),
                    SwitchListTile.adaptive(
                      value: _porCaja,
                      onChanged: (v) => setState(() => _porCaja = v),
                      title: const Text('También se vende por caja'),
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: c.lager,
                    ),
                    if (_porCaja)
                      fila([
                        campo(
                          'precioCaja',
                          'Precio por caja',
                          _precioCaja,
                          formato: dinero,
                          prefijo: '\$ ',
                          teclado: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        campo(
                          'piezasPorCaja',
                          'Piezas por caja',
                          _piezasPorCaja,
                          formato: soloNumeros,
                          teclado: TextInputType.number,
                        ),
                      ]),
                    campo(
                      'existenciaPiezas',
                      'Existencia inicial (piezas)',
                      _existencia,
                      formato: soloNumeros,
                      teclado: TextInputType.number,
                      ayuda: 'Queda registrada como movimiento de inventario',
                    ),
                    Text(
                      'Envase retornable',
                      style: textos.labelMedium?.copyWith(color: c.tinta2),
                    ),
                    SegmentedButton<String?>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: null, label: Text('Ninguno')),
                        ButtonSegment(value: 'mega', label: Text('Mega')),
                        ButtonSegment(value: 'media', label: Text('Media')),
                        ButtonSegment(value: 'cuarto', label: Text('Cuarto')),
                      ],
                      selected: {_envase},
                      onSelectionChanged: (s) =>
                          setState(() => _envase = s.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: c.seleccion,
                        selectedForegroundColor: c.seleccionTinta,
                        side: BorderSide(color: c.linea),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final hoy = DateTime.now();
                        final f = await showDatePicker(
                          context: context,
                          firstDate: hoy,
                          lastDate: DateTime(hoy.year + 5),
                          initialDate:
                              _caducidad ?? hoy.add(const Duration(days: 90)),
                        );
                        if (f != null) setState(() => _caducidad = f);
                      },
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        _caducidad == null
                            ? 'Agregar caducidad (opcional)'
                            : 'Caduca el ${fechaCorta(_caducidad!.toIso8601String().substring(0, 10))} ${_caducidad!.year}',
                      ),
                    ),
                    if (_errores['caducidad'] case final e?)
                      Text(e, style: TextStyle(color: c.alerta)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: const Text(Textos.cancelar),
                  ),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Guardar producto'),
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
