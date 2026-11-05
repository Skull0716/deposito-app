import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/pedido.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/tiempo_real/tiempo_real.dart';

/// Pedidos que las terminales mandaron y la caja todavía no atiende.
/// Se mantiene al día con `pedido.creado`, `pedido.atendido` y al
/// reconectarse (regla del contrato).
final pedidosPendientesProvider =
    AsyncNotifierProvider<PedidosPendientesNotifier, List<Pedido>>(
      PedidosPendientesNotifier.new,
      retry: (_, _) => null,
    );

class PedidosPendientesNotifier extends AsyncNotifier<List<Pedido>> {
  @override
  Future<List<Pedido>> build() async {
    final api = await ref.watch(apiProvider.future);
    ref.listen(eventosProvider, (_, siguiente) {
      final evento = siguiente.value;
      if (evento == null) return;
      switch (evento.tipo) {
        case TiposEvento.pedidoCreado:
        case TiposEvento.pedidoAtendido:
        case eventoReconectado:
          _refrescarSinParpadeo();
      }
    });
    return api.listarPedidos();
  }

  Future<void> refrescar() async {
    final api = await ref.read(apiProvider.future);
    state = await AsyncValue.guard(api.listarPedidos);
  }

  /// Marca el pedido como atendido y lo quita de la lista.
  Future<void> descartar(Pedido pedido) async {
    final api = await ref.read(apiProvider.future);
    await api.descartarPedido(pedido.id);
    state = AsyncData([
      for (final p in state.value ?? const <Pedido>[])
        if (p.id != pedido.id) p,
    ]);
  }

  Future<void> _refrescarSinParpadeo() async {
    final api = await ref.read(apiProvider.future);
    state = await AsyncValue.guard(api.listarPedidos);
  }
}
