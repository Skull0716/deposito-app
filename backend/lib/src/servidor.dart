import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:sqlite3/sqlite3.dart';

import 'comun/bitacora.dart';
import 'comun/errores.dart';
import 'comun/fechas.dart';
import 'comun/middleware.dart';
import 'comun/seguridad.dart';
import 'comun/sesion.dart';
import 'db/almacen_fotos.dart';
import 'db/base_datos.dart';
import 'db/migraciones.dart';
import 'db/repositorio_ajustes.dart';
import 'db/repositorio_caja.dart';
import 'db/repositorio_idempotencia.dart';
import 'db/repositorio_productos.dart';
import 'db/repositorio_terminales.dart';
import 'db/repositorio_usuarios.dart';
import 'rutas/rutas_ajustes.dart';
import 'rutas/rutas_alertas.dart';
import 'rutas/rutas_caja.dart';
import 'rutas/rutas_diagnostico.dart';
import 'rutas/rutas_productos.dart';
import 'rutas/rutas_terminales.dart';
import 'rutas/rutas_usuarios.dart';
import 'seed/datos_ejemplo.dart';
import 'seed/fotos_ejemplo.dart';
import 'servicios/servicio_ajustes.dart';
import 'servicios/servicio_alertas.dart';
import 'servicios/servicio_caja.dart';
import 'servicios/servicio_diagnostico.dart';
import 'servicios/servicio_productos.dart';
import 'servicios/servicio_terminales.dart';
import 'servicios/servicio_usuarios.dart';
import 'ws/hub.dart';
import 'db/repositorio_envases.dart';
import 'db/repositorio_ventas.dart';
import 'rutas/rutas_envases.dart';
import 'rutas/rutas_ventas.dart';
import 'rutas/rutas_pedidos.dart';
import 'servicios/servicio_envases.dart';
import 'servicios/servicio_ventas.dart';
import 'servicios/servicio_pedidos.dart';

/// Fondo del turno que se abre solo con datos de ejemplo: $500.00.
const fondoEjemplo = 50000;

/// Versión del servidor; se manda en `conexion.lista`.
const versionServidor = '0.1.0';

/// El servidor de Anaquel. La app lo arranca dentro de sí misma en modo Caja;
/// en desarrollo lo arranca `bin/server.dart`.
///
/// ```dart
/// final servidor = DepositoServer(rutaBaseDatos: '${docs.path}/anaquel.db');
/// await servidor.iniciar();
/// // La app de la caja usa servidor.claveCaja en X-Clave-Terminal.
/// await servidor.detener();
/// ```
class DepositoServer {
  DepositoServer({
    required this.rutaBaseDatos,
    this.puerto = 8080,
    InternetAddress? direccion,
    String? claveCaja,
    this.carpetaFotos,
    this.datosEjemplo = false,
    this.fotosEjemplo = const {},
    Bitacora? bitacora,
    this._reloj = relojSistema,
  }) : direccion = direccion ?? InternetAddress.anyIPv4,
       claveCaja = claveCaja ?? generarClave(),
       bitacora = bitacora ?? Bitacora();

  /// Archivo SQLite, o [enMemoria].
  final String rutaBaseDatos;

  /// `0` elige un puerto libre (pruebas); el real queda en [puertoActual].
  final int puerto;
  final InternetAddress direccion;

  /// Clave con la que la app de la caja se identifica. Nunca sale del iPad.
  final String claveCaja;

  /// Dónde se guardan las fotos de productos. Por omisión, `fotos/` junto a
  /// la base; con [enMemoria], una carpeta temporal que se borra al detener.
  final String? carpetaFotos;

  /// Carga los productos del prototipo si la base está vacía y abre un turno
  /// de caja con [fondoEjemplo] si nunca hubo uno.
  final bool datosEjemplo;

  /// Bytes de las fotos de ejemplo por nombre de archivo (ver
  /// [fotosDeEjemplo]). Con [datosEjemplo], se ponen a los productos de
  /// ejemplo que no tengan foto. La app las lee de sus assets.
  final Map<String, Uint8List> fotosEjemplo;
  final Bitacora bitacora;
  final Reloj _reloj;

  HttpServer? _http;
  Database? _db;
  Hub? _hub;
  Directory? _fotosTemporales;

  bool get iniciado => _http != null;

  int get puertoActual =>
      _http?.port ?? (throw StateError('El servidor no está iniciado'));

  /// Abre la base, aplica migraciones (con respaldo previo) y empieza a escuchar.
  Future<void> iniciar() async {
    if (iniciado) return;
    final db = abrirBaseDatos(rutaBaseDatos);
    try {
      final aplicadas = aplicarMigraciones(
        db,
        rutaRespaldo: _rutaRespaldoMigracion,
        reloj: _reloj,
      );
      if (aplicadas.isNotEmpty) {
        bitacora.info('Migraciones aplicadas: ${aplicadas.join(', ')}');
      }

      final hub = Hub(
        version: versionServidor,
        bitacora: bitacora,
        reloj: _reloj,
      );
      final ajustes = RepositorioAjustes(db);
      final repoProductos = RepositorioProductos(db);
      final repoEnvases = RepositorioEnvases(db);
      final repoVentas = RepositorioVentas(db);
      final repoCaja = RepositorioCaja(db);
      final idempotencia = RepositorioIdempotencia(db);
      final alertas = ServicioAlertas(
        repoProductos: repoProductos,
        repoAjustes: ajustes,
        hub: hub,
        reloj: _reloj,
      );
      final productos = ServicioProductos(
        db: db,
        repositorio: repoProductos,
        hub: hub,
        fotos: AlmacenFotos(_carpetaDeFotos()),
        alertas: alertas,
        reloj: _reloj,
      );
      final terminales = ServicioTerminales(
        repositorio: RepositorioTerminales(db),
        hub: hub,
        reloj: _reloj,
      );
      final usuarios = ServicioUsuarios(
        db: db,
        repo: RepositorioUsuarios(db),
        reloj: _reloj,
      );
      final servicioAjustes = ServicioAjustes(
        db: db,
        repo: ajustes,
        reloj: _reloj,
      );
      final caja = ServicioCaja(
        db: db,
        repo: repoCaja,
        idempotencia: idempotencia,
        ajustes: ajustes,
        usuarios: usuarios,
        hub: hub,
        reloj: _reloj,
      );
      final envases = ServicioEnvases(
        db: db,
        repositorio: repoEnvases,
        idempotencia: idempotencia,
        caja: caja,
        hub: hub,
        reloj: _reloj,
      );
      final ventas = ServicioVentas(
        db: db,
        repoVentas: repoVentas,
        repoProductos: repoProductos,
        repoEnvases: repoEnvases,
        repoAjustes: ajustes,
        repoCaja: repoCaja,
        idempotencia: idempotencia,
        usuarios: usuarios,
        hub: hub,
        alertas: alertas,
        reloj: _reloj,
      );

      final diagnostico = ServicioDiagnostico(
        db: db,
        hub: hub,
        bitacora: bitacora,
        iniciado: _reloj(),
        reloj: _reloj,
      );

      final pedidos = ServicioPedidos(
        db: db,
        repoProductos: repoProductos,
        hub: hub,
        reloj: _reloj,
      );

      if (datosEjemplo && repoProductos.contar() == 0) {
        cargarDatosEjemplo(
          productos,
          zonaHoraria: ajustes.zonaHoraria,
          reloj: _reloj,
        );
        bitacora.info('Datos de ejemplo cargados');
      }
      if (datosEjemplo) _ponerFotosEjemplo(productos, repoProductos);
      // En demo se puede cobrar desde el primer arranque. Solo si nunca hubo
      // un turno: después de un corte, la caja se queda cerrada.
      if (datosEjemplo && repoCaja.contar() == 0) {
        caja.abrir({'fondo': fondoEjemplo});
        bitacora.info('Turno de caja de ejemplo abierto');
      }

      final router =
          Router(
              notFoundHandler: (_) => throw ErrorApi.noEncontrado('esa ruta'),
            )
            ..get('/salud', (Request _) => Response.ok('ok'))
            ..get('/api/v1/ws', (Request peticion) {
              final sesion = sesionDe(peticion);
              return webSocketHandler(
                (canal, _) => hub.conectar(canal, sesion),
                pingInterval: const Duration(seconds: 20),
              )(peticion);
            });
      montarRutasTerminales(router, terminales);
      montarRutasProductos(router, productos);
      montarRutasEnvases(router, envases, ventas);
      montarRutasVentas(router, ventas);
      montarRutasPedidos(router, pedidos);
      montarRutasCaja(router, caja);
      montarRutasUsuarios(router, usuarios);
      montarRutasAjustes(router, servicioAjustes);
      montarRutasAlertas(router, alertas);
      montarRutasDiagnostico(router, diagnostico);

      final manejador = const Pipeline()
          .addMiddleware(registrarPeticiones(bitacora))
          .addMiddleware(manejarErrores(bitacora))
          .addMiddleware(
            autenticar(claveCaja: claveCaja, terminales: terminales),
          )
          .addHandler(router.call);

      _http = await io.serve(manejador, direccion, puerto);
      _db = db;
      _hub = hub;
      bitacora.info(
        'Servidor $versionServidor en ${direccion.address}:${_http!.port}',
      );
    } catch (e, pila) {
      // Limpieza integral en caso de error durante el arranque
      await _hub?.cerrar();
      await _http?.close(force: true);
      db.close();
      _borrarFotosTemporales();
      _http = null;
      _db = null;
      _hub = null;
      bitacora.error('No se pudo iniciar el servidor', e, pila);
      rethrow;
    }
  }

  /// Cierra conexiones y la base. Se puede volver a [iniciar] después.
  Future<void> detener() async {
    await _hub?.cerrar();
    await _http?.close(force: true);
    _db?.close();
    _borrarFotosTemporales();
    _http = null;
    _db = null;
    _hub = null;
    bitacora.info('Servidor detenido');
  }

  /// Solo a productos sin foto: también funciona en bases ya creadas y no
  /// reemplaza una foto que se haya subido.
  void _ponerFotosEjemplo(
    ServicioProductos productos,
    RepositorioProductos repo,
  ) {
    for (final e in fotosDeEjemplo.entries) {
      final bytes = fotosEjemplo[e.value];
      final producto = repo.porCodigo(e.key);
      if (bytes == null || producto == null || producto.foto != null) continue;
      try {
        productos.guardarFoto(producto.id, 'image/webp', bytes);
      } on ErrorApi catch (error) {
        bitacora.advertencia(
          'Foto de ejemplo ${e.value}: ${error.campos ?? error.mensaje}',
        );
      }
    }
  }

  String _carpetaDeFotos() {
    if (carpetaFotos != null) return carpetaFotos!;
    if (rutaBaseDatos != enMemoria) {
      return p.join(p.dirname(rutaBaseDatos), 'fotos');
    }
    return (_fotosTemporales = Directory.systemTemp.createTempSync(
      'anaquel_fotos_',
    )).path;
  }

  void _borrarFotosTemporales() {
    final carpeta = _fotosTemporales;
    _fotosTemporales = null;
    if (carpeta != null && carpeta.existsSync()) {
      carpeta.deleteSync(recursive: true);
    }
  }

  String? _rutaRespaldoMigracion(int versionActual) {
    if (rutaBaseDatos == enMemoria) return null;
    final marca = instanteIso(_reloj()).replaceAll(RegExp('[-:]'), '');
    final carpeta = p.join(p.dirname(rutaBaseDatos), 'respaldos');
    Directory(carpeta).createSync(recursive: true);
    return p.join(carpeta, 'antes-de-migrar-v$versionActual-$marca.db');
  }
}
