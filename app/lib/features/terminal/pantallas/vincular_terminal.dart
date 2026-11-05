import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/api.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/config/configuracion.dart';
import '../../../core/widgets/marca.dart';
import 'escaner.dart';

/// Vincula esta terminal con la caja: escaneando el QR que muestra la caja
/// o escribiendo IP y código a mano (útil con el servidor de la laptop).
class VincularTerminal extends ConsumerStatefulWidget {
  const VincularTerminal({super.key});

  @override
  ConsumerState<VincularTerminal> createState() => _VincularTerminalState();
}

class _VincularTerminalState extends ConsumerState<VincularTerminal> {
  final _nombre = TextEditingController(
    // `defaultTargetPlatform` funciona también en web, donde `dart:io`
    // (`Platform.isIOS`) lanza UnsupportedError.
    text: defaultTargetPlatform == TargetPlatform.iOS
        ? 'iPhone'
        : 'Terminal S24',
  );
  final _host = TextEditingController();
  final _puerto = TextEditingController(text: '8080');
  final _codigo = TextEditingController();
  var _manual = false;
  var _conectando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _host, _puerto, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escanearQr() async {
    final texto = await escanearCodigo(
      context,
      titulo: 'Código de la caja',
      ayuda: 'En la caja toca "Vincular Terminal"',
    );
    if (texto == null) return;
    try {
      final datos = jsonDecode(texto) as Map<String, Object?>;
      _host.text = datos['host'] as String;
      _puerto.text = '${datos['puerto']}';
      _codigo.text = datos['codigo'] as String;
    } on Object {
      setState(
        () => _error = 'Ese no es el código de la caja. Escanea el QR de "Vincular Terminal".',
      );
      return;
    }
    await _vincular();
  }

  Future<void> _vincular() async {
    final puerto = int.tryParse(_puerto.text);
    if (_host.text.trim().isEmpty ||
        puerto == null ||
        _codigo.text.length != 6) {
      setState(
        () => _error =
            'Escribe la IP de la caja, el puerto y el código de 6 dígitos.',
      );
      return;
    }
    setState(() {
      _conectando = true;
      _error = null;
    });
    try {
      final host = _host.text.trim();
      final registro = await ApiHttp.registrarTerminal(
        base: Uri(scheme: 'http', host: host, port: puerto),
        nombre: _nombre.text.trim().isEmpty ? 'Terminal' : _nombre.text.trim(),
        codigo: _codigo.text,
      );
      await ref
          .read(configuracionProvider.notifier)
          .guardarConexion(
            ConexionTerminal(
              host: host,
              puerto: puerto,
              clave: registro.clave,
              nombre: registro.terminal.nombre,
            ),
          );
    } on FalloApi catch (e) {
      if (mounted) {
        setState(() {
          _conectando = false;
          _error = e.codigo == 'codigo_invalido'
              ? 'El código es incorrecto o ya venció. Genera otro en la caja.'
              : e.mensaje;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => ref
                            .read(configuracionProvider.notifier)
                            .elegirModo(null),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Cambiar modo',
                      ),
                      const Spacer(),
                      const LogoAnaquel(tamano: 40),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Vincula esta terminal', style: textos.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    'En la caja toca "Vincular Terminal" y escanea el código que aparece. '
                    'El teléfono y la caja deben estar en la misma Wi-Fi.',
                    style: textos.bodyLarge?.copyWith(color: c.tinta2),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de esta terminal',
                      helperText: 'Así aparecerá en la caja y en los pedidos',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _conectando ? null : _escanearQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear el código de la caja'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => _manual = !_manual),
                    child: Text(
                      _manual ? 'Ocultar' : 'Escribir los datos a mano',
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: !_manual
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 12,
                              children: [
                                Row(
                                  spacing: 10,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _host,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'IP de la caja',
                                          hintText: '192.168.1.20',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _puerto,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Puerto',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: _codigo,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: textos.headlineMedium?.copyWith(
                                    letterSpacing: 6,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Código de 6 dígitos',
                                    counterText: '',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: _conectando ? null : _vincular,
                                  child: const Text('Vincular'),
                                ),
                              ],
                            ),
                          ),
                  ),
                  if (_conectando) ...[
                    const SizedBox(height: 18),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.alertaSuave,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, color: c.alerta),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: c.alerta,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
