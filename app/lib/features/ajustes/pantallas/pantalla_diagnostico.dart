import 'dart:io';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/api/proveedores.dart';
import '../../../core/formato/formato.dart';
import '../../../core/servidor/servidor_embebido.dart';
import '../../../core/widgets/estados.dart';
import '../estado/diagnostico_provider.dart';

/// Estado del servidor para dar soporte sin estar en el depósito
/// (`GET /api/v1/diagnostico` y la bitácora). Solo caja.
class PantallaDiagnostico extends ConsumerWidget {
  const PantallaDiagnostico({super.key});

  Future<void> _descargarBitacora(BuildContext context, WidgetRef ref) async {
    try {
      final api = await ref.read(apiProvider.future);
      final log = await api.descargarBitacora();
      if (!context.mounted) return;
      if (log.texto.trim().isEmpty) {
        avisar(context, 'La bitácora está vacía');
        return;
      }
      if (kIsWeb) {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              _DialogoBitacora(nombre: log.nombre, texto: log.texto),
        );
        return;
      }
      final carpeta = await carpetaCaja();
      final archivo = File('${carpeta.path}/${log.nombre}')
        ..writeAsStringSync(log.texto, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path, mimeType: 'text/plain')],
          subject: 'Bitácora de Anaquel',
        ),
      );
    } on Object catch (e) {
      if (context.mounted) {
        avisar(
          context,
          'No se pudo descargar la bitácora: ${mensajeDeError(e)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final estado = ref.watch(diagnosticoProvider);

    return Scaffold(
      backgroundColor: c.fondo,
      appBar: AppBar(
        backgroundColor: c.fondo,
        surfaceTintColor: Colors.transparent,
        title: const Text('Diagnóstico'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.read(diagnosticoProvider.notifier).refrescar(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: switch (estado) {
          AsyncData(:final value) => _Contenido(
            diagnostico: value,
            alDescargarBitacora: () => _descargarBitacora(context, ref),
          ),
          AsyncError(:final error) => EstadoError(
            error: error,
            alReintentar: () =>
                ref.read(diagnosticoProvider.notifier).refrescar(),
          ),
          _ => const Cargando(mensaje: 'Revisando el servidor'),
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.diagnostico,
    required this.alDescargarBitacora,
  });

  final Diagnostico diagnostico;
  final VoidCallback alDescargarBitacora;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final errores = diagnostico.ultimosErrores;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                _Tarjeta(
                  titulo: 'Servidor',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Metrica(
                            icono: Icons.tag_rounded,
                            etiqueta: 'Versión',
                            valor: diagnostico.version,
                          ),
                          _Metrica(
                            icono: Icons.storage_rounded,
                            etiqueta: 'Base de datos',
                            valor: tamanoLegible(diagnostico.bytesBaseDatos),
                          ),
                          _Metrica(
                            icono: Icons.device_hub_rounded,
                            etiqueta: 'Conexiones',
                            valor: '${diagnostico.conexiones}',
                          ),
                          _Metrica(
                            icono: Icons.phone_iphone_rounded,
                            etiqueta: 'Terminales',
                            valor: '${diagnostico.terminalesConectadas}',
                          ),
                        ],
                      ),
                      Divider(height: 1, color: c.linea),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: c.tinta2,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Encendido desde ${fechaHora(diagnostico.iniciado)}'
                              ' · esquema ${diagnostico.esquema}',
                              style: TextStyle(color: c.tinta2, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Tarjeta(
                  titulo: errores.isEmpty
                      ? 'Sin errores'
                      : 'Últimos errores (${errores.length})',
                  child: errores.isEmpty
                      ? Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: c.verde,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Nada ha fallado desde que arrancó el '
                                'servidor.',
                                style: TextStyle(color: c.tinta2),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 8,
                          children: [
                            for (final error in errores)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: c.alertaSuave,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SelectableText(
                                  error,
                                  style: TextStyle(
                                    color: c.tinta,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            Text(
                              'Se borran al reiniciar; la bitácora los '
                              'conserva.',
                              style: TextStyle(color: c.tinta2, fontSize: 13),
                            ),
                          ],
                        ),
                ),
                _Tarjeta(
                  titulo: 'Soporte',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Text(
                        'Descarga el registro del servidor para revisarlo con '
                        'quien te ayuda. No cambia nada de la caja.',
                        style: TextStyle(color: c.tinta2, height: 1.4),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: alDescargarBitacora,
                          icon: const Icon(Icons.description_outlined),
                          label: Text(
                            kIsWeb ? 'Ver bitácora' : 'Descargar bitácora',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      width: 166,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.superficie2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.linea),
      ),
      child: Row(
        children: [
          Icon(icono, color: c.azul, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: TextStyle(color: c.tinta2, fontSize: 12)),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.tinta,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          child,
        ],
      ),
    );
  }
}

class _DialogoBitacora extends StatelessWidget {
  const _DialogoBitacora({required this.nombre, required this.texto});

  final String nombre;
  final String texto;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(nombre),
    content: SizedBox(
      width: 640,
      height: 420,
      child: SingleChildScrollView(
        child: SelectableText(
          texto,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
