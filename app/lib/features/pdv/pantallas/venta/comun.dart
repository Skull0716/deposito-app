import '../../estado/carrito.dart';

String nombreItem(ItemCarrito i) =>
    i.porCaja ? '${i.producto.nombre} (caja)' : i.producto.nombre;
