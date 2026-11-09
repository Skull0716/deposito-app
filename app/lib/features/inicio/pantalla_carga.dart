import 'package:flutter/material.dart';

import '../../app/tema/colores.dart';
import '../../core/textos.dart';
import '../../core/widgets/cargador_nexo.dart';
import '../../core/widgets/marca.dart';

/// Pantalla de Carga (Splash Screen) inicial de Nexo POS.
class PantallaCarga extends StatelessWidget {
  const PantallaCarga({
    super.key,
    this.mensaje = Textos.preparandoEspacio,
    this.version = 'v 1.0.0',
  });

  final String mensaje;
  final String version;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Scaffold(
      backgroundColor: c.fondo,
      body: Stack(
        children: [
          // Fondo con trazos curvados sutiles en las esquinas
          Positioned.fill(
            child: CustomPaint(
              painter: _FondoAccentosCurvosPainter(
                colorAccento: c.azul.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Contenido centralizado
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  // LogoNexPOS
                  const LogoNexo(tamanoBase: 44, mostrarSubtitulo: true),
                  const SizedBox(height: 64),
                  // Loader animado fluido metaball
                  const CargadorNexo(tamano: 64),
                  const Spacer(flex: 3),
                  // Mensaje inferior y versión
                  Text(
                    mensaje,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.tinta2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    version,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: c.tinta2,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibujador de líneas curvadas sutiles en las esquinas superior derecha e inferior izquierda.
class _FondoAccentosCurvosPainter extends CustomPainter {
  _FondoAccentosCurvosPainter({required this.colorAccento});

  final Color colorAccento;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorAccento
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;

    // Curva superior derecha
    final pathArriba = Path()
      ..moveTo(size.width * 0.55, 0)
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.08,
        size.width,
        size.height * 0.16,
      );

    // Curva inferior izquierda
    final pathAbajo = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.15,
        size.height * 0.94,
        size.width * 0.45,
        size.height,
      );

    canvas.drawPath(pathArriba, paint);
    canvas.drawPath(pathAbajo, paint);
  }

  @override
  bool shouldRepaint(_FondoAccentosCurvosPainter oldDelegate) {
    return oldDelegate.colorAccento != colorAccento;
  }
}
