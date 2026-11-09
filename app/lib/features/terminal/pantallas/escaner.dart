import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/tema/colores.dart';
import '../../../core/textos.dart';

/// Abre la cámara a pantalla completa y regresa el primer código leído
/// (código de barras o QR), o `null` si se cierra.
Future<String?> escanearCodigo(
  BuildContext context, {
  required String titulo,
  String? ayuda,
}) => Navigator.of(context, rootNavigator: true).push<String>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PantallaEscaner(titulo: titulo, ayuda: ayuda),
  ),
);

class PantallaEscaner extends StatefulWidget {
  const PantallaEscaner({super.key, required this.titulo, this.ayuda});

  final String titulo;
  final String? ayuda;

  @override
  State<PantallaEscaner> createState() => _PantallaEscanerState();
}

class _PantallaEscanerState extends State<PantallaEscaner> {
  final _control = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  var _listo = false;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _control,
            onDetect: (captura) {
              final valor = captura.barcodes.firstOrNull?.rawValue;
              if (_listo || valor == null || valor.isEmpty) return;
              _listo = true;
              Navigator.pop(context, valor);
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Permite el uso de la cámara en los ajustes del teléfono para escanear.'
                      : 'No se pudo abrir la cámara.',
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Marco de enfoque.
          Center(
            child: Container(
              width: 260,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: c.lager, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: Textos.cerrar,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.titulo,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
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
                  const Spacer(),
                  if (widget.ayuda != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.ayuda!,
                        style: const TextStyle(color: Colors.white),
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
