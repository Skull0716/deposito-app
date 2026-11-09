import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/widgets/estados.dart';
import '../../../envases/datos/modelos_envases.dart';
import '../../../envases/pantallas/modal_recepcion_envases.dart';
import '../../estado/carrito.dart';
import 'cobro_efectivo.dart';
import 'cobro_tarjeta.dart';

// ============================================================================
// 4.2 SELECCIÓN DE MÉTODO DE PAGO
// ============================================================================
class MetodoPago extends ConsumerWidget {
  const MetodoPago({super.key});

  void _irA(BuildContext context, Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  /// "Saldo por Envases": el cliente entrega vacíos extra, su depósito se
  /// descuenta del ticket y el resto se paga en efectivo.
  Future<void> _saldoEnvases(BuildContext context, WidgetRef ref) async {
    final carrito = ref.read(carritoProvider);
    final r = await ModalRecepcionEnvases.mostrar(
      context,
      modo: ModoVacios.credito,
      cantidadInicial: carrito.totalRetornables > 0
          ? carrito.totalRetornables
          : 1,
      formatoInicial: carrito.retornables.isEmpty
          ? FormatoEnvase.media
          : FormatoEnvase.de(carrito.retornables.keys.first),
    );
    if (r == null || !context.mounted) return;
    final precios = ref.read(preciosEnvasesProvider);
    final saldo = r.cantidad * (precios[r.formato.clave] ?? 0);
    final total = carrito.total(precios);
    if (saldo > total) {
      avisar(
        context,
        'El saldo (${dinero(saldo)}) pasa del total (${dinero(total)}): '
        'usa "Devolver depósito" en Envases',
      );
      return;
    }
    ref
        .read(carritoProvider.notifier)
        .agregarCredito(r.formato.clave, r.cantidad);
    _irA(context, const CobroEfectivo());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final total = ref.watch(totalCarritoProvider);
    final esTablet = MediaQuery.sizeOf(context).width >= 700;

    final opciones = [
      (
        Icons.payments_outlined,
        'Efectivo',
        'Cobro con billetes y monedas físicas',
        () => _irA(context, const CobroEfectivo()),
      ),
      (
        Icons.point_of_sale_rounded,
        'Tarjeta',
        'Terminal bancaria física (Débito / Crédito)',
        () => _irA(context, const CobroTarjeta()),
      ),
      (
        Icons.liquor_outlined,
        'Saldo por Envases',
        'Descuento por botellas retornables recibidas',
        () => _saldoEnvases(context, ref),
      ),
    ];

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Selecciona el Método de Pago',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: c.tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca una opción para continuar la transacción',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: c.tinta2),
                  ),
                  const SizedBox(height: 48),
                  if (esTablet)
                    Row(
                      children: [
                        for (final (i, o) in opciones.indexed) ...[
                          if (i > 0) const SizedBox(width: 24),
                          Expanded(
                            child: _BotonMetodo(
                              icono: o.$1,
                              texto: o.$2,
                              c: c,
                              alTocar: o.$4,
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (final (i, o) in opciones.indexed) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _BotonMetodoMovil(
                            icono: o.$1,
                            texto: o.$2,
                            descripcion: o.$3,
                            c: c,
                            alTocar: o.$4,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado para iPad, con efecto de hundimiento (0.95).
class _BotonMetodo extends StatefulWidget {
  const _BotonMetodo({
    required this.icono,
    required this.texto,
    required this.c,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final ColoresAnaquel c;
  final VoidCallback alTocar;

  @override
  State<_BotonMetodo> createState() => _BotonMetodoState();
}

class _BotonMetodoState extends State<_BotonMetodo> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) {
        setState(() => _presionado = false);
        HapticFeedback.lightImpact();
        widget.alTocar();
      },
      onTapCancel: () => setState(() => _presionado = false),
      child: AnimatedScale(
        scale: _presionado ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: widget.c.superficie,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _presionado ? widget.c.azul : widget.c.linea,
                width: _presionado ? 2 : 1,
              ),
              boxShadow: _presionado
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icono, size: 72, color: widget.c.azul),
                const SizedBox(height: 20),
                Text(
                  widget.texto,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.c.tinta,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón ancho para el teléfono, con efecto de hundimiento (0.95).
class _BotonMetodoMovil extends StatefulWidget {
  const _BotonMetodoMovil({
    required this.icono,
    required this.texto,
    required this.descripcion,
    required this.c,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final String descripcion;
  final ColoresAnaquel c;
  final VoidCallback alTocar;

  @override
  State<_BotonMetodoMovil> createState() => _BotonMetodoMovilState();
}

class _BotonMetodoMovilState extends State<_BotonMetodoMovil> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) {
        setState(() => _presionado = false);
        HapticFeedback.lightImpact();
        widget.alTocar();
      },
      onTapCancel: () => setState(() => _presionado = false),
      child: AnimatedScale(
        scale: _presionado ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: widget.c.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _presionado ? widget.c.azul : widget.c.linea,
              width: _presionado ? 2 : 1,
            ),
            boxShadow: _presionado
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.c.azul.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icono, size: 34, color: widget.c.azul),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.texto,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.c.tinta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.descripcion,
                      style: TextStyle(fontSize: 13, color: widget.c.tinta2),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: widget.c.tinta2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
