import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../textos.dart';
import '../tiempo_real/tiempo_real.dart';

/// Punto verde "en línea" / ámbar "conectando" / gris "sin conexión".
///
/// Se ve siempre en la terminal y en la caja: si la Wi-Fi falla, el
/// personal lo nota antes de cobrar (plan, riesgo "Wi-Fi inestable").
class IndicadorConexion extends ConsumerWidget {
  const IndicadorConexion({
    super.key,
    this.colorTexto,
    this.etiquetaEnLinea = Textos.enLinea,
  });

  final Color? colorTexto;
  final String etiquetaEnLinea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado =
        ref.watch(estadoConexionProvider).value ?? EstadoConexion.conectando;
    final (color, texto) = switch (estado) {
      EstadoConexion.enLinea => (const Color(0xFF46C281), etiquetaEnLinea),
      EstadoConexion.conectando => (const Color(0xFFF4B324), Textos.conectando),
      EstadoConexion.sinConexion => (
        const Color(0xFF9A8B7A),
        Textos.sinConexionReintentando,
      ),
    };
    return Semantics(
      label: Textos.conexion(texto),
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
