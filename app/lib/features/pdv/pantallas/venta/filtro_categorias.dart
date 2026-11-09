import 'package:flutter/material.dart';

import '../../../../app/tema/colores.dart';

class FiltroCategorias extends StatelessWidget {
  const FiltroCategorias({
    super.key,
    required this.texto,
    required this.activo,
    required this.alElegir,
  });

  final String texto;
  final bool activo;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ChoiceChip(
      label: Text(texto),
      selected: activo,
      onSelected: (_) => alElegir(),
      selectedColor: c.azul,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: activo ? Colors.white : c.tinta,
        fontWeight: activo ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: activo ? Colors.transparent : c.linea),
      ),
    );
  }
}
