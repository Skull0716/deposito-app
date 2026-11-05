import 'package:deposito_backend/deposito_backend.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/config/configuracion.dart';
import '../../../../core/servidor/servidor_embebido.dart';
import '../../../../core/widgets/campo_pin.dart';
import '../../../../core/widgets/cargador_nexo.dart';
import '../../../../core/widgets/estados.dart';
import '../../../../core/widgets/teclado_numerico.dart';
import '../../../core/textos.dart';

/// Restaurar la caja desde un respaldo (diseño de Pablo): se elige el
/// archivo, se confirma con el PIN del dueño de ESE respaldo y reemplaza la
/// base antes de que arranque el servidor.
class RestaurarRespaldo extends ConsumerStatefulWidget {
  const RestaurarRespaldo({super.key});

  @override
  ConsumerState<RestaurarRespaldo> createState() => _RestaurarRespaldoState();
}

class _RestaurarRespaldoState extends ConsumerState<RestaurarRespaldo> {
  String? _ruta;
  bool get _archivoSeleccionado => _ruta != null;
  bool _restaurando = false;
  String _pin = '';
  bool _errorPin = false;

  Future<void> _seleccionarArchivo() async {
    final PlatformFile? archivo;
    try {
      archivo = await FilePicker.pickFile(dialogTitle: 'Respaldo de Anaquel');
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo abrir el selector: $e');
      return;
    }
    final ruta = archivo?.path;
    if (ruta == null || !mounted) return;
    switch (verificarRespaldo(ruta)) {
      case EstadoRespaldo.noEsRespaldo:
        avisar(context, 'Ese archivo no es un respaldo de Anaquel');
      case EstadoRespaldo.valido:
        await _restaurar(ruta);
      case EstadoRespaldo.requierePin || EstadoRespaldo.pinIncorrecto:
        setState(() => _ruta = ruta);
    }
  }

  Future<void> _restaurar(String ruta) async {
    setState(() => _restaurando = true);
    try {
      restaurarRespaldo(ruta, rutaBaseDatosCaja(await carpetaCaja()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _restaurando = false);
      avisar(context, 'No se pudo restaurar: $e');
      return;
    }
    if (!mounted) return;
    // La caja arranca con la base restaurada.
    await ref
        .read(configuracionProvider.notifier)
        .elegirModo(ModoDispositivo.caja);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _teclear(String tecla) {
    if (_restaurando || _pin.length >= 6) return;
    setState(() {
      _pin += tecla;
      _errorPin = false;
    });
    if (_pin.length == 6) _validarPin();
  }

  void _borrar() {
    if (_restaurando || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorPin = false;
    });
  }

  void _validarPin() {
    if (verificarRespaldo(_ruta!, pin: _pin) == EstadoRespaldo.valido) {
      _restaurar(_ruta!);
    } else {
      setState(() => _errorPin = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _pin = '';
            _errorPin = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _restaurando
            ? null
            : TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text(
                  Textos.volver,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: c.azul,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
        leadingWidth: 100,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _restaurando
                ? _ConstruirEstadoRestaurando(c: c)
                : (!_archivoSeleccionado)
                ? _ConstruirPaso1(c: c, alSeleccionar: _seleccionarArchivo)
                : _ConstruirPaso2(
                    c: c,
                    pin: _pin,
                    errorPin: _errorPin,
                    alTeclear: _teclear,
                    alBorrar: _borrar,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConstruirPaso1 extends StatelessWidget {
  const _ConstruirPaso1({required this.c, required this.alSeleccionar});
  final ColoresAnaquel c;
  final VoidCallback alSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: c.azul.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.description_outlined, size: 48, color: c.azul),
          ),
          const SizedBox(height: 32),
          Text(
            'Selecciona tu archivo de respaldo .sqlite',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.tinta,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'El archivo será verificado antes de modificar este dispositivo.',
            style: TextStyle(fontSize: 16, color: c.tinta2, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: alSeleccionar,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.azul,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Explorar Archivos del iPad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstruirPaso2 extends StatelessWidget {
  const _ConstruirPaso2({
    required this.c,
    required this.pin,
    required this.errorPin,
    required this.alTeclear,
    required this.alBorrar,
  });
  final ColoresAnaquel c;
  final String pin;
  final bool errorPin;
  final void Function(String) alTeclear;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Verificar Respaldo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.tinta,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa el PIN Maestro del dueño de este respaldo',
                style: TextStyle(fontSize: 16, color: c.tinta2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              CampoPin(longitud: 6, valor: pin, conError: errorPin),
              const SizedBox(height: 24),
              if (errorPin)
                Text(
                  'PIN incorrecto',
                  style: TextStyle(
                    color: c.alerta,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        TecladoNumerico(alPresionarTecla: alTeclear, alBorrar: alBorrar),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ConstruirEstadoRestaurando extends StatelessWidget {
  const _ConstruirEstadoRestaurando({required this.c});
  final ColoresAnaquel c;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CargadorNexo(tamano: 40),
        const SizedBox(height: 48),
        Text(
          'Restaurando servidor...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: c.tinta,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Por favor no cierres la aplicación',
          style: TextStyle(fontSize: 16, color: c.tinta2),
        ),
      ],
    );
  }
}
