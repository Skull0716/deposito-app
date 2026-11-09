import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../textos.dart';

enum ModoDispositivo { caja, terminal }

/// Datos con los que una terminal habla con la caja. La [clave] la entrega
/// el servidor una sola vez, al registrarse.
@immutable
class ConexionTerminal {
  const ConexionTerminal({
    required this.host,
    required this.puerto,
    required this.clave,
    required this.nombre,
  });

  final String host;
  final int puerto;
  final String clave;
  final String nombre;
}

/// Configuración local de este dispositivo.
@immutable
class Configuracion {
  const Configuracion({this.modo, this.conexion, this.tema = ThemeMode.system});

  final ModoDispositivo? modo;
  final ConexionTerminal? conexion;
  final ThemeMode tema;

  Configuracion copiar({
    ModoDispositivo? Function()? modo,
    ConexionTerminal? Function()? conexion,
    ThemeMode? tema,
  }) => Configuracion(
    modo: modo == null ? this.modo : modo(),
    conexion: conexion == null ? this.conexion : conexion(),
    tema: tema ?? this.tema,
  );
}

/// Se sobrescribe en `main()` con la instancia ya cargada.
final preferenciasProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('preferenciasProvider sin inicializar'),
);

final configuracionProvider =
    NotifierProvider<ConfiguracionNotifier, Configuracion>(
      ConfiguracionNotifier.new,
    );

class ConfiguracionNotifier extends Notifier<Configuracion> {
  static const _modo = 'modo';
  static const _tema = 'tema';
  static const _host = 'conexion.host';
  static const _puerto = 'conexion.puerto';
  static const _clave = 'conexion.clave';
  static const _nombre = 'conexion.nombre';

  SharedPreferences get _prefs => ref.read(preferenciasProvider);

  @override
  Configuracion build() {
    final p = ref.watch(preferenciasProvider);
    final host = p.getString(_host);
    final clave = p.getString(_clave);
    return Configuracion(
      modo: ModoDispositivo.values.asNameMap()[p.getString(_modo)],
      tema:
          ThemeMode.values.asNameMap()[p.getString(_tema)] ?? ThemeMode.system,
      conexion: host == null || clave == null
          ? null
          : ConexionTerminal(
              host: host,
              puerto: p.getInt(_puerto) ?? 8080,
              clave: clave,
              nombre: p.getString(_nombre) ?? Textos.nombreTerminalPorDefecto,
            ),
    );
  }

  Future<void> elegirModo(ModoDispositivo? modo) async {
    if (modo == null) {
      await _prefs.remove(_modo);
    } else {
      await _prefs.setString(_modo, modo.name);
    }
    state = state.copiar(modo: () => modo);
  }

  Future<void> guardarConexion(ConexionTerminal c) async {
    await _prefs.setString(_host, c.host);
    await _prefs.setInt(_puerto, c.puerto);
    await _prefs.setString(_clave, c.clave);
    await _prefs.setString(_nombre, c.nombre);
    state = state.copiar(conexion: () => c);
  }

  Future<void> olvidarConexion() async {
    for (final k in [_host, _puerto, _clave, _nombre]) {
      await _prefs.remove(k);
    }
    state = state.copiar(conexion: () => null);
  }

  Future<void> cambiarTema(ThemeMode tema) async {
    await _prefs.setString(_tema, tema.name);
    state = state.copiar(tema: tema);
  }
}
