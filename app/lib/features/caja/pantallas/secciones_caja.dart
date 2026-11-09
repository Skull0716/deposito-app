import 'package:flutter/material.dart';

import '../../ajustes/ajustes.dart';
import '../../alertas/pantallas/pantalla_alertas.dart';
import '../../catalogo/pantallas/pantalla_catalogo.dart';
import '../../envases/pantallas/dashboard_envases.dart';
import '../../pdv/pantallas/punto_venta.dart';
import '../../proximamente/proximamente.dart';
import '../../ventas/pantallas/lista_transacciones.dart';
import 'inicio_caja.dart';
import 'seccion_corte.dart';

/// Secciones de la caja, en el orden del menú. Las que no están construidas
/// muestran en qué sprint llegan y quién las hace (docs/PLAN_DE_TRABAJO.md).
class SeccionCaja {
  const SeccionCaja(
    this.ruta,
    this.titulo,
    this.icono,
    this.iconoActivo,
    this.construir,
  );

  final String ruta;
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  final Widget Function() construir;
}

final seccionesCaja = <SeccionCaja>[
  SeccionCaja(
    'inicio',
    'Inicio',
    Icons.space_dashboard_outlined,
    Icons.space_dashboard_rounded,
    InicioCaja.new,
  ),
  SeccionCaja(
    'vender',
    'Vender',
    Icons.point_of_sale_outlined,
    Icons.point_of_sale_rounded,
    PuntoVenta.new,
  ),
  SeccionCaja(
    'ventas',
    'Ventas',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
    ListaTransacciones.new,
  ),
  SeccionCaja(
    'catalogo',
    'Catálogo',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
    PantallaCatalogo.new,
  ),
  SeccionCaja(
    'envases',
    'Envases',
    Icons.recycling_outlined,
    Icons.recycling_rounded,
    DashboardEnvases.new,
  ),
  SeccionCaja(
    'corte',
    'Corte de caja',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded,
    SeccionCorte.new,
  ),
  SeccionCaja(
    'alertas',
    'Alertas',
    Icons.notifications_active_outlined,
    Icons.notifications_active_rounded,
    PantallaAlertas.new,
  ),
  SeccionCaja(
    'resurtido',
    'Resurtido',
    Icons.local_shipping_outlined,
    Icons.local_shipping_rounded,
    () => const Proximamente(
      icono: Icons.local_shipping_outlined,
      titulo: 'Resurtido',
      descripcion: 'Cuánto comprar según lo vendido, con pedido al proveedor por WhatsApp.',
      sprint: 4,
      responsable: 'Luis',
    ),
  ),
  SeccionCaja(
    'ajustes',
    'Ajustes',
    Icons.tune_outlined,
    Icons.tune_rounded,
    PantallaAjustes.new,
  ),
];

SeccionCaja seccionCaja(String ruta) => seccionesCaja.firstWhere(
  (s) => s.ruta == ruta,
  orElse: () => seccionesCaja.first,
);
