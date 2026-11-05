import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/textos.dart';
import '../../estado/carrito.dart';
import 'comun.dart';
import 'registrar_venta.dart';

// ============================================================================
// 4.5 COBRO CON TARJETA Y 4.6 TRANSACCIÓN RECHAZADA
// ============================================================================
/// El cobro se hace en la terminal bancaria; aquí se confirma lo que
/// respondió para registrar la venta.
class CobroTarjeta extends ConsumerStatefulWidget {
  const CobroTarjeta({super.key});

  @override
  ConsumerState<CobroTarjeta> createState() => _CobroTarjetaState();
}

class _CobroTarjetaState extends ConsumerState<CobroTarjeta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  bool _mostrarRechazo = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _aprobado() {
    HapticFeedback.mediumImpact();
    registrarVenta(context, ref, metodo: 'tarjeta');
  }

  void _rechazado() {
    // Vibración fuerte de doble pulso.
    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 180),
      HapticFeedback.heavyImpact,
    );
    setState(() => _mostrarRechazo = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final total = ref.watch(totalCarritoProvider);

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: c.tinta),
        title: Text(
          'Total a Cobrar: ${dinero(total)}',
          style: TextStyle(
            color: c.tinta,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 4.5 Espera con animación continua.
          SafeArea(
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
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (context, child) => SizedBox(
                          width: 210,
                          height: 210,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 180 + (_ctrl.value * 30),
                                height: 180 + (_ctrl.value * 30),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.azul.withValues(
                                    alpha: 0.08 * (1 - _ctrl.value),
                                  ),
                                ),
                              ),
                              child!,
                            ],
                          ),
                        ),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.azul.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            Icons.contactless_outlined,
                            size: 76,
                            color: c.azul,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Siga las instrucciones en la terminal física',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: c.tinta,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Inserte, deslice o acerque la tarjeta al lector',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: c.tinta2),
                      ),
                      const SizedBox(height: 40),

                      // Lo que respondió la terminal bancaria.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.superficie,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.linea),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _aprobado,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Pago aprobado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: verdeExito,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _rechazado,
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: rojoRechazo,
                              ),
                              label: const Text(
                                'Pago rechazado',
                                style: TextStyle(color: rojoRechazo),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: rojoRechazo),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar pago con tarjeta',
                          style: TextStyle(
                            color: c.tinta2,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4.6 Transacción rechazada.
          if (_mostrarRechazo)
            Container(
              color: Colors.black.withValues(alpha: 0.65),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: c.superficie,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: rojoRechazo.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 52,
                          color: rojoRechazo,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Transacción Declinada',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: c.tinta,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'La tarjeta fue rechazada por el banco emisor. '
                        'Verifique fondos o intente con otra tarjeta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: c.tinta2),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _mostrarRechazo = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rojoRechazo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            Textos.reintentar,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: c.linea),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Cambiar método de pago',
                            style: TextStyle(fontSize: 16, color: c.tinta),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
