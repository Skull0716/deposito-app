import 'package:flutter/material.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/widgets/campo_pin.dart';
import '../../../../core/widgets/teclado_numerico.dart';
import '../../../core/textos.dart';

class CrearCuentaMaestra extends StatefulWidget {
  const CrearCuentaMaestra({super.key, required this.alCompletar});

  /// Nombre del negocio, nombre del dueño y su PIN de 6 dígitos.
  final void Function(String negocio, String nombre, String pin) alCompletar;

  @override
  State<CrearCuentaMaestra> createState() => _CrearCuentaMaestraState();
}

class _CrearCuentaMaestraState extends State<CrearCuentaMaestra> {
  final _negocioCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();

  String _pin = '';
  String _pinConfirmacion = '';
  bool _confirmando = false;
  bool _errorPin = false;

  @override
  void dispose() {
    _negocioCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _teclear(String tecla) {
    if (!_confirmando) {
      if (_pin.length < 6) {
        setState(() {
          _pin += tecla;
          _errorPin = false;
        });
      }
    } else {
      if (_pinConfirmacion.length < 6) {
        setState(() {
          _pinConfirmacion += tecla;
          _errorPin = false;
        });
      }
    }
  }

  void _borrar() {
    if (!_confirmando) {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _errorPin = false;
        });
      }
    } else {
      if (_pinConfirmacion.isNotEmpty) {
        setState(() {
          _pinConfirmacion = _pinConfirmacion.substring(
            0,
            _pinConfirmacion.length - 1,
          );
          _errorPin = false;
        });
      }
    }
  }

  void _continuar() {
    if (_negocioCtrl.text.trim().isEmpty || _nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos de texto'),
        ),
      );
      return;
    }

    if (!_confirmando) {
      if (_pin.length == 6) {
        setState(() {
          _confirmando = true;
          _errorPin = false;
        });
      }
    } else {
      if (_pinConfirmacion.length == 6) {
        if (_pin == _pinConfirmacion) {
          widget.alCompletar(
            _negocioCtrl.text.trim(),
            _nombreCtrl.text.trim(),
            _pin,
          );
        } else {
          // Error, no coinciden
          setState(() {
            _errorPin = true;
          });
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              setState(() {
                _confirmando = false;
                _pin = '';
                _pinConfirmacion = '';
                _errorPin = false;
              });
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final pinActual = _confirmando ? _pinConfirmacion : _pin;
    final puedeContinuar = pinActual.length == 6;

    return Scaffold(
      backgroundColor: c.fondo,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          if (_confirmando) {
                            setState(() {
                              _confirmando = false;
                              _pinConfirmacion = '';
                              _errorPin = false;
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          Textos.volver,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: c.azul,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'CUENTA MAESTRA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.azul,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea el acceso del propietario',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: c.tinta,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Estos datos identificarán al negocio y protegerán las funciones administrativas.',
                        style: TextStyle(
                          fontSize: 15,
                          color: c.tinta2,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Campos de Texto solo si no estamos confirmando
                      if (!_confirmando) ...[
                        Text(
                          'Nombre del Negocio',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.tinta,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _negocioCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ej. Café Central',
                            hintStyle: TextStyle(
                              color: c.tinta2.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: c.fondo,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: c.linea),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: c.linea),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Nombre del Dueño',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.tinta,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nombreCtrl,
                          decoration: InputDecoration(
                            hintText: 'Nombre completo',
                            hintStyle: TextStyle(
                              color: c.tinta2.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: c.fondo,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: c.linea),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: c.linea),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ] else ...[
                        const SizedBox(height: 32),
                      ],

                      Text(
                        _confirmando
                            ? 'Confirma tu PIN Maestro'
                            : 'Crea un PIN Maestro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: c.tinta,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _confirmando
                            ? 'Vuelve a escribir el PIN para confirmar.'
                            : 'Usa seis dígitos que puedas recordar.',
                        style: TextStyle(fontSize: 14, color: c.tinta2),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      CampoPin(
                        longitud: 6,
                        valor: pinActual,
                        conError: _errorPin,
                      ),

                      const SizedBox(height: 32),

                      TecladoNumerico(
                        alPresionarTecla: _teclear,
                        alBorrar: _borrar,
                      ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: puedeContinuar ? _continuar : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.azul,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: c.linea,
                          disabledForegroundColor: c.tinta2,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _confirmando ? 'Confirmar PIN' : Textos.continuar,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
