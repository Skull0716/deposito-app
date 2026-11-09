import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/textos.dart';

/// Resultado de un código leído: qué decirle a quien escanea.
typedef ResultadoEscaneo = ({bool agregado, String mensaje});

/// Escáner continuo (diseño de Pablo): la cámara se queda abierta y cada
/// código leído se agrega a la venta con un aviso verde, sin cerrar.
class EscanerContinuo extends StatefulWidget {
  const EscanerContinuo({super.key, required this.alEscanear});

  /// Agrega el producto del código y regresa el aviso a mostrar.
  final ResultadoEscaneo Function(String codigo) alEscanear;

  @override
  State<EscanerContinuo> createState() => _EscanerContinuoState();
}

class _EscanerContinuoState extends State<EscanerContinuo> {
  /// Entre dos lecturas del mismo código: así una lata frente a la cámara
  /// no se cobra varias veces.
  static const _pausaMismoCodigo = Duration(milliseconds: 1500);

  final _control = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  String? _ultimoCodigo;
  DateTime _ultimaLectura = DateTime.fromMillisecondsSinceEpoch(0);
  ResultadoEscaneo? _aviso;
  int _avisoId = 0;
  int _agregados = 0;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    final codigo = captura.barcodes.firstOrNull?.rawValue;
    if (codigo == null || codigo.isEmpty) return;
    // Solo para no repetir la lectura: no es lógica de negocio.
    final ahora = DateTime.now();
    if (codigo == _ultimoCodigo &&
        ahora.difference(_ultimaLectura) < _pausaMismoCodigo) {
      return;
    }
    _ultimoCodigo = codigo;
    _ultimaLectura = ahora;

    final r = widget.alEscanear(codigo);
    if (r.agregado) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.heavyImpact();
    }
    final id = ++_avisoId;
    setState(() {
      _aviso = r;
      if (r.agregado) _agregados++;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _avisoId == id) setState(() => _aviso = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _aviso;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _control,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Permite el uso de la cámara en los ajustes para escanear.'
                    : 'No se pudo abrir la cámara.',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Retícula central.
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Stack(
                children: [
                  Positioned(top: 0, left: 0, child: _Esquina(0)),
                  Positioned(top: 0, right: 0, child: _Esquina(1)),
                  Positioned(bottom: 0, right: 0, child: _Esquina(2)),
                  Positioned(bottom: 0, left: 0, child: _Esquina(3)),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'cerrar_escaner',
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        icon: const Icon(Icons.close_rounded),
                        label: Text(
                          _agregados == 0
                              ? Textos.cerrar
                              : 'Listo ($_agregados agregados)',
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _control.toggleTorch,
                        icon: const Icon(Icons.flashlight_on_rounded),
                        tooltip: 'Linterna',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Aviso flotante que no bloquea la cámara.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: aviso == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: ValueKey(_avisoId),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: aviso.agregado
                                  ? Colors.green[600]
                                  : Colors.amber[800],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  aviso.agregado
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    aviso.mensaje,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Apunta a los códigos uno tras otro: se agregan a la venta',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Esquina extends StatelessWidget {
  const _Esquina(this.indice);

  /// 0 arriba-izquierda, 1 arriba-derecha, 2 abajo-derecha, 3 abajo-izquierda.
  final int indice;

  @override
  Widget build(BuildContext context) {
    const borde = BorderSide(color: Colors.greenAccent, width: 4);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: indice <= 1 ? borde : BorderSide.none,
          bottom: indice >= 2 ? borde : BorderSide.none,
          left: indice == 0 || indice == 3 ? borde : BorderSide.none,
          right: indice == 1 || indice == 2 ? borde : BorderSide.none,
        ),
      ),
    );
  }
}
