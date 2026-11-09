import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema/colores.dart';
import '../../../core/api/fallo_api.dart';
import '../../../core/config/configuracion.dart';
import '../../../core/formato/formato.dart';
import '../../../core/servidor/servidor_embebido.dart';
import '../../../core/textos.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/indicador_conexion.dart';
import '../../../core/widgets/marca.dart';
import '../../alertas/estado/alertas_provider.dart';
import '../../auth/pantallas/login_diario.dart';
import '../../pedidos/estado/pedidos_provider.dart';
import '../../personal/estado/personal_provider.dart';
import 'conectar_terminal.dart';
import 'secciones_caja.dart';

/// Marco de la caja: menú lateral café, barra superior y la sección activa.
///
/// - 1000 px o más (iPad horizontal): menú completo.
/// - 640 a 1000 px (iPad vertical): menú de íconos.
/// - Menos: menú en cajón (para probar en teléfono).
class ShellCaja extends ConsumerWidget {
  const ShellCaja({super.key, required this.seccion, required this.child});

  final String seccion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servidor = ref.watch(servidorEmbebidoProvider);
    return switch (servidor) {
      AsyncData() => _ConPersonal(
        child: _Marco(seccion: seccion, child: child),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/inicio'),
            tooltip: 'Volver al Inicio',
          ),
        ),
        body: EstadoVacio(
          icono: Icons.dns_outlined,
          titulo: 'No se pudo iniciar la caja',
          mensaje:
              '$error\n\nCierra otras apps que usen el puerto $puertoServidor y reintenta.',
          accion: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/inicio'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver al Inicio'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(servidorEmbebidoProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(Textos.reintentar),
              ),
            ],
          ),
        ),
      ),
      _ => const _Arrancando(),
    };
  }
}

class _Arrancando extends StatelessWidget {
  const _Arrancando();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      backgroundColor: c.superficie,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoAnaquel(tamano: 72),
            const SizedBox(height: 20),
            Text(
              'Abriendo la caja…',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: c.tinta),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                color: c.azul,
                backgroundColor: c.superficie2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marco extends ConsumerWidget {
  const _Marco({required this.seccion, required this.child});

  final String seccion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(pedidosPendientesProvider).value?.length ?? 0;
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancho = medidas.maxWidth;
        final actual = seccionCaja(seccion);
        if (ancho < 640) {
          final itemsNav = [
            (
              ruta: 'inicio',
              icono: Icons.space_dashboard_outlined,
              activo: Icons.space_dashboard_rounded,
              label: 'Inicio',
            ),
            (
              ruta: 'vender',
              icono: Icons.point_of_sale_outlined,
              activo: Icons.point_of_sale_rounded,
              label: 'Vender',
            ),
            (
              ruta: 'ventas',
              icono: Icons.receipt_long_outlined,
              activo: Icons.receipt_long_rounded,
              label: 'Ventas',
            ),
            (
              ruta: 'envases',
              icono: Icons.recycling_outlined,
              activo: Icons.recycling_rounded,
              label: 'Envases',
            ),
            (
              ruta: 'catalogo',
              icono: Icons.inventory_2_outlined,
              activo: Icons.inventory_2_rounded,
              label: 'Catálogo',
            ),
          ];
          final indiceActual = itemsNav.indexWhere((it) => it.ruta == seccion);

          return Scaffold(
            appBar: AppBar(
              title: Text(actual.titulo),
              actions: const [
                _BotonConectar(compacto: true),
                SizedBox(width: 8),
              ],
            ),
            drawer: Drawer(
              backgroundColor: context.colores.superficie,
              child: _MenuLateral(
                seccion: seccion,
                compacto: false,
                alNavegar: () => Navigator.pop(context),
              ),
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: indiceActual >= 0 ? indiceActual : 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (idx) {
                final destino = itemsNav[idx].ruta;
                if (destino != seccion) {
                  context.go('/caja/$destino');
                }
              },
              destinations: [
                for (final item in itemsNav)
                  NavigationDestination(
                    icon: _IconoNav(
                      icono: item.icono,
                      insignia: item.ruta == 'vender' ? pedidos : 0,
                    ),
                    selectedIcon: _IconoNav(
                      icono: item.activo,
                      insignia: item.ruta == 'vender' ? pedidos : 0,
                    ),
                    label: item.label,
                  ),
              ],
            ),
          );
        }
        final compacto = ancho < 1000;
        return Scaffold(
          body: Row(
            children: [
              _MenuLateral(seccion: seccion, compacto: compacto),
              Expanded(
                child: Column(
                  children: [
                    _BarraSuperior(
                      titulo: actual.titulo,
                      compacta: ancho < 820,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuLateral extends ConsumerWidget {
  const _MenuLateral({
    required this.seccion,
    required this.compacto,
    this.alNavegar,
  });

  final String seccion;
  final bool compacto;
  final VoidCallback? alNavegar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final ip = ref.watch(direccionLocalProvider).value;
    final alertas = ref.watch(alertasProvider).value?.alertas.length ?? 0;
    final pedidos = ref.watch(pedidosPendientesProvider).value?.length ?? 0;

    return Container(
      width: compacto ? 92 : 240,
      decoration: BoxDecoration(
        color: c.superficie,
        border: Border(right: BorderSide(color: c.linea)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compacto ? 8 : 12,
            vertical: 18,
          ),
          child: Column(
            crossAxisAlignment: compacto
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(compacto ? 0 : 8, 4, 0, 20),
                child: Row(
                  mainAxisAlignment: compacto
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    const LogoAnaquel(),
                    if (!compacto) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anaquel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textos.headlineSmall?.copyWith(
                                color: c.tinta,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'Caja principal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.tinta2,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final s in seccionesCaja)
                      _ElementoMenu(
                        seccion: s,
                        activo: s.ruta == seccion,
                        compacto: compacto,
                        insignia: s.ruta == 'alertas' && alertas > 0
                            ? alertas
                            : s.ruta == 'vender' && pedidos > 0
                            ? pedidos
                            : null,
                        alTocar: () {
                          alNavegar?.call();
                          context.go('/caja/${s.ruta}');
                        },
                      ),
                  ],
                ),
              ),
              if (!compacto)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      IndicadorConexion(
                        colorTexto: c.tinta,
                        etiquetaEnLinea: 'Servidor activo',
                      ),
                      Row(
                        children: [
                          Icon(Icons.wifi_rounded, size: 16, color: c.tinta2),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ip == null ? 'Sin Wi-Fi' : '$ip:$puertoServidor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.tinta2, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElementoMenu extends StatelessWidget {
  const _ElementoMenu({
    required this.seccion,
    required this.activo,
    required this.compacto,
    required this.alTocar,
    this.insignia,
  });

  final SeccionCaja seccion;
  final bool activo;
  final bool compacto;
  final VoidCallback alTocar;
  final int? insignia;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final colorIcono = activo ? c.azul : const Color(0xFF64748B);
    final colorTexto = activo ? c.azul : c.tinta;

    final icono = Icon(
      activo ? seccion.iconoActivo : seccion.icono,
      color: colorIcono,
      size: compacto ? 20 : 22,
    );

    final contenido = compacto
        ? Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: insignia != null,
                label: Text('${insignia ?? ''}'),
                backgroundColor: c.alerta,
                child: icono,
              ),
              const SizedBox(height: 3),
              Text(
                seccion.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: colorTexto,
                ),
              ),
            ],
          )
        : Row(
            children: [
              Container(
                width: 3.5,
                height: 22,
                decoration: BoxDecoration(
                  color: activo ? c.azul : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              icono,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  seccion.titulo,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: colorTexto,
                  ),
                ),
              ),
              if (insignia != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.alerta,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$insignia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Tooltip(
        message: seccion.titulo,
        child: Material(
          color: activo ? c.superficie3 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: c.superficie2,
            onTap: alTocar,
            child: Container(
              height: compacto ? 54 : 48,
              padding: EdgeInsets.symmetric(horizontal: compacto ? 2 : 8),
              alignment: compacto ? Alignment.center : Alignment.centerLeft,
              child: contenido,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconoNav extends StatelessWidget {
  const _IconoNav({required this.icono, required this.insignia});

  final IconData icono;

  /// Pedidos pendientes que se muestran sobre el ícono. 0 lo oculta.
  final int insignia;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: insignia > 0,
    backgroundColor: context.colores.alerta,
    label: Text('$insignia'),
    child: Icon(icono),
  );
}

class _BarraSuperior extends ConsumerWidget {
  const _BarraSuperior({required this.titulo, required this.compacta});

  final String titulo;
  final bool compacta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final tema = ref.watch(configuracionProvider).tema;
    final oscuro =
        tema == ThemeMode.dark ||
        (tema == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
      decoration: BoxDecoration(
        color: c.superficie,
        border: Border(bottom: BorderSide(color: c.linea)),
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            // La fecha cede espacio en pantallas angostas (iPad vertical).
            if (!compacta)
              Flexible(
                child: Pildora(
                  texto: fechaLarga(DateTime.now()),
                  icono: Icons.calendar_today_rounded,
                ),
              ),
            IconButton.outlined(
              tooltip: oscuro ? 'Tema claro' : 'Tema oscuro',
              style: IconButton.styleFrom(side: BorderSide(color: c.linea)),
              onPressed: () => ref
                  .read(configuracionProvider.notifier)
                  .cambiarTema(oscuro ? ThemeMode.light : ThemeMode.dark),
              icon: Icon(
                oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
            ),
            _BotonConectar(compacto: compacta),
          ],
        ),
      ),
    );
  }
}

class _BotonConectar extends StatelessWidget {
  const _BotonConectar({this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Vincular terminal móvil para pedidos',
    child: OutlinedButton.icon(
      onPressed: () => mostrarConectarTerminal(context),
      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
      label: Text(compacto ? 'Vincular' : 'Vincular Terminal'),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 10 : 14,
          vertical: compacto ? 8 : 10,
        ),
      ),
    ),
  );
}

/// Con el servidor listo: crea la cuenta maestra pendiente y, si hay
/// personal registrado, pide el inicio de turno antes de entrar a la caja.
class _ConPersonal extends ConsumerStatefulWidget {
  const _ConPersonal({required this.child});

  final Widget child;

  @override
  ConsumerState<_ConPersonal> createState() => _ConPersonalState();
}

class _ConPersonalState extends ConsumerState<_ConPersonal> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(cuentaMaestraPendienteProvider.notifier).aplicar();
      } on FalloApi catch (e) {
        if (mounted) {
          avisar(context, 'No se creó la cuenta maestra: ${mensajeDeError(e)}');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final actual = ref.watch(usuarioActualProvider);
    final activos = [
      for (final u in ref.watch(usuariosProvider).value ?? const <Usuario>[])
        if (u.activo) u,
    ];
    if (actual != null || activos.isEmpty) return widget.child;
    return LoginDiario(
      usuarios: activos,
      alEntrar: ref.read(usuarioActualProvider.notifier).entrar,
    );
  }
}
