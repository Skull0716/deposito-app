import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/tema/colores.dart';
import 'app/tema/tema.dart';
import 'core/api/api_falsa.dart';
import 'core/api/proveedores.dart';
import 'core/config/configuracion.dart';
import 'features/inicio/pantalla_carga.dart';
import 'features/inicio/pantallas/restaurar_respaldo.dart';
import 'features/pdv/pantallas/punto_venta.dart';
import 'features/personal/pantallas/gestion_personal.dart';
import 'features/personal/pantallas/seguridad_respaldo.dart';

/// Vitrina de pantallas con datos de prueba, sin servidor:
///
///     flutter run -t lib/sandbox.dart
///
/// Sirve para revisar diseño. Las que todavía no tienen endpoint (personal,
/// turnos, cortes, respaldo) solo existen aquí hasta que se conecten.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = ApiFalsa();

  runApp(
    ProviderScope(
      overrides: [
        preferenciasProvider.overrideWithValue(prefs),
        apiProvider.overrideWith((ref) async => api),
      ],
      child: MaterialApp(
        title: 'Anaquel · vitrina',
        debugShowCheckedModeBanner: false,
        theme: temaClaro(),
        darkTheme: temaOscuro(),
        themeMode: ThemeMode.light,
        home: const _Vitrina(),
      ),
    ),
  );
}

class _Vitrina extends StatelessWidget {
  const _Vitrina();

  static final _pantallas = <(String, String, Widget Function())>[
    (
      'Pantalla de carga',
      'Animación al abrir la app (regresa sola en 4 s)',
      _CargaDemo.new,
    ),
    ('Punto de venta', 'Conectado (aquí con ApiFalsa)', PuntoVenta.new),
    ('Personal', 'Sin endpoint todavía', GestionPersonal.new),
    ('Seguridad y respaldo', 'Sin endpoint todavía', SeguridadRespaldo.new),
    ('Restaurar respaldo', 'Sin endpoint todavía', RestaurarRespaldo.new),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      appBar: AppBar(title: const Text('Vitrina de pantallas')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pantallas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final (titulo, nota, construir) = _pantallas[i];
          return ListTile(
            tileColor: c.superficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: c.linea),
            ),
            title: Text(titulo),
            subtitle: Text(nota),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => construir()),
            ),
          );
        },
      ),
    );
  }
}

/// La pantalla de carga no tiene botón de regresar: en la app dura lo que
/// tarda en arrancar. Aquí regresa sola a la vitrina.
class _CargaDemo extends StatefulWidget {
  const _CargaDemo();

  @override
  State<_CargaDemo> createState() => _CargaDemoState();
}

class _CargaDemoState extends State<_CargaDemo> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => const PantallaCarga();
}
