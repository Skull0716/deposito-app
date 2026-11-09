import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/colores.dart';
import '../../core/api/fallo_api.dart';
import '../../core/api/proveedores.dart';
import '../../core/config/configuracion.dart';
import '../../core/servidor/servidor_embebido.dart';
import '../../core/textos.dart';
import '../../core/ticket/ticket_pdf.dart';
import '../../core/widgets/estados.dart';
import '../personal/estado/personal_provider.dart';
import '../personal/pantallas/gestion_personal.dart';
import '../personal/pantallas/seguridad_respaldo.dart';
import 'pantallas/pantalla_diagnostico.dart';

/// Ajustes de este dispositivo y, en la caja, los del negocio (para el
/// ticket), el personal y el respaldo.
class PantallaAjustes extends ConsumerWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configuracionProvider);
    final notificador = ref.read(configuracionProvider.notifier);
    final c = context.colores;
    final esCaja = config.modo == ModoDispositivo.caja;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [
                _Grupo(
                  titulo: 'Apariencia',
                  children: [
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('Automático'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Oscuro'),
                        ),
                      ],
                      selected: {config.tema},
                      onSelectionChanged: (s) =>
                          notificador.cambiarTema(s.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: c.seleccion,
                        selectedForegroundColor: c.seleccionTinta,
                        side: BorderSide(color: c.linea),
                      ),
                    ),
                  ],
                ),
                _Grupo(
                  titulo: 'Este dispositivo',
                  children: [
                    _Dato('Modo', esCaja ? 'Caja (servidor)' : 'Terminal'),
                    if (esCaja) ...[
                      _Dato(
                        'Dirección en la Wi-Fi',
                        '${ref.watch(direccionLocalProvider).value ?? 'sin Wi-Fi'}:$puertoServidor',
                      ),
                      _Dato('Versión del servidor', versionServidor),
                    ] else if (config.conexion case final cx?) ...[
                      _Dato('Nombre', cx.nombre),
                      _Dato('Caja', '${cx.host}:${cx.puerto}'),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!esCaja)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await confirmar(
                                context,
                                titulo: '¿Desvincular de la caja?',
                                mensaje: 'Para volver a usar esta terminal hay que escanear un código nuevo en la caja.',
                                accion: 'Desvincular',
                                peligrosa: true,
                              );
                              if (ok) await notificador.olvidarConexion();
                            },
                            icon: const Icon(Icons.link_off_rounded),
                            label: const Text('Desvincular de la caja'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await confirmar(
                              context,
                              titulo: 'Cambiar el modo',
                              mensaje: esCaja
                                  ? 'La caja dejará de atender a las terminales. Los datos se conservan en este iPad.'
                                  : 'Esta terminal se desvinculará de la caja.',
                              accion: 'Cambiar modo',
                              peligrosa: esCaja,
                            );
                            if (!ok) return;
                            if (!esCaja) await notificador.olvidarConexion();
                            await notificador.elegirModo(null);
                          },
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Cambiar modo'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (esCaja) ...[
                  const _Grupo(titulo: 'Negocio', children: [_DatosNegocio()]),
                  _Grupo(
                    titulo: 'Personal y seguridad',
                    children: [
                      _Dato(
                        'En la caja',
                        ref.watch(usuarioActualProvider)?.nombre ??
                            'Sin personal registrado',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GestionPersonal(),
                              ),
                            ),
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Gestión de personal'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SeguridadRespaldo(),
                              ),
                            ),
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Seguridad y respaldo'),
                          ),
                          if (ref.watch(usuarioActualProvider) != null)
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(usuarioActualProvider.notifier)
                                  .salir(),
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Cambiar de usuario'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  _Grupo(
                    titulo: 'Soporte',
                    children: [
                      Text(
                        'Revisa el estado del servidor o comparte su bitácora '
                        'cuando algo no responda.',
                        style: TextStyle(color: c.tinta2, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PantallaDiagnostico(),
                            ),
                          ),
                          icon: const Icon(Icons.monitor_heart_outlined),
                          label: const Text('Diagnóstico del servidor'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.linea),
        boxShadow: c.sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ...children,
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(etiqueta, style: TextStyle(color: context.colores.tinta2)),
      ),
      Flexible(
        child: Text(
          valor,
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}

/// Nombre, dirección, teléfono y mensaje del ticket (`PUT /ajustes`).
class _DatosNegocio extends ConsumerStatefulWidget {
  const _DatosNegocio();

  @override
  ConsumerState<_DatosNegocio> createState() => _DatosNegocioState();
}

class _DatosNegocioState extends ConsumerState<_DatosNegocio> {
  final _campos = {
    for (final clave in AjustesNegocio.claves) clave: TextEditingController(),
  };
  bool _cargado = false;
  bool _guardando = false;

  static const _etiquetas = {
    'nombreNegocio': ('Nombre del negocio', 80),
    'direccion': ('Dirección', 80),
    'telefono': ('Teléfono', 20),
    'mensajeTicket': ('Mensaje al pie del ticket', 120),
  };

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final api = await ref.read(apiProvider.future);
      await api.guardarAjustes({
        for (final e in _campos.entries)
          e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      });
      ref.invalidate(ajustesNegocioProvider);
      if (mounted) avisar(context, 'Datos del negocio guardados');
    } on FalloApi catch (e) {
      if (mounted) {
        avisar(context, e.campos.values.firstOrNull ?? mensajeDeError(e));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = ref.watch(ajustesNegocioProvider).value;
    if (ajustes != null && !_cargado) {
      _cargado = true;
      final valores = ajustes.toJson();
      for (final e in _campos.entries) {
        e.value.text = valores[e.key] as String? ?? '';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        for (final e in _campos.entries)
          TextField(
            controller: e.value,
            maxLength: _etiquetas[e.key]!.$2,
            keyboardType: e.key == 'telefono' ? TextInputType.phone : null,
            decoration: InputDecoration(
              labelText: _etiquetas[e.key]!.$1,
              counterText: '',
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: const Icon(Icons.save_outlined),
            label: const Text(Textos.guardar),
          ),
        ),
      ],
    );
  }
}
