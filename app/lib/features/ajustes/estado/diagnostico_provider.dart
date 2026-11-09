import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/proveedores.dart';

/// Estado del servidor embebido para soporte (`GET /api/v1/diagnostico`).
/// Solo tiene sentido en la caja.
final diagnosticoProvider =
    AsyncNotifierProvider<DiagnosticoNotifier, Diagnostico>(
      DiagnosticoNotifier.new,
      retry: (_, _) => null,
    );

class DiagnosticoNotifier extends AsyncNotifier<Diagnostico> {
  @override
  Future<Diagnostico> build() async {
    final api = await ref.watch(apiProvider.future);
    return api.obtenerDiagnostico();
  }

  /// Vuelve a pedir el estado sin dejar la pantalla en blanco.
  Future<void> refrescar() async {
    final api = await ref.read(apiProvider.future);
    state = await AsyncValue.guard(api.obtenerDiagnostico);
  }
}
