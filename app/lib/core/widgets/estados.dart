import 'package:flutter/material.dart';

import '../../app/tema/colores.dart';
import '../api/fallo_api.dart';
import '../textos.dart';

/// Estado vacío con ícono, título, explicación y una acción opcional.
/// Toda pantalla con datos lo usa en lugar de dejar el espacio en blanco.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.superficie3,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icono, size: 34, color: c.tinta2),
              ),
              const SizedBox(height: 18),
              Text(
                titulo,
                style: textos.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (mensaje != null) ...[
                const SizedBox(height: 6),
                Text(
                  mensaje!,
                  style: textos.bodyMedium?.copyWith(color: c.tinta2),
                  textAlign: TextAlign.center,
                ),
              ],
              if (accion != null) ...[const SizedBox(height: 20), accion!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error con mensaje legible y botón para reintentar.
class EstadoError extends StatelessWidget {
  const EstadoError({super.key, required this.error, this.alReintentar});

  final Object error;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final sinConexion = error is FalloApi && (error as FalloApi).sinConexion;
    return EstadoVacio(
      icono: sinConexion ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      titulo: sinConexion ? Textos.sinConexionCaja : Textos.algoSalioMal,
      mensaje: mensajeDeError(error),
      accion: alReintentar == null
          ? null
          : OutlinedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(Textos.reintentar),
            ),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) => Semantics(
    label: mensaje ?? Textos.cargando,
    liveRegion: true,
    excludeSemantics: true,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (mensaje != null) ...[
            const SizedBox(height: 14),
            Text(mensaje!, style: TextStyle(color: context.colores.tinta2)),
          ],
        ],
      ),
    ),
  );
}

/// Diálogo de confirmación compartido (docs/ESTANDARES.md: no se crea uno por pantalla).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  bool peligrosa = false,
}) async {
  final c = context.colores;
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(Textos.cancelar),
        ),
        FilledButton(
          style: peligrosa
              ? FilledButton.styleFrom(
                  backgroundColor: c.alerta,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return r ?? false;
}

void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
