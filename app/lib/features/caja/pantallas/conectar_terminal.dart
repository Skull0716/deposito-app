import 'dart:async';
import 'dart:convert';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/servidor/servidor_embebido.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../estado/terminales.dart';

Future<void> mostrarConectarTerminal(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const ConectarTerminal(),
);

/// QR de emparejamiento (docs/API.md, Terminales): IP, puerto y un código de
/// 6 dígitos que vence en 10 minutos y sirve para una sola terminal.
class ConectarTerminal extends ConsumerStatefulWidget {
  const ConectarTerminal({super.key});

  @override
  ConsumerState<ConectarTerminal> createState() => _ConectarTerminalState();
}

class _ConectarTerminalState extends ConsumerState<ConectarTerminal> {
  CodigoEmparejamiento? _codigo;
  Object? _error;
  Timer? _reloj;
  Timer? _sondeo;
  var _restante = Duration.zero;
  var _terminalesAlAbrir = -1;

  @override
  void initState() {
    super.initState();
    _generar();
    // Mientras el diálogo está abierto se revisa seguido si ya se vinculó una.
    _sondeo = Timer.periodic(
      const Duration(seconds: 2),
      (_) => ref.invalidate(terminalesProvider),
    );
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _sondeo?.cancel();
    super.dispose();
  }

  Future<void> _generar() async {
    setState(() {
      _codigo = null;
      _error = null;
    });
    try {
      final api = await ref.read(apiProvider.future);
      final codigo = await api.crearCodigoEmparejamiento();
      if (!mounted) return;
      setState(() => _codigo = codigo);
      _reloj?.cancel();
      _actualizarRestante();
      _reloj = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _actualizarRestante(),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _actualizarRestante() {
    final codigo = _codigo;
    if (codigo == null) return;
    final r = DateTime.parse(codigo.expira).difference(DateTime.now());
    setState(() => _restante = r.isNegative ? Duration.zero : r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final ip = ref.watch(direccionLocalProvider).value;
    final terminales = ref.watch(terminalesProvider);

    // Si aparece una terminal nueva mientras está abierto, el código ya se usó.
    final total = terminales.value?.length;
    if (total != null) {
      if (_terminalesAlAbrir < 0) {
        _terminalesAlAbrir = total;
      } else if (total > _terminalesAlAbrir) {
        _terminalesAlAbrir = total;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          avisar(
            context,
            '${terminales.value!.last.nombre} se conectó a la caja',
          );
          _generar();
        });
      }
    }

    final vencido = _codigo != null && _restante == Duration.zero;
    final qr = _codigo == null || ip == null
        ? null
        : jsonEncode({
            'v': 1,
            'host': ip,
            'puerto': puertoServidor,
            'codigo': _codigo!.codigo,
          });

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vincular una terminal',
                      style: textos.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: Textos.cerrar,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'En el teléfono abre Anaquel, elige Terminal y escanea este código. Los dos deben estar en la misma Wi-Fi.',
                style: textos.bodyMedium?.copyWith(color: c.tinta2),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 28,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.linea),
                    ),
                    child: switch ((qr, _error)) {
                      (_, final Object e) => Center(
                        child: Text(
                          mensajeDeError(e),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      (null, _) when ip == null && _codigo != null =>
                        const Center(
                          child: Text(
                            'Conecta el iPad a la Wi-Fi del local',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      (null, _) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      (final String datos, _) => Opacity(
                        opacity: vencido ? 0.15 : 1,
                        child: QrImageView(
                          data: datos,
                          padding: EdgeInsets.zero,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF1B2226),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1B2226),
                          ),
                        ),
                      ),
                    },
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('O escríbelo a mano', style: textos.bodySmall),
                        const SizedBox(height: 6),
                        Text(
                          _codigo == null
                              ? '··· ···'
                              : '${_codigo!.codigo.substring(0, 3)} ${_codigo!.codigo.substring(3)}',
                          style: textos.displayLarge?.copyWith(
                            letterSpacing: 4,
                            color: vencido ? c.tinta2 : c.tinta,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ip == null
                              ? 'Sin Wi-Fi'
                              : 'Caja: $ip · puerto $puertoServidor',
                          style: textos.titleSmall?.copyWith(color: c.tinta2),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              vencido
                                  ? Icons.timer_off_outlined
                                  : Icons.timer_outlined,
                              size: 18,
                              color: vencido ? c.alerta : c.tinta2,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              vencido
                                  ? 'El código venció'
                                  : 'Vence en ${_restante.inMinutes}:${(_restante.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: vencido ? c.alerta : c.tinta2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: _generar,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('Generar otro'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text('Terminales vinculadas', style: textos.titleLarge),
              const SizedBox(height: 8),
              switch (terminales) {
                AsyncData(:final value) when value.isEmpty => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Todavía no hay terminales.',
                    style: TextStyle(color: c.tinta2),
                  ),
                ),
                AsyncData(:final value) => Column(
                  children: [for (final t in value) _FilaTerminal(terminal: t)],
                ),
                AsyncError(:final error) => Text(
                  mensajeDeError(error),
                  style: TextStyle(color: c.alerta),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaTerminal extends ConsumerWidget {
  const _FilaTerminal({required this.terminal});

  final Terminal terminal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.linea)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.superficie3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.smartphone_rounded, color: c.tinta2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  terminal.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: terminal.conectada
                            ? const Color(0xFF46C281)
                            : c.tinta2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      terminal.conectada ? 'Conectada ahora' : 'Desconectada',
                      style: TextStyle(fontSize: 14, color: c.tinta2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.alerta),
            onPressed: () async {
              final ok = await confirmar(
                context,
                titulo: '¿Desvincular ${terminal.nombre}?',
                mensaje: 'Dejará de ver productos y mandar pedidos hasta que se vuelva a conectar con un código nuevo.',
                accion: 'Desvincular',
                peligrosa: true,
              );
              if (!ok) return;
              try {
                final api = await ref.read(apiProvider.future);
                await api.revocarTerminal(terminal.id);
                ref.invalidate(terminalesProvider);
              } on FalloApi catch (e) {
                if (context.mounted) avisar(context, e.mensaje);
              }
            },
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
  }
}
