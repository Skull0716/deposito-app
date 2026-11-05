import 'package:flutter/material.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/textos.dart';
import '../../../../core/widgets/cargador_nexo.dart';

class InicializandoBD extends StatefulWidget {
  const InicializandoBD({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<InicializandoBD> createState() => _InicializandoBDState();
}

class _InicializandoBDState extends State<InicializandoBD> {
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    _simularCarga();
  }

  Future<void> _simularCarga() async {
    // Simula el tiempo que toma crear las tablas de SQLite
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() => _terminado = true);
      // Simula 1 segundo de mostrar el "Check" antes de avanzar
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        widget.alTerminar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Scaffold(
      backgroundColor: c.fondo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _terminado
                  ? Container(
                      key: const ValueKey('check'),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.verde.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: c.verde,
                        size: 32,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('spinner'),
                      width: 120,
                      height: 120,
                      child: Center(child: CargadorNexo(tamano: 40)),
                    ),
            ),
            const SizedBox(height: 32),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _terminado ? c.verde : c.tinta,
              ),
              child: Text(
                _terminado
                    ? Textos.baseDatosLista
                    : Textos.inicializandoBaseDatos,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
