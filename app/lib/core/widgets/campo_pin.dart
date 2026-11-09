import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tema/colores.dart';
import '../textos.dart';

class CampoPin extends StatelessWidget {
  const CampoPin({
    super.key,
    required this.longitud,
    required this.valor,
    this.conError = false,
  });

  final int longitud;
  final String valor;
  final bool conError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${Textos.pin}: ${valor.length} de $longitud',
      excludeSemantics: true,
      child: _ShakeWidget(
        shaking: conError,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(longitud, (index) {
            final lleno = index < valor.length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _CirculoPin(lleno: lleno, conError: conError),
            );
          }),
        ),
      ),
    );
  }
}

class _CirculoPin extends StatelessWidget {
  const _CirculoPin({required this.lleno, required this.conError});

  final bool lleno;
  final bool conError;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    final colorLleno = conError ? c.alerta : c.azul;
    final colorVacio = conError ? c.alerta.withValues(alpha: 0.3) : c.linea;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lleno ? colorLleno : Colors.transparent,
        border: Border.all(color: lleno ? colorLleno : colorVacio, width: 2),
      ),
    );
  }
}

class _ShakeWidget extends StatefulWidget {
  const _ShakeWidget({required this.child, required this.shaking});

  final Widget child;
  final bool shaking;

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant _ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shaking && !oldWidget.shaking) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sine = math.sin(_controller.value * 4 * math.pi);
        // Desvanecer la vibración hacia el final
        final fade = 1.0 - _controller.value;
        final dx = sine * 8 * fade;

        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
