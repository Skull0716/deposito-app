import 'package:flutter/material.dart';

import '../../estado/carrito.dart';

const verdeExito = Color(0xFF10B981);
const rojoRechazo = Color(0xFFEF4444);

String nombreItem(ItemCarrito i) =>
    '${i.producto.nombre}${i.porCaja ? ' (Caja)' : ''}'
    '${i.descuento > 0 ? ' −${i.descuento}%' : ''}';
