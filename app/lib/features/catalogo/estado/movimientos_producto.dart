import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/proveedores.dart';

/// Últimos movimientos de existencias de un producto
/// (`GET /api/v1/productos/{id}/movimientos`).
final movimientosProductoProvider =
    FutureProvider.family<List<Movimiento>, String>((ref, id) async {
      final api = await ref.watch(apiProvider.future);
      return api.listarMovimientos(id);
    });
