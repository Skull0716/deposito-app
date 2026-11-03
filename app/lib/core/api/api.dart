import 'dart:typed_data';

import 'package:deposito_backend/deposito_backend.dart';
import 'package:dio/dio.dart';

import 'fallo_api.dart';

/// Lo que la app le puede pedir al servidor (docs/API.md).
///
/// Las pantallas solo conocen esta interfaz. [ApiHttp] habla con el servidor
/// real; `ApiFalsa` regresa datos de prueba para pruebas de widgets y para
/// avanzar antes de que exista un endpoint.
abstract interface class Api {
  /// `http://host:puerto`, para armar la URL del WebSocket.
  Uri get base;

  String get clave;

  Future<List<Producto>> listarProductos();

  Future<Producto> crearProducto(Map<String, Object?> datos);

  /// Para el escáner: `null` si no hay un producto con ese código.
  Future<Producto?> buscarPorCodigo(String codigo);

  /// Reemplaza los campos editables; la existencia no cambia por aquí.
  Future<Producto> editarProducto(String id, Map<String, Object?> datos);

  Future<void> eliminarProducto(String id);

  /// Recibe mercancía: `cajas × piezasPorCaja + piezas`.
  Future<Producto> registrarEntrada(
    String id, {
    int cajas = 0,
    int piezas = 0,
    String? caducidad,
    String? nota,
  });

  /// Fija la existencia a lo que se contó físicamente.
  Future<Producto> registrarConteo(
    String id, {
    required int existenciaPiezas,
    String? nota,
  });

  /// Saca piezas rotas, caducadas o regaladas.
  Future<Producto> registrarMerma(
    String id, {
    required int piezas,
    String? nota,
  });

  Future<List<Movimiento>> listarMovimientos(String id);

  /// [tipo]: `image/jpeg`, `image/png` o `image/webp`, de hasta 5 MB.
  Future<Producto> subirFoto(String id, Uint8List bytes, String tipo);

  Future<Producto> borrarFoto(String id);

  /// Crea o actualiza productos desde el texto de un CSV. Con [soloRevisar]
  /// dice qué haría sin guardar. Con algún renglón con error no se guarda
  /// nada (`guardado: false`). Un archivo que no se puede leer es
  /// `datos_invalidos` en `csv`.
  Future<ResultadoImportacion> importarProductos(
    String csv, {
    required bool soloRevisar,
  });

  /// Las últimas 100 ventas, del folio más nuevo al más viejo. Con [turno]
  /// (`actual` o un id `tur_...`), solo las de ese turno; con [usuario],
  /// solo las que cobró esa persona.
  Future<List<ResumenVenta>> listarVentas({String? turno, String? usuario});

  Future<DetalleVenta> obtenerVenta(String id);

  /// Regresa lo que falta de la venta. Ya cancelada es `datos_invalidos`; de
  /// un turno con corte, `turno_cerrado`. [pin] de gerente o dueño si hay
  /// alguno registrado. [destino]: `inventario` o `merma`.
  Future<void> cancelarVenta(
    String id, {
    String? pin,
    String destino = 'inventario',
    String? motivo,
  });

  /// Devolución parcial: [lineas] es `lineaId → unidades`.
  Future<({Devolucion devolucion, DetalleVenta venta})> devolverVenta(
    String id, {
    required Map<int, int> lineas,
    String destino = 'inventario',
    String? motivo,
    String? pin,
  });

  /// Existencias por formato: `mega`, `media`, `cuarto`.
  Future<Map<String, BalanceEnvase>> obtenerBalanceEnvases();

  /// Préstamos sin devolver, del más nuevo al más viejo.
  Future<List<PrestamoEnvase>> listarPrestamos();

  /// Presta vacíos de bodega. Sin suficientes, `envases_insuficientes`.
  Future<PrestamoEnvase> prestarEnvases({
    required String cliente,
    String? telefono,
    required String formato,
    required int cantidad,
  });

  /// Saca vacíos de bodega sin cobro (al proveedor, rotos...).
  Future<Map<String, BalanceEnvase>> sacarVacios({
    required String formato,
    required int cantidad,
    required String motivo,
  });

  /// El cliente regresa vacíos y se le devuelve su depósito en efectivo
  /// (retiro de caja). Necesita la caja abierta.
  Future<({Map<String, BalanceEnvase> balance, Turno turno})> devolverDeposito({
    required String formato,
    required int cantidad,
    String? cliente,
    required String claveIdempotencia,
  });

  /// Bitácora de envases, del más nuevo al más viejo.
  Future<List<MovimientoEnvase>> listarMovimientosEnvases({int limite = 50});

  /// Los envases regresan a bodega: todo lo pendiente o, con [cantidad],
  /// una devolución parcial.
  Future<void> devolverPrestamo(String id, {int? cantidad});

  /// Vacíos que entran a bodega sin una venta.
  Future<Map<String, BalanceEnvase>> recibirVacios({
    required String formato,
    required int cantidad,
  });

  /// Cobra envases vacíos de bodega al precio de depósito. Es una venta con
  /// folio; reintentar con la misma [claveIdempotencia] no cobra otra vez.
  Future<VentaRegistrada> venderVacios({
    required String formato,
    required int cantidad,
    required String metodo,
    int? recibido,
    required String claveIdempotencia,
  });

  /// El turno abierto con sus movimientos; `turno` es `null` si la caja está
  /// cerrada.
  Future<DetalleTurno> turnoActual();

  /// Ya abierta es `caja_abierta`.
  Future<Turno> abrirCaja({required int fondo, String? usuarioId});

  /// [tipo]: `ingreso` o `retiro`. Un retiro no puede pasar del esperado.
  Future<({MovimientoCaja movimiento, Turno turno})> registrarMovimientoCaja({
    required String tipo,
    required int monto,
    required String motivo,
    required String claveIdempotencia,
  });

  /// Corte. [nota] es obligatoria si [contado] no coincide con el esperado.
  /// Reintentar con la misma [claveIdempotencia] regresa el mismo corte.
  Future<Turno> cerrarCaja({
    required int contado,
    String? nota,
    String? usuarioId,
    required String claveIdempotencia,
  });

  /// Turnos cerrados, del más nuevo al más viejo. [desde] y [hasta] son días
  /// `AAAA-MM-DD`; sin ellos, los últimos 30.
  Future<List<Turno>> listarCortes({String? desde, String? hasta});

  /// Un turno, abierto o cerrado, con sus movimientos.
  Future<DetalleTurno> obtenerCorte(String id);

  /// Personal, activos e inactivos, por nombre.
  Future<List<Usuario>> listarUsuarios();

  /// El primero debe ser `dueno` y no lleva [pinAutoriza]; los demás sí.
  Future<Usuario> crearUsuario({
    required String nombre,
    required String rol,
    required String pin,
    String? pinAutoriza,
  });

  /// Solo cambia lo que viene. [pinAutoriza] de gerente o dueño.
  Future<Usuario> editarUsuario(
    String id, {
    String? nombre,
    String? rol,
    bool? activo,
    String? pin,
    required String pinAutoriza,
  });

  /// De quién es el PIN; con [usuarioId], que sea de esa persona.
  Future<Usuario> verificarPin(String pin, {String? usuarioId});

  /// Productos por resurtir y por caducar, ya ordenados por urgencia.
  /// [dias]: hasta cuántos días adelante se revisan las caducidades (1 a
  /// 365, por omisión 15, como el Inicio). `dia` es hoy en la hora del negocio.
  Future<({String dia, int dias, List<Alerta> alertas})> listarAlertas({
    int? dias,
  });

  Future<AjustesNegocio> obtenerAjustes();

  /// Reemplaza los campos de [cambios]; `null` borra.
  Future<AjustesNegocio> guardarAjustes(Map<String, String?> cambios);

  /// La base completa como archivo SQLite, con su nombre sugerido.
  Future<({Uint8List bytes, String nombre})> descargarRespaldo();

  Future<CodigoEmparejamiento> crearCodigoEmparejamiento();

  Future<List<Terminal>> listarTerminales();

  Future<void> revocarTerminal(String id);

  /// Cobra en la caja. Reintentar con la misma [claveIdempotencia] regresa
  /// la misma venta en lugar de cobrar otra vez.
  ///
  /// [envModo]: `na`, `cobrar`, `trae` o `prestamo` (con [envCliente]).
  /// [envCredito]: vacíos extra que entrega el cliente, por formato.
  Future<VentaRegistrada> registrarVenta({
    required List<LineaVenta> lineas,
    required String metodo,
    int? recibido,
    String envModo = 'na',
    String? envCliente,
    Map<String, int> envCredito = const {},
    String? usuarioId,
    required String claveIdempotencia,
  });
}

class ApiHttp implements Api {
  ApiHttp({required this.base, required this.clave, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: base.toString(),
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 10),
              headers: {cabeceraClave: clave},
            ),
          );

  @override
  final Uri base;
  @override
  final String clave;
  final Dio _dio;

  /// Registro de una terminal: es público, todavía no hay clave.
  static Future<({Terminal terminal, String clave})> registrarTerminal({
    required Uri base,
    required String nombre,
    required String codigo,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: base.toString(),
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    try {
      final r = await dio.post<Map<String, Object?>>(
        '/api/v1/terminales/registro',
        data: {'nombre': nombre, 'codigo': codigo},
      );
      return (
        terminal: Terminal.fromJson((r.data!['terminal'] as Map).cast()),
        clave: r.data!['clave'] as String,
      );
    } on DioException catch (e) {
      throw FalloApi.desdeDio(e);
    } finally {
      dio.close();
    }
  }

  @override
  Future<List<Producto>> listarProductos() => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/productos');
    return [
      for (final p in r.data!['productos'] as List)
        Producto.fromJson((p as Map).cast()),
    ];
  });

  @override
  Future<Producto> crearProducto(Map<String, Object?> datos) =>
      _pedir(() async {
        final r = await _dio.post<Map<String, Object?>>(
          '/api/v1/productos',
          data: datos,
        );
        return Producto.fromJson(r.data!);
      });

  @override
  Future<Producto?> buscarPorCodigo(String codigo) async {
    try {
      return await _producto(
        _dio.get('/api/v1/productos/codigo/${Uri.encodeComponent(codigo)}'),
      );
    } on FalloApi catch (e) {
      if (e.estado == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Producto> editarProducto(String id, Map<String, Object?> datos) =>
      _producto(_dio.put('/api/v1/productos/$id', data: datos));

  @override
  Future<void> eliminarProducto(String id) =>
      _pedir(() => _dio.delete<void>('/api/v1/productos/$id'));

  @override
  Future<Producto> registrarEntrada(
    String id, {
    int cajas = 0,
    int piezas = 0,
    String? caducidad,
    String? nota,
  }) => _producto(
    _dio.post(
      '/api/v1/productos/$id/entradas',
      data: {
        'cajas': cajas,
        'piezas': piezas,
        'caducidad': ?caducidad,
        'nota': ?nota,
      },
    ),
  );

  @override
  Future<Producto> registrarConteo(
    String id, {
    required int existenciaPiezas,
    String? nota,
  }) => _producto(
    _dio.post(
      '/api/v1/productos/$id/ajustes',
      data: {
        'motivo': 'conteo',
        'existenciaPiezas': existenciaPiezas,
        'nota': ?nota,
      },
    ),
  );

  @override
  Future<Producto> registrarMerma(
    String id, {
    required int piezas,
    String? nota,
  }) => _producto(
    _dio.post(
      '/api/v1/productos/$id/ajustes',
      data: {'motivo': 'merma', 'piezas': piezas, 'nota': ?nota},
    ),
  );

  @override
  Future<List<Movimiento>> listarMovimientos(String id) => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>(
      '/api/v1/productos/$id/movimientos',
    );
    return [
      for (final m in r.data!['movimientos'] as List)
        Movimiento.fromJson((m as Map).cast()),
    ];
  });

  @override
  Future<Producto> subirFoto(String id, Uint8List bytes, String tipo) =>
      _producto(
        _dio.put(
          '/api/v1/productos/$id/foto',
          data: Stream.value(bytes),
          options: Options(
            contentType: tipo,
            headers: {Headers.contentLengthHeader: bytes.length},
          ),
        ),
      );

  @override
  Future<Producto> borrarFoto(String id) =>
      _producto(_dio.delete('/api/v1/productos/$id/foto'));

  @override
  Future<ResultadoImportacion> importarProductos(
    String csv, {
    required bool soloRevisar,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/productos/importar',
      data: {'csv': csv, 'soloRevisar': soloRevisar},
    );
    return ResultadoImportacion.fromJson(r.data!);
  });

  @override
  Future<List<ResumenVenta>> listarVentas({String? turno, String? usuario}) =>
      _pedir(() async {
        final r = await _dio.get<Map<String, Object?>>(
          '/api/v1/ventas',
          queryParameters: {'turno': ?turno, 'usuario': ?usuario},
        );
        return [
          for (final v in r.data!['ventas'] as List)
            ResumenVenta.fromJson((v as Map).cast()),
        ];
      });

  @override
  Future<DetalleVenta> obtenerVenta(String id) => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/ventas/$id');
    return DetalleVenta.fromJson(r.data!);
  });

  @override
  Future<void> cancelarVenta(
    String id, {
    String? pin,
    String destino = 'inventario',
    String? motivo,
  }) => _pedir(
    () => _dio.post<void>(
      '/api/v1/ventas/$id/cancelar',
      data: {'pin': ?pin, 'destino': destino, 'motivo': ?motivo},
    ),
  );

  @override
  Future<({Devolucion devolucion, DetalleVenta venta})> devolverVenta(
    String id, {
    required Map<int, int> lineas,
    String destino = 'inventario',
    String? motivo,
    String? pin,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/ventas/$id/devolver',
      data: {
        'lineas': [
          for (final e in lineas.entries)
            {'lineaId': e.key, 'cantidad': e.value},
        ],
        'destino': destino,
        'motivo': ?motivo,
        'pin': ?pin,
      },
    );
    return (
      devolucion: Devolucion.fromJson((r.data!['devolucion'] as Map).cast()),
      venta: DetalleVenta.fromJson((r.data!['venta'] as Map).cast()),
    );
  });

  @override
  Future<Map<String, BalanceEnvase>> obtenerBalanceEnvases() =>
      _pedir(() async {
        final r = await _dio.get<Map<String, Object?>>('/api/v1/envases');
        return BalanceEnvase.deJson((r.data!['balance'] as Map).cast());
      });

  @override
  Future<List<PrestamoEnvase>> listarPrestamos() => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/envases/prestamos');
    return [
      for (final p in r.data!['prestamos'] as List)
        PrestamoEnvase.fromJson((p as Map).cast()),
    ];
  });

  @override
  Future<PrestamoEnvase> prestarEnvases({
    required String cliente,
    String? telefono,
    required String formato,
    required int cantidad,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/envases/prestamos',
      data: {
        'cliente': cliente,
        'telefono': ?telefono,
        'formato': formato,
        'cantidad': cantidad,
      },
    );
    return PrestamoEnvase.fromJson(r.data!);
  });

  @override
  Future<Map<String, BalanceEnvase>> sacarVacios({
    required String formato,
    required int cantidad,
    required String motivo,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/envases/salida',
      data: {'formato': formato, 'cantidad': cantidad, 'motivo': motivo},
    );
    return BalanceEnvase.deJson((r.data!['balance'] as Map).cast());
  });

  @override
  Future<({Map<String, BalanceEnvase> balance, Turno turno})> devolverDeposito({
    required String formato,
    required int cantidad,
    String? cliente,
    required String claveIdempotencia,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/envases/devolucion-deposito',
      data: {'formato': formato, 'cantidad': cantidad, 'cliente': ?cliente},
      options: Options(headers: {cabeceraIdempotencia: claveIdempotencia}),
    );
    return (
      balance: BalanceEnvase.deJson((r.data!['balance'] as Map).cast()),
      turno: Turno.fromJson((r.data!['turno'] as Map).cast()),
    );
  });

  @override
  Future<List<MovimientoEnvase>> listarMovimientosEnvases({int limite = 50}) =>
      _pedir(() async {
        final r = await _dio.get<Map<String, Object?>>(
          '/api/v1/envases/movimientos',
          queryParameters: {'limite': limite},
        );
        return [
          for (final m in r.data!['movimientos'] as List)
            MovimientoEnvase.fromJson((m as Map).cast()),
        ];
      });

  @override
  Future<void> devolverPrestamo(String id, {int? cantidad}) => _pedir(
    () => _dio.post<void>(
      '/api/v1/envases/prestamos/$id/devolver',
      data: {'cantidad': ?cantidad},
    ),
  );

  @override
  Future<Map<String, BalanceEnvase>> recibirVacios({
    required String formato,
    required int cantidad,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/envases/entrada',
      data: {'formato': formato, 'cantidad': cantidad},
    );
    return BalanceEnvase.deJson((r.data!['balance'] as Map).cast());
  });

  @override
  Future<VentaRegistrada> venderVacios({
    required String formato,
    required int cantidad,
    required String metodo,
    int? recibido,
    required String claveIdempotencia,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/envases/venta-vacios',
      data: {
        'formato': formato,
        'cantidad': cantidad,
        'metodo': metodo,
        'recibido': ?recibido,
      },
      options: Options(headers: {cabeceraIdempotencia: claveIdempotencia}),
    );
    return VentaRegistrada.fromJson(r.data!);
  });

  @override
  Future<DetalleTurno> turnoActual() => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/caja/turno');
    return DetalleTurno.fromJson(r.data!);
  });

  @override
  Future<Turno> abrirCaja({required int fondo, String? usuarioId}) => _turno(
    _dio.post(
      '/api/v1/caja/abrir',
      data: {'fondo': fondo, 'usuarioId': ?usuarioId},
    ),
  );

  @override
  Future<({MovimientoCaja movimiento, Turno turno})> registrarMovimientoCaja({
    required String tipo,
    required int monto,
    required String motivo,
    required String claveIdempotencia,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/caja/movimientos',
      data: {'tipo': tipo, 'monto': monto, 'motivo': motivo},
      options: Options(headers: {cabeceraIdempotencia: claveIdempotencia}),
    );
    return (
      movimiento: MovimientoCaja.fromJson(
        (r.data!['movimiento'] as Map).cast(),
      ),
      turno: Turno.fromJson((r.data!['turno'] as Map).cast()),
    );
  });

  @override
  Future<Turno> cerrarCaja({
    required int contado,
    String? nota,
    String? usuarioId,
    required String claveIdempotencia,
  }) => _turno(
    _dio.post(
      '/api/v1/caja/cerrar',
      data: {'contado': contado, 'nota': ?nota, 'usuarioId': ?usuarioId},
      options: Options(headers: {cabeceraIdempotencia: claveIdempotencia}),
    ),
  );

  @override
  Future<List<Turno>> listarCortes({String? desde, String? hasta}) =>
      _pedir(() async {
        final r = await _dio.get<Map<String, Object?>>(
          '/api/v1/caja/cortes',
          queryParameters: {'desde': ?desde, 'hasta': ?hasta},
        );
        return [
          for (final t in r.data!['cortes'] as List)
            Turno.fromJson((t as Map).cast()),
        ];
      });

  @override
  Future<DetalleTurno> obtenerCorte(String id) => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/caja/cortes/$id');
    return DetalleTurno.fromJson(r.data!);
  });

  @override
  Future<List<Usuario>> listarUsuarios() => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/usuarios');
    return [
      for (final u in r.data!['usuarios'] as List)
        Usuario.fromJson((u as Map).cast()),
    ];
  });

  @override
  Future<Usuario> crearUsuario({
    required String nombre,
    required String rol,
    required String pin,
    String? pinAutoriza,
  }) => _usuario(
    _dio.post(
      '/api/v1/usuarios',
      data: {
        'nombre': nombre,
        'rol': rol,
        'pin': pin,
        'pinAutoriza': ?pinAutoriza,
      },
    ),
  );

  @override
  Future<Usuario> editarUsuario(
    String id, {
    String? nombre,
    String? rol,
    bool? activo,
    String? pin,
    required String pinAutoriza,
  }) => _usuario(
    _dio.put(
      '/api/v1/usuarios/$id',
      data: {
        'nombre': ?nombre,
        'rol': ?rol,
        'activo': ?activo,
        'pin': ?pin,
        'pinAutoriza': pinAutoriza,
      },
    ),
  );

  @override
  Future<Usuario> verificarPin(String pin, {String? usuarioId}) => _usuario(
    _dio.post(
      '/api/v1/usuarios/verificar',
      data: {'pin': pin, 'usuarioId': ?usuarioId},
    ),
  );

  @override
  Future<({String dia, int dias, List<Alerta> alertas})> listarAlertas({
    int? dias,
  }) => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>(
      '/api/v1/alertas',
      queryParameters: {'dias': ?dias},
    );
    return (
      dia: r.data!['dia'] as String,
      dias: r.data!['dias'] as int,
      alertas: [
        for (final a in r.data!['alertas'] as List)
          Alerta.fromJson((a as Map).cast()),
      ],
    );
  });

  @override
  Future<AjustesNegocio> obtenerAjustes() => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/ajustes');
    return AjustesNegocio.fromJson(r.data!);
  });

  @override
  Future<AjustesNegocio> guardarAjustes(Map<String, String?> cambios) =>
      _pedir(() async {
        final r = await _dio.put<Map<String, Object?>>(
          '/api/v1/ajustes',
          data: cambios,
        );
        return AjustesNegocio.fromJson(r.data!);
      });

  @override
  Future<({Uint8List bytes, String nombre})> descargarRespaldo() =>
      _pedir(() async {
        final r = await _dio.get<List<int>>(
          '/api/v1/respaldo',
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 2),
          ),
        );
        final disposicion = r.headers.value('content-disposition') ?? '';
        final nombre =
            RegExp('filename="([^"]+)"').firstMatch(disposicion)?[1] ??
            'anaquel.db';
        return (bytes: Uint8List.fromList(r.data!), nombre: nombre);
      });

  @override
  Future<CodigoEmparejamiento> crearCodigoEmparejamiento() => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/terminales/codigo',
    );
    return CodigoEmparejamiento.fromJson(r.data!);
  });

  @override
  Future<List<Terminal>> listarTerminales() => _pedir(() async {
    final r = await _dio.get<Map<String, Object?>>('/api/v1/terminales');
    return [
      for (final t in r.data!['terminales'] as List)
        Terminal.fromJson((t as Map).cast()),
    ];
  });

  @override
  Future<void> revocarTerminal(String id) =>
      _pedir(() => _dio.delete<void>('/api/v1/terminales/$id'));

  @override
  Future<VentaRegistrada> registrarVenta({
    required List<LineaVenta> lineas,
    required String metodo,
    int? recibido,
    String envModo = 'na',
    String? envCliente,
    Map<String, int> envCredito = const {},
    String? usuarioId,
    required String claveIdempotencia,
  }) => _pedir(() async {
    final r = await _dio.post<Map<String, Object?>>(
      '/api/v1/ventas',
      data: {
        'metodo': metodo,
        'recibido': ?recibido,
        'envModo': envModo,
        'envCliente': ?envCliente,
        if (envCredito.isNotEmpty) 'envCredito': envCredito,
        'usuarioId': ?usuarioId,
        'lineas': [for (final l in lineas) l.toJson()],
      },
      options: Options(headers: {cabeceraIdempotencia: claveIdempotencia}),
    );
    return VentaRegistrada.fromJson(r.data!);
  });

  /// Peticiones que responden `{ "usuario": <usuario> }`.
  Future<Usuario> _usuario(Future<Response<Map<String, Object?>>> peticion) =>
      _pedir(
        () async =>
            Usuario.fromJson(((await peticion).data!['usuario'] as Map).cast()),
      );

  /// Peticiones que responden `{ "turno": <turno> }`.
  Future<Turno> _turno(Future<Response<Map<String, Object?>>> peticion) =>
      _pedir(
        () async =>
            Turno.fromJson(((await peticion).data!['turno'] as Map).cast()),
      );

  /// Peticiones que responden un producto.
  Future<Producto> _producto(Future<Response<Map<String, Object?>>> peticion) =>
      _pedir(() async => Producto.fromJson((await peticion).data!));

  Future<T> _pedir<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on DioException catch (e) {
      throw FalloApi.desdeDio(e);
    }
  }
}
