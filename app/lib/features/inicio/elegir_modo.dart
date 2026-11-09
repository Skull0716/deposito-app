import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tema/colores.dart';
import '../../core/config/configuracion.dart';
import '../../core/textos.dart';
import '../personal/estado/personal_provider.dart';
import 'pantallas/crear_cuenta_maestra.dart';
import 'pantallas/inicializando_bd.dart';
import 'pantallas/restaurar_respaldo.dart';

/// Pantalla "Configura tu punto de venta".
///
/// Al terminar de configurar guarda el modo del dispositivo y el router lleva
/// al tablero de la caja o a vincular la terminal (app/router.dart).
class ElegirModo extends ConsumerWidget {
  const ElegirModo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final notificador = ref.read(configuracionProvider.notifier);

    return Scaffold(
      backgroundColor: c.fondo,
      body: Stack(
        children: [
          // Degradado azul elegante desde arriba
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.azul.withValues(alpha: 0.08),
                    c.fondo.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                // En teléfonos chicos no cabe todo: se desplaza.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        Textos.configurarPuntoDeVenta,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: c.tinta,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        Textos.eligeQueDeseasHacer,
                        style: TextStyle(
                          fontSize: 16,
                          color: c.tinta2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        Textos.seleccionaUnaOpcion,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.tinta,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Opciones
                      _OpcionConfiguracion(
                        icono: Icons.dns_outlined,
                        titulo: Textos.crearServidorPos,
                        descripcion: Textos.descripcionCrearServidor,
                        alPresionar: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CrearCuentaMaestra(
                                alCompletar: (negocio, nombre, pin) {
                                  // El servidor aún no arranca: el dueño se
                                  // crea en cuanto la caja esté lista.
                                  ref
                                      .read(
                                        cuentaMaestraPendienteProvider.notifier,
                                      )
                                      .guardar((
                                        negocio: negocio,
                                        nombre: nombre,
                                        pin: pin,
                                      ));
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InicializandoBD(
                                        alTerminar: () => notificador
                                            .elegirModo(ModoDispositivo.caja),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _OpcionConfiguracion(
                        icono: Icons.smartphone_outlined,
                        titulo: Textos.vincularCelular,
                        descripcion: Textos.descripcionVincularCelular,
                        alPresionar: () =>
                            notificador.elegirModo(ModoDispositivo.terminal),
                      ),
                      const SizedBox(height: 16),
                      _OpcionConfiguracion(
                        icono: Icons.restore_outlined,
                        titulo: Textos.restaurarServidor,
                        descripcion: Textos.descripcionRestaurarServidor,
                        alPresionar: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RestaurarRespaldo(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 48),

                      // Footer
                      Center(
                        child: Text(
                          Textos.desarrolladoPor,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.tinta2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ), // Closes SafeArea
        ], // Closes Stack children
      ), // Closes Stack
    ); // Closes Scaffold
  }
}

class _OpcionConfiguracion extends StatelessWidget {
  const _OpcionConfiguracion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.alPresionar,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: c.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.linea),
        ),
        child: InkWell(
          onTap: alPresionar,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.azul.withValues(alpha: 0.1), // Fondo azul clarito
                    borderRadius: BorderRadius.circular(18), // Más redondito
                  ),
                  child: Icon(
                    icono,
                    color: c.azul, // Ícono azul
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.tinta,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: c.tinta2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, color: c.tinta, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
