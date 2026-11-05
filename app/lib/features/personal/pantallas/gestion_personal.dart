import 'package:deposito_backend/deposito_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/tema/colores.dart';
import '../../../../core/api/fallo_api.dart';
import '../../../../core/widgets/estados.dart';
import '../../../core/textos.dart';
import '../../ventas/pantallas/modal_autorizacion_numpad.dart';
import '../estado/personal_provider.dart';
import '../widgets/bottom_sheet_gestion_accesos.dart';
import '../widgets/modal_alta_empleado.dart';
import 'seguridad_respaldo.dart';
import 'ventas_empleado.dart';

/// Un renglón de la lista, con lo que muestra el diseño de Pablo.
class _Fila {
  _Fila(this.usuario);

  final Usuario usuario;
  String get nombre => usuario.nombre;
  String get iniciales => inicialesDe(usuario.nombre);
  String get rol => etiquetaRol(usuario.rol);
  bool get activo => usuario.activo;
  bool get esDueno => usuario.rol == 'dueno';
}

/// Gestión de personal (diseño de Pablo), con el personal del servidor.
/// Dar de alta, cambiar PIN y suspender piden el PIN de un gerente o del
/// dueño.
class GestionPersonal extends ConsumerStatefulWidget {
  const GestionPersonal({super.key});

  @override
  ConsumerState<GestionPersonal> createState() => _GestionPersonalState();
}

class _GestionPersonalState extends ConsumerState<GestionPersonal> {
  List<_Fila> get _empleados => [
    for (final u in ref.watch(usuariosProvider).value ?? const <Usuario>[])
      _Fila(u),
  ];

  _Fila? _empleadoSeleccionado;

  /// Pide el PIN de un gerente o del dueño y ejecuta [accion] con él.
  Future<void> _autorizado(
    String titulo,
    Future<void> Function(String pin) accion,
    String exito,
  ) async {
    final pin = await ModalAutorizacionNumpad.mostrar(
      context: context,
      tituloAccion: titulo,
    );
    if (pin == null || !mounted) return;
    try {
      await accion(pin);
      if (mounted) avisar(context, exito);
    } on FalloApi catch (e) {
      if (mounted) {
        avisar(context, e.campos.values.firstOrNull ?? mensajeDeError(e));
      }
    }
  }

  void _abrirAlta() {
    showDialog(
      context: context,
      builder: (_) => ModalAltaEmpleado(
        alGuardar: (nombre, rol, pin) => _autorizado(
          'Dar de alta',
          (autoriza) => ref
              .read(usuariosProvider.notifier)
              .crear(
                nombre: nombre,
                rol: rol == 'Gerente' ? 'gerente' : 'cajero',
                pin: pin,
                pinAutoriza: autoriza,
              ),
          '$nombre ya puede entrar con su PIN',
        ),
      ),
    );
  }

  Future<void> _cambiarPin(_Fila emp) async {
    final control = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Nuevo PIN de ${emp.nombre}'),
        content: TextField(
          controller: control,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'De 4 a 6 dígitos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text(Textos.cancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, control.text.trim()),
            child: const Text(Textos.guardar),
          ),
        ],
      ),
    );
    control.dispose();
    if (nuevo == null || nuevo.isEmpty || !mounted) return;
    await _autorizado(
      'Cambiar PIN',
      (autoriza) => ref
          .read(usuariosProvider.notifier)
          .editar(emp.usuario.id, pin: nuevo, pinAutoriza: autoriza),
      'PIN de ${emp.nombre} actualizado',
    );
  }

  void _abrirGestion(_Fila emp) {
    if (emp.esDueno) return;

    setState(() => _empleadoSeleccionado = emp);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (contextoHoja) => BottomSheetGestionAccesos(
        nombre: emp.nombre,
        rol: emp.rol,
        activo: emp.activo,
        alVerVentas: () {
          Navigator.pop(contextoHoja);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VentasEmpleado(usuario: emp.usuario),
            ),
          );
        },
        alCambiarPin: () {
          Navigator.pop(contextoHoja);
          _cambiarPin(emp);
        },
        alSuspender: () {
          Navigator.pop(contextoHoja);
          _autorizado(
            emp.activo ? 'Suspender acceso' : 'Reactivar acceso',
            (autoriza) => ref
                .read(usuariosProvider.notifier)
                .editar(
                  emp.usuario.id,
                  activo: !emp.activo,
                  pinAutoriza: autoriza,
                ),
            emp.activo
                ? 'Acceso de ${emp.nombre} suspendido'
                : 'Acceso de ${emp.nombre} reactivado',
          );
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _empleadoSeleccionado = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;

    return Scaffold(
      backgroundColor: c.fondo,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const SizedBox(height: 16),
            Text(
              'ADMINISTRACIÓN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.azul,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gestión de Personal',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: c.tinta,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Regresa al inicio de turno: otra persona entra con su PIN.
                    ref.read(usuarioActualProvider.notifier).salir();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.azul,
                    side: BorderSide(color: c.azul.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Salir',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SeguridadRespaldo(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.tinta,
                    side: BorderSide(color: c.linea),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Seguridad y respaldo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _abrirAlta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.azul,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Agregar Empleado',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tabla
            Container(
              decoration: BoxDecoration(
                color: c.fondo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.linea),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'NOMBRE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.tinta2,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'ROL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.tinta2,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Text(
                          'ESTADO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.tinta2,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Filas
                  ..._empleados.asMap().entries.map((entry) {
                    final isLast = entry.key == _empleados.length - 1;
                    final emp = entry.value;
                    final isSelected = emp == _empleadoSeleccionado;

                    return Column(
                      children: [
                        Container(
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: c.azul.withValues(alpha: 0.05),
                                  border: Border.all(color: c.azul, width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          margin: isSelected
                              ? const EdgeInsets.all(4)
                              : EdgeInsets.zero,
                          child: InkWell(
                            onTap: emp.esDueno
                                ? null
                                : () => _abrirGestion(emp),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSelected ? 16 : 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  // Nombre
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: c.azul.withValues(
                                              alpha: 0.08,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              emp.iniciales,
                                              style: TextStyle(
                                                color: c.azul,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            emp.nombre,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: c.tinta,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Rol
                                  Expanded(
                                    flex: 2,
                                    child: emp.esDueno
                                        ? Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: c.azul.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Dueño/Admin',
                                                style: TextStyle(
                                                  color: c.azul,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            emp.rol,
                                            style: TextStyle(
                                              color: c.tinta,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                  // Estado
                                  Text(
                                    emp.activo ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      color: c.azul,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!isLast && !isSelected) const Divider(height: 1),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 48),
            Center(
              child: Text(
                'Desarrollado por Equipo Umizommi',
                style: TextStyle(
                  fontSize: 12,
                  color: c.tinta2.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
