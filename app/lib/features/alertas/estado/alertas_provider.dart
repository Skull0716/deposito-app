import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/proveedores.dart';
import '../../../core/tiempo_real/tiempo_real.dart';

/// Alertas del día tal como las manda `GET /api/v1/alertas`.
typedef AlertasDelDia = ({String dia, int dias, List<Alerta> alertas});

/// Días hacia adelante que se revisan las caducidades. La pantalla lo cambia
/// entre 7, 15 y 30; el contrato acepta de 1 a 365.
final diasAlertasProvider = NotifierProvider<DiasAlertasNotifier, int>(
  DiasAlertasNotifier.new,
);

class DiasAlertasNotifier extends Notifier<int> {
  @override
  int build() => diasAlertaCaducidad;

  void cambiar(int dias) => state = dias;
}

/// Alertas calculadas por el servidor, al día con el WebSocket:
/// se vuelven a pedir al recibir `alerta.nueva`, `producto.actualizado`,
/// `producto.eliminado` y al reconectarse (regla del contrato).
final alertasProvider = AsyncNotifierProvider<AlertasNotifier, AlertasDelDia>(
  AlertasNotifier.new,
  retry: (_, _) => null,
);

class AlertasNotifier extends AsyncNotifier<AlertasDelDia> {
  @override
  Future<AlertasDelDia> build() async {
    final api = await ref.watch(apiProvider.future);
    final dias = ref.watch(diasAlertasProvider);
    ref.listen(eventosProvider, (_, siguiente) {
      final evento = siguiente.value;
      if (evento == null) return;
      switch (evento.tipo) {
        case TiposEvento.alertaNueva:
        case TiposEvento.productoActualizado:
        case TiposEvento.productoEliminado:
        case eventoReconectado:
          _refrescarSinParpadeo();
      }
    });
    return api.listarAlertas(dias: dias);
  }

  /// Vuelve a pedir la lista (jalar para refrescar).
  Future<void> refrescar() async {
    final api = await ref.read(apiProvider.future);
    final dias = ref.read(diasAlertasProvider);
    state = await AsyncValue.guard(() => api.listarAlertas(dias: dias));
  }

  /// Refresco por WebSocket: no pasa por "cargando" para no borrar la lista
  /// que la persona está viendo.
  Future<void> _refrescarSinParpadeo() async {
    final api = await ref.read(apiProvider.future);
    final dias = ref.read(diasAlertasProvider);
    state = await AsyncValue.guard(() => api.listarAlertas(dias: dias));
  }
}
