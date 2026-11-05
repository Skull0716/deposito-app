import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/api/proveedores.dart';
import '../../../../core/formato/formato.dart';
import '../../../../core/respaldo/respaldos.dart';
import '../../../../core/widgets/estados.dart';
import '../../../core/textos.dart';

/// Seguridad y respaldo (diseño de Pablo): copia completa de la base para
/// guardarla fuera del iPad. Además, cada corte de caja guarda una sola.
class SeguridadRespaldo extends ConsumerStatefulWidget {
  const SeguridadRespaldo({super.key});

  @override
  ConsumerState<SeguridadRespaldo> createState() => _SeguridadRespaldoState();
}

class _SeguridadRespaldoState extends ConsumerState<SeguridadRespaldo> {
  File? _ultimo;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargarUltimo();
  }

  Future<void> _cargarUltimo() async {
    try {
      final todos = await respaldosLocales();
      if (mounted) setState(() => _ultimo = todos.firstOrNull);
    } catch (_) {
      // Sin carpeta de documentos (web, pruebas): no hay respaldos locales.
    }
  }

  Future<void> _generar(BuildContext context) async {
    setState(() => _generando = true);
    try {
      final api = await ref.read(apiProvider.future);
      final archivo = await guardarRespaldo(api);
      if (!mounted) return;
      setState(() {
        _ultimo = archivo;
        _generando = false;
      });
      if (context.mounted) _mostrarAlertaExportar(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _generando = false);
      if (context.mounted) avisar(context, 'No se pudo generar: $e');
    }
  }

  Future<void> _compartir(BuildContext context) async {
    Navigator.pop(context);
    final archivo = _ultimo;
    if (archivo == null) return;
    try {
      await compartirRespaldo(archivo);
    } catch (e) {
      if (mounted) avisar(this.context, 'No se pudo compartir: $e');
    }
  }

  String get _textoUltimo {
    final f = _ultimo;
    if (f == null) return 'Aún no se ha creado';
    final kb = (f.lengthSync() / 1024).ceil();
    return '${fechaHora(f.lastModifiedSync().toUtc().toIso8601String())} · $kb KB';
  }

  void _mostrarAlertaExportar(BuildContext context) {
    final c = context.colores;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.fondo,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.alertaSuave.withValues(
                  alpha: 0.2,
                ), // Yellowish/amber background
                shape: BoxShape.circle,
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Respaldo listo para exportar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.tinta,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Guarde este archivo en un lugar seguro. Contiene todo su inventario y cortes de caja.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.brown[800],
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _mostrarBottomSheetCompartir(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.azul,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  Textos.continuar,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: c.tinta2),
                child: const Text(Textos.cancelar),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarBottomSheetCompartir(BuildContext context) {
    final c = context.colores;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: c.fondo,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Compartir respaldo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.tinta,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ultimo?.uri.pathSegments.last ?? 'anaquel.db',
                style: TextStyle(fontSize: 14, color: c.tinta2),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _OpcionCompartir(
                    icono: Icons.wifi_tethering,
                    texto: 'AirDrop',
                    alPresionar: () => _compartir(context),
                  ),
                  _OpcionCompartir(
                    icono: Icons.folder_rounded,
                    texto: 'Guardar en\nArchivos',
                    alPresionar: () => _compartir(context),
                  ),
                  _OpcionCompartir(
                    icono: Icons.ios_share_rounded,
                    texto: 'Compartir',
                    alPresionar: () => _compartir(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: c.tinta2,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    Textos.cancelar,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Scaffold(
      backgroundColor: c.fondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      Textos.volver,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: c.azul,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'PROTECCIÓN DE DATOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.azul,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seguridad y Respaldo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: c.tinta,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Crea una copia cifrada de la información de tu servidor.',
                    style: TextStyle(
                      fontSize: 15,
                      color: c.tinta2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tarjeta de estado
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: c.fondo,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.linea),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: c.azul.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.storage_rounded,
                            color: c.azul,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Último respaldo creado',
                                style: TextStyle(fontSize: 13, color: c.tinta2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _textoUltimo,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: c.tinta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _generando ? null : () => _generar(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.azul,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _generando ? 'Generando...' : 'Generar Respaldo Manual',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionCompartir extends StatelessWidget {
  const _OpcionCompartir({
    required this.icono,
    required this.texto,
    required this.alPresionar,
  });

  final IconData icono;
  final String texto;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return GestureDetector(
      onTap: alPresionar,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.azul.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icono, color: c.azul, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            style: TextStyle(fontSize: 12, color: c.tinta),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
