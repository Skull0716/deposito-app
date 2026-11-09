import 'dart:math' as math;

import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/teclado_numerico.dart';
import '../datos/modelos_ventas.dart';

/// Pide autorización para una acción sensible.
///
/// - `null`: se canceló.
/// - `(pin: null)`: no se necesita (no hay gerente ni dueño registrado).
/// - `(pin: '...')`: PIN ya verificado de un gerente o del dueño.
Future<({String? pin})?> pedirAutorizacion(
  BuildContext context,
  WidgetRef ref, {
  String tituloAccion = 'Cancelar Venta',
}) async {
  final api = await ref.read(apiProvider.future);
  final List<Usuario> usuarios;
  try {
    usuarios = await api.listarUsuarios();
  } on FalloApi {
    // Sin poder saberlo, se pide: el servidor decide al final.
    if (!context.mounted) return null;
    final pin = await ModalAutorizacionNumpad.mostrar(
      context: context,
      tituloAccion: tituloAccion,
    );
    return pin == null ? null : (pin: pin);
  }
  if (!usuarios.any((u) => u.activo && u.autoriza)) return (pin: null);
  if (!context.mounted) return null;
  final pin = await ModalAutorizacionNumpad.mostrar(
    context: context,
    tituloAccion: tituloAccion,
  );
  return pin == null ? null : (pin: pin);
}

/// 6.6 Autorización con teclado (diseño de Pablo): bloquea la pantalla y
/// pide el PIN de un gerente o del dueño. Regresa el PIN ya verificado.
class ModalAutorizacionNumpad extends ConsumerStatefulWidget {
  const ModalAutorizacionNumpad({
    super.key,
    this.tituloAccion = 'Cancelar Venta',
  });

  final String tituloAccion;

  static Future<String?> mostrar({
    required BuildContext context,
    String tituloAccion = 'Cancelar Venta',
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => ModalAutorizacionNumpad(tituloAccion: tituloAccion),
  );

  @override
  ConsumerState<ModalAutorizacionNumpad> createState() =>
      _ModalAutorizacionNumpadState();
}

class _ModalAutorizacionNumpadState
    extends ConsumerState<ModalAutorizacionNumpad>
    with SingleTickerProviderStateMixin {
  static const _minimo = 4;
  static const _maximo = 6;

  String _pin = '';
  String? _mensajeError;
  bool _estaVerificando = false;

  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _shakeAnim = CurvedAnimation(
    parent: _shakeCtrl,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onTecla(String val) {
    if (_estaVerificando || _pin.length >= _maximo) return;
    setState(() {
      _mensajeError = null;
      _pin += val;
    });
  }

  void _onBorrar() {
    if (_estaVerificando || _pin.isEmpty) return;
    setState(() {
      _mensajeError = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verificarPin() async {
    setState(() => _estaVerificando = true);
    String? error;
    try {
      final api = await ref.read(apiProvider.future);
      final usuario = await api.verificarPin(_pin);
      if (usuario.autoriza) {
        if (mounted) Navigator.pop(context, _pin);
        return;
      }
      error =
          'PIN de cajero: sin permisos para ${widget.tituloAccion.toLowerCase()}.';
    } on FalloApi catch (e) {
      error = switch (e.codigo) {
        'pin_invalido' => 'PIN incorrecto. Acceso no autorizado.',
        _ => mensajeDeError(e),
      };
    }
    if (!mounted) return;
    _shakeCtrl.forward(from: 0.0);
    setState(() {
      _estaVerificando = false;
      _mensajeError = error;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final puedeVerificar = _pin.length >= _minimo && !_estaVerificando;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior con botón Cancelar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        Textos.cancelar,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'MODO SEGURIDAD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Caja central de autenticación
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                    decoration: BoxDecoration(
                      color: c.superficie,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.superficie2,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.linea),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 34,
                            color: c.tinta,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Autorización Requerida',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: c.tinta,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.tituloAccion}: requiere permisos de '
                          'Gerente o Dueño',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: rojoCancelacion,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Indicadores del PIN con animación de sacudida
                        AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (context, child) {
                            final desplazamiento =
                                math.sin(_shakeAnim.value * math.pi * 4) *
                                (1 - _shakeAnim.value) *
                                14;
                            return Transform.translate(
                              offset: Offset(desplazamiento, 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_maximo, (i) {
                              final lleno = i < _pin.length;
                              final tieneError = _mensajeError != null;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tieneError
                                      ? rojoCancelacion
                                      : (lleno ? c.azul : Colors.transparent),
                                  border: Border.all(
                                    color: tieneError
                                        ? rojoCancelacion
                                        : (lleno
                                              ? c.azul
                                              : c.tinta2.withValues(
                                                  alpha: i < _minimo
                                                      ? 0.4
                                                      : 0.2,
                                                )),
                                    width: 2,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _mensajeError ??
                              'Ingresa el PIN de un gerente o del dueño '
                                  '(4 a 6 dígitos)',
                          textAlign: TextAlign.center,
                          style: _mensajeError != null
                              ? const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: rojoCancelacion,
                                )
                              : TextStyle(fontSize: 12, color: c.tinta2),
                        ),
                        const SizedBox(height: 20),
                        TecladoNumerico(
                          alPresionarTecla: _onTecla,
                          alBorrar: _onBorrar,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: puedeVerificar ? _verificarPin : null,
                            icon: _estaVerificando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: const Text(
                              'Autorizar',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
