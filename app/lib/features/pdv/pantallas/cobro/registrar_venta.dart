import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/fallo_api.dart';
import '../../../../core/api/proveedores.dart';
import '../../../../core/textos.dart';
import '../../../catalogo/estado/productos.dart';
import '../../../envases/estado/envases_provider.dart';
import '../../../personal/estado/personal_provider.dart';
import '../../estado/carrito.dart';
import 'venta_exitosa.dart';

/// Registra el carrito actual en el servidor y abre la pantalla de éxito.
///
/// Usa la clave de cobro del carrito: si la red falla y la persona reintenta,
/// el servidor regresa la misma venta en lugar de cobrar dos veces.
Future<void> registrarVenta(
  BuildContext context,
  WidgetRef ref, {
  required String metodo,
  int? recibido,
}) async {
  final carrito = ref.read(carritoProvider);
  final navegador = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final api = await ref.read(apiProvider.future);
    final venta = await api.registrarVenta(
      lineas: carrito.lineas,
      metodo: metodo,
      recibido: recibido,
      envModo: carrito.envModo.name,
      envCliente: carrito.envCliente,
      envCredito: carrito.credito,
      usuarioId: ref.read(usuarioActualProvider)?.id,
      claveIdempotencia: carrito.claveCobro,
    );
    ref.read(carritoProvider.notifier).vaciar();
    ref.read(productosProvider.notifier).refrescar();
    if (carrito.envModo != ModoEnvases.na || carrito.credito.isNotEmpty) {
      ref.read(envasesProvider.notifier).refrescar();
    }
    navegador.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => VentaExitosa(venta: venta)),
      (ruta) => ruta.isFirst,
    );
  } catch (e) {
    navegador.pop();
    if (!context.mounted) return;
    final sinConexion = e is FalloApi && e.sinConexion;
    final reintentar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('No se registró el cobro'),
        content: Text(
          sinConexion
              ? '${mensajeDeError(e)}\n\nSi reintentas no se cobra dos veces.'
              : mensajeDeError(e),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text(Textos.cerrar),
          ),
          if (sinConexion)
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text(Textos.reintentar),
            ),
        ],
      ),
    );
    if (reintentar == true && context.mounted) {
      await registrarVenta(context, ref, metodo: metodo, recibido: recibido);
    }
  }
}
