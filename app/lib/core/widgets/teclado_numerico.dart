import 'package:flutter/material.dart';

import '../../app/tema/colores.dart';
import '../textos.dart';

class TecladoNumerico extends StatelessWidget {
  const TecladoNumerico({
    super.key,
    required this.alPresionarTecla,
    required this.alBorrar,
  });

  final ValueChanged<String> alPresionarTecla;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 1; i <= 9; i++)
          _Tecla(
            numero: i.toString(),
            alPresionar: alPresionarTecla,
            color: c.tinta,
          ),
        const SizedBox.shrink(),
        _Tecla(numero: '0', alPresionar: alPresionarTecla, color: c.tinta),
        _TeclaIcono(
          icono: Icons.backspace_outlined,
          etiqueta: Textos.borrar,
          alPresionar: alBorrar,
          color: c.tinta,
        ),
      ],
    );
  }
}

class _Tecla extends StatelessWidget {
  const _Tecla({
    required this.numero,
    required this.alPresionar,
    required this.color,
  });

  final String numero;
  final ValueChanged<String> alPresionar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => alPresionar(numero),
        child: Center(
          child: Text(
            numero,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeclaIcono extends StatelessWidget {
  const _TeclaIcono({
    required this.icono,
    required this.etiqueta,
    required this.alPresionar,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback alPresionar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: alPresionar,
          child: Center(
            child: Icon(icono, size: 28, color: color.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );
  }
}
