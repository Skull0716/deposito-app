import 'package:deposito_backend/deposito_backend.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/imagenes/foto_producto.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/ilustracion_producto.dart';

Future<Producto?> abrirFormularioProducto(
  BuildContext context, {
  Producto? producto,
}) => showDialog<Producto>(
  context: context,
  builder: (_) => FormularioProducto(producto: producto),
);

/// Alta o edición de producto. Valida lo básico en pantalla; las reglas
/// finales las pone el servidor y sus errores se muestran en el campo que
/// corresponde.
class FormularioProducto extends ConsumerStatefulWidget {
  const FormularioProducto({super.key, this.producto});

  /// Con un producto, el formulario lo edita; sin él, da de alta uno nuevo.
  final Producto? producto;

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
  Uint8List? _fotoPendiente;
  var _quitarFoto = false;

  bool get _editando => widget.producto != null;
  bool get _tieneFoto =>
      _fotoPendiente != null || (!_quitarFoto && widget.producto?.foto != null);

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p == null) return;
    _codigo.text = p.codigo;
    _nombre.text = p.nombre;
    _categoria.text = p.categoria;
    _presentacion.text = p.presentacion ?? '';
    _precio.text = pesosEditables(p.precio);
    _porCaja = p.precioCaja != null || p.piezasPorCaja != null;
    _precioCaja.text = p.precioCaja == null
        ? ''
        : pesosEditables(p.precioCaja!);
    _piezasPorCaja.text = p.piezasPorCaja?.toString() ?? '';
    _existencia.text = p.existenciaPiezas.toString();
    _minimo.text = p.minimo.toString();
    _envase = p.envase;
    _caducidad = p.caducidad == null ? null : DateTime.tryParse(p.caducidad!);
  }

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

  Future<void> _elegirFoto() async {
    try {
      final archivo = await FilePicker.pickFile(type: FileType.image);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted || bytes.isEmpty) return;
      final reducida = reducirFotoProducto(bytes);
      if (!mounted) return;
      if (reducida == null) {
        avisar(context, 'No se pudo leer la imagen. Prueba con otra foto.');
        return;
      }
      setState(() {
        _fotoPendiente = reducida;
        _quitarFoto = false;
      });
    } on Object catch (e) {
      if (mounted) {
        avisar(context, 'No se pudo abrir la foto: ${mensajeDeError(e)}');
      }
    }
  }

  void _quitarFotoSeleccionada() => setState(() {
    _fotoPendiente = null;
    _quitarFoto = true;
  });

  /// Producto para dibujar la vista previa cuando no hay una foto elegida.
  Producto _productoParaVista() {
    final base = widget.producto;
    if (base != null) {
      return _quitarFoto
          ? Producto.fromJson({...base.toJson(), 'foto': null})
          : base;
    }
    final categoria = _categoria.text.trim().toLowerCase();
    final nombre = _nombre.text.trim();
    final presentacion = _presentacion.text.trim();
    return Producto.fromJson({
      'id': 'nuevo',
      'codigo': _codigo.text.trim(),
      'nombre': nombre.isEmpty ? 'Producto' : nombre,
      'categoria': categoria.isEmpty ? 'cerveza' : categoria,
      'presentacion': presentacion.isEmpty ? null : presentacion,
      'precio': 0,
      'existenciaPiezas': 0,
      'minimo': 0,
      'envase': _envase,
      'foto': null,
      'creado': '2026-01-01T00:00:00Z',
      'actualizado': '2026-01-01T00:00:00Z',
    });
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
    final piezasPorCaja = _porCaja ? int.tryParse(_piezasPorCaja.text) : null;
    if (_porCaja && (piezasPorCaja == null || piezasPorCaja <= 0)) {
      errores['piezasPorCaja'] = 'Escribe cuántas piezas trae la caja';
    }
    setState(() => _errores = errores);
    if (errores.isNotEmpty) return;

    final caducidad = _caducidad;
    final datos = <String, Object?>{
      'codigo': _codigo.text.trim(),
      'nombre': _nombre.text.trim(),
      'categoria': _categoria.text.trim().toLowerCase(),
      'presentacion': _presentacion.text.trim().isEmpty
          ? null
          : _presentacion.text.trim(),
      'precio': precio,
      'precioCaja': _porCaja ? precioCaja : null,
      'piezasPorCaja': _porCaja ? piezasPorCaja : null,
      'minimo': int.tryParse(_minimo.text) ?? 0,
      'envase': _envase,
      'caducidad': caducidad == null
          ? null
          : '${caducidad.year}-${caducidad.month.toString().padLeft(2, '0')}-${caducidad.day.toString().padLeft(2, '0')}',
      // El servidor ignora la existencia al editar: solo cambia con
      // entradas y ajustes (docs/API.md).
      if (!_editando) 'existenciaPiezas': int.tryParse(_existencia.text) ?? 0,
    };

    setState(() => _guardando = true);
    try {
      final api = await ref.read(apiProvider.future);
      var producto = _editando
          ? await api.editarProducto(widget.producto!.id, datos)
          : await api.crearProducto(datos);

      // La foto se sube después de guardar: así cancelar el formulario no
      // cambia la foto del producto.
      String? avisoFoto;
      if (_fotoPendiente case final foto?) {
        try {
          producto = await api.subirFoto(producto.id, foto, 'image/jpeg');
        } on FalloApi catch (e) {
          avisoFoto = 'El producto se guardó, pero la foto no: ${e.mensaje}';
        }
      } else if (_quitarFoto && _editando) {
        try {
          producto = await api.borrarFoto(producto.id);
        } on FalloApi catch (e) {
          avisoFoto =
              'Los cambios se guardaron, pero no se quitó la foto: '
              '${e.mensaje}';
        }
      }

      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.pop(context, producto);
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              avisoFoto ??
                  (_editando
                      ? '${producto.nombre} se actualizó'
                      : '${producto.nombre} quedó en el catálogo'),
            ),
          ),
        );
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
      void Function(String)? alCambiar,
    }) => TextField(
      controller: ctrl,
      inputFormatters: formato,
      keyboardType: teclado,
      onChanged: alCambiar,
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
                    child: Text(
                      _editando ? 'Editar producto' : 'Nuevo producto',
                      style: textos.headlineMedium,
                    ),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: c.superficie2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.linea),
                          ),
                          child: _fotoPendiente != null
                              ? Image.memory(_fotoPendiente!, fit: BoxFit.cover)
                              : IlustracionProducto(
                                  producto: _productoParaVista(),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 6,
                            children: [
                              Text(
                                'Foto del producto',
                                style: textos.titleSmall,
                              ),
                              Text(
                                _fotoPendiente != null
                                    ? 'Se subirá al guardar'
                                    : _tieneFoto
                                    ? 'Foto actual'
                                    : 'Se usará una ilustración',
                                style: TextStyle(color: c.tinta2),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _guardando ? null : _elegirFoto,
                                    icon: const Icon(
                                      Icons.photo_camera_outlined,
                                    ),
                                    label: const Text('Subir foto'),
                                  ),
                                  if (_tieneFoto)
                                    TextButton.icon(
                                      onPressed: _guardando
                                          ? null
                                          : _quitarFotoSeleccionada,
                                      icon: const Icon(
                                        Icons.hide_image_outlined,
                                      ),
                                      label: const Text('Quitar foto'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    campo(
                      'codigo',
                      'Código de barras',
                      _codigo,
                      teclado: TextInputType.number,
                      alCambiar: (_) => setState(() {}),
                    ),
                    campo('nombre', 'Nombre', _nombre),
                    fila([
                      campo(
                        'categoria',
                        'Categoría',
                        _categoria,
                        ayuda: 'cerveza, refresco, botana, hielo…',
                        alCambiar: (_) => setState(() {}),
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
                    if (_editando)
                      Text(
                        'La existencia no se cambia aquí: usa Recibir '
                        'mercancía o un ajuste de inventario.',
                        style: TextStyle(color: c.tinta2, fontSize: 13),
                      )
                    else
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
                    label: Text(
                      _editando ? 'Guardar cambios' : 'Guardar producto',
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
}
