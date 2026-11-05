import 'package:flutter/material.dart';

import '../../../../app/tema/colores.dart';
import '../../../core/textos.dart';

class BottomSheetGestionAccesos extends StatelessWidget {
  const BottomSheetGestionAccesos({
    super.key,
    required this.nombre,
    required this.rol,
    required this.alSuspender,
    required this.alVerVentas,
    required this.alCambiarPin,
    this.activo = true,
  });

  final String nombre;
  final String rol;
  final bool activo;
  final VoidCallback alSuspender;
  final VoidCallback alVerVentas;
  final VoidCallback alCambiarPin;

  void _confirmarSuspension(BuildContext context) {
    final c = context.colores;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Estás seguro?',
          style: TextStyle(color: c.tinta, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de revocar el acceso a este usuario?',
          style: TextStyle(color: c.tinta2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Textos.cancelar, style: TextStyle(color: c.tinta2)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra alerta
              alSuspender();
            },
            child: Text(
              'Suspender',
              style: TextStyle(color: c.alerta, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Container(
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de arrastre (Handle)
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Cabecera
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gestionar acceso',
                  style: TextStyle(fontSize: 13, color: c.tinta2),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.tinta,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Opción 1: Ver Ventas
              _OpcionBottomSheet(
                icono: Icons.bar_chart_rounded,
                texto: 'Ver Ventas del Empleado',
                alPresionar: alVerVentas,
              ),
              const SizedBox(height: 16),

              // Opción 2: Cambiar PIN
              _OpcionBottomSheet(
                icono: Icons.vpn_key_outlined,
                texto: 'Cambiar PIN',
                alPresionar: alCambiarPin,
              ),
              const SizedBox(height: 16),

              // Opción 3 Destructiva
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: activo
                      ? () => _confirmarSuspension(context)
                      : alSuspender,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.alerta.withValues(alpha: 0.05),
                    foregroundColor: c.alerta,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: c.alerta.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Text(
                    activo
                        ? 'Suspender Acceso / Dar de Baja'
                        : 'Reactivar Acceso',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: c.tinta2),
                  child: const Text(
                    Textos.cancelar,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionBottomSheet extends StatelessWidget {
  const _OpcionBottomSheet({
    required this.icono,
    required this.texto,
    required this.alPresionar,
  });

  final IconData icono;
  final String texto;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: c.linea),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.azul.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: c.azul, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.tinta,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
