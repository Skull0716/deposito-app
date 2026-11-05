import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/widgets/teclado_numerico.dart';
import '../../estado/carrito.dart';
import 'comun.dart';
import 'registrar_venta.dart';

// ============================================================================
// 4.3 COBRO EN EFECTIVO
// ============================================================================
class CobroEfectivo extends ConsumerStatefulWidget {
  const CobroEfectivo({super.key});

  @override
  ConsumerState<CobroEfectivo> createState() => _CobroEfectivoState();
}

class _CobroEfectivoState extends ConsumerState<CobroEfectivo> {
  /// Centavos que entregó el cliente. Con el teclado se escriben pesos
  /// enteros; "Monto Exacto" puede traer centavos.
  int _recibido = 0;

  void _teclear(String tecla) {
    final pesos = _recibido ~/ 100;
    if (pesos >= 1000000) return;
    setState(() => _recibido = (pesos * 10 + int.parse(tecla)) * 100);
  }

  void _borrar() => setState(() => _recibido = (_recibido ~/ 100) ~/ 10 * 100);

  void _ponerMonto(int monto) => setState(() => _recibido = monto);

  Future<void> _cobrar(int total) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ModalCambio(recibido: _recibido, cambio: _recibido - total),
    );
    if (confirmar == true && mounted) {
      await registrarVenta(
        context,
        ref,
        metodo: 'efectivo',
        recibido: _recibido,
      );
    }
  }

  /// Billetes inteligentes: exacto, siguiente múltiplo de $50 y de $100 y
  /// billetes comunes por encima del total. Centavos.
  static List<int> _billetesSugeridos(int total) {
    final res = <int>[total];
    void agregar(int monto) {
      if (monto > total && !res.contains(monto)) res.add(monto);
    }

    agregar((total + 4999) ~/ 5000 * 5000);
    agregar((total + 9999) ~/ 10000 * 10000);
    for (final b in [20000, 50000, 100000]) {
      agregar(b);
    }
    return res.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final total = ref.watch(totalCarritoProvider);
    final puedeCobrar = _recibido >= total && !ref.watch(carritoProvider).vacio;
    final esTablet = MediaQuery.sizeOf(context).width >= 700;
    final rapidos = _billetesSugeridos(total);

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: c.superficie,
        elevation: 0,
        leading: BackButton(color: c.tinta),
        title: Text(
          'Cobro en Efectivo',
          style: TextStyle(
            color: c.tinta,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: c.linea, height: 1),
        ),
      ),
      body: SafeArea(
        child: esTablet
            // Dos columnas en el iPad: teclado a la izquierda, billetes y
            // cobrar a la derecha.
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (context, medidas) => SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: medidas.maxHeight - 64,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Total a Pagar',
                                style: TextStyle(fontSize: 16, color: c.tinta2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dinero(total),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: c.tinta,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _displayRecibido(c, puedeCobrar),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: 360,
                                child: TecladoNumerico(
                                  alPresionarTecla: _teclear,
                                  alBorrar: _borrar,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: c.superficie,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Botones Inteligentes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: c.tinta,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: [
                                for (final monto in rapidos)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: OutlinedButton(
                                      onPressed: () => _ponerMonto(monto),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        side: BorderSide(
                                          color: c.azul.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        monto == total
                                            ? 'Monto Exacto (${dinero(monto)})'
                                            : 'Entregar ${dinero(monto)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: c.azul,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _botonCobrar(c, total, puedeCobrar),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            // Teléfono: todo en una columna con billetes en chips.
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total a Pagar:',
                          style: TextStyle(fontSize: 16, color: c.tinta2),
                        ),
                        Text(
                          dinero(total),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: c.azul,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _displayRecibido(c, puedeCobrar),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final monto in rapidos)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(
                                  monto == total
                                      ? 'Exacto (${dinero(monto)})'
                                      : dinero(monto),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: c.azul,
                                  ),
                                ),
                                backgroundColor: c.azul.withValues(alpha: 0.1),
                                side: BorderSide(
                                  color: c.azul.withValues(alpha: 0.3),
                                ),
                                onPressed: () => _ponerMonto(monto),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TecladoNumerico(
                        alPresionarTecla: _teclear,
                        alBorrar: _borrar,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _botonCobrar(c, total, puedeCobrar),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _displayRecibido(ColoresAnaquel c, bool puedeCobrar) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      color: c.superficie,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: puedeCobrar ? verdeExito : c.linea,
        width: puedeCobrar ? 2 : 1,
      ),
    ),
    child: Column(
      children: [
        Text(
          'Dinero Recibido',
          style: TextStyle(fontSize: 14, color: c.tinta2),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            dinero(_recibido),
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: puedeCobrar ? verdeExito : c.tinta,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );

  Widget _botonCobrar(ColoresAnaquel c, int total, bool puedeCobrar) =>
      SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: puedeCobrar ? () => _cobrar(total) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: verdeExito,
            foregroundColor: Colors.white,
            disabledBackgroundColor: c.linea,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: FittedBox(
            child: Text(
              puedeCobrar
                  ? 'Cobrar (${dinero(_recibido)})'
                  : 'Faltan ${dinero(total - _recibido)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
}

// ============================================================================
// 4.4 MODAL DE CAMBIO A ENTREGAR
// ============================================================================
/// Muestra el cambio a entregar a pantalla completa. Regresa `true` al
/// cerrar la venta y `false` para corregir el monto.
class ModalCambio extends StatelessWidget {
  const ModalCambio({super.key, required this.recibido, required this.cambio});

  /// Centavos.
  final int recibido;
  final int cambio;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pago recibido: ${dinero(recibido)}',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  'CAMBIO',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.greenAccent[400],
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    dinero(cambio),
                    style: const TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cerrar Venta',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Corregir monto',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
