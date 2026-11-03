import 'dart:typed_data';

import 'package:deposito_backend/deposito_backend.dart';

import 'api.dart';
import 'fallo_api.dart';

/// Datos de prueba con la forma exacta del contrato. Sirve para pruebas de
/// widgets y para programar pantallas antes de que exista su endpoint.
class ApiFalsa implements Api {
  ApiFalsa({
    List<Producto>? productos,
    List<Terminal>? terminales,
    Map<String, BalanceEnvase>? envases,
    List<PrestamoEnvase>? prestamos,
    bool cajaAbierta = true,
  }) : productos = productos ?? productosDePrueba(),
       terminales = terminales ?? [],
       envases = envases ?? balanceDePrueba(prestamos: prestamos ?? []),
       prestamos = prestamos ?? [] {
    // Como el servidor con datos de ejemplo: se puede cobrar desde el inicio.
    if (cajaAbierta) _abrir(fondoDePrueba);
  }

  final List<Producto> productos;
  final List<Terminal> terminales;
  final Map<String, BalanceEnvase> envases;
  final List<PrestamoEnvase> prestamos;

  @override
  Uri get base => Uri.parse('http://127.0.0.1:8080');

  @override
  String get clave => 'clave-falsa';

  @override
  Future<List<Producto>> listarProductos() async => List.of(productos);

  @override
  Future<Producto> crearProducto(Map<String, Object?> datos) async {
    final p = Producto.fromJson({
      'id': 'p_${productos.length + 1}',
      'existenciaPiezas': 0,
      'minimo': 0,
      'creado': '2026-10-02T18:30:00Z',
      'actualizado': '2026-10-02T18:30:00Z',
      ...datos,
    });
    productos.add(p);
    return p;
  }

  /// Movimientos registrados por las operaciones de esta API falsa.
  final movimientos = <String, List<Movimiento>>{};

  @override
  Future<Producto?> buscarPorCodigo(String codigo) async =>
      productos.where((p) => p.codigo == codigo).firstOrNull;

  @override
  Future<Producto> editarProducto(String id, Map<String, Object?> datos) async {
    final p = _producto(id);
    return _reemplazar({
      ...p.toJson(),
      ...datos,
      'id': id,
      'existenciaPiezas': p.existenciaPiezas,
      'foto': p.foto,
    });
  }

  @override
  Future<void> eliminarProducto(String id) async {
    _producto(id);
    productos.removeWhere((p) => p.id == id);
  }

  @override
  Future<Producto> registrarEntrada(
    String id, {
    int cajas = 0,
    int piezas = 0,
    String? caducidad,
    String? nota,
  }) async {
    final p = _producto(id);
    final total = cajas * (p.piezasPorCaja ?? 0) + piezas;
    if (total <= 0) {
      throw const FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'piezas': 'La entrada debe tener al menos una pieza'},
        estado: 400,
      );
    }
    final antes = p.caducidad;
    final usarNueva =
        caducidad != null &&
        (p.existenciaPiezas == 0 ||
            antes == null ||
            caducidad.compareTo(antes) < 0);
    return _moverExistencia(
      p,
      'entrada',
      total,
      nota: nota,
      caducidad: usarNueva ? caducidad : antes,
    );
  }

  @override
  Future<Producto> registrarConteo(
    String id, {
    required int existenciaPiezas,
    String? nota,
  }) async {
    final p = _producto(id);
    final diferencia = existenciaPiezas - p.existenciaPiezas;
    if (diferencia == 0) return p;
    return _moverExistencia(p, 'ajuste', diferencia, nota: nota);
  }

  @override
  Future<Producto> registrarMerma(
    String id, {
    required int piezas,
    String? nota,
  }) async {
    final p = _producto(id);
    if (piezas > p.existenciaPiezas) {
      throw FalloApi(
        'stock_insuficiente',
        'No hay suficiente ${p.nombre}: quedan ${p.existenciaPiezas} piezas',
        estado: 409,
      );
    }
    return _moverExistencia(p, 'merma', -piezas, nota: nota);
  }

  @override
  Future<List<Movimiento>> listarMovimientos(String id) async {
    _producto(id);
    return List.of(movimientos[id] ?? const <Movimiento>[]).reversed.toList();
  }

  @override
  Future<Producto> subirFoto(String id, Uint8List bytes, String tipo) async =>
      _reemplazar({
        ..._producto(id).toJson(),
        'foto': '/api/v1/productos/$id/foto?v=${bytes.length}',
      });

  @override
  Future<Producto> borrarFoto(String id) async =>
      _reemplazar({..._producto(id).toJson(), 'foto': null});

  /// Versión simple del servidor: lee el archivo con las mismas reglas,
  /// pero de la validación de cada producto solo revisa los obligatorios.
  @override
  Future<ResultadoImportacion> importarProductos(
    String csv, {
    required bool soloRevisar,
  }) async {
    final List<RenglonInventario> renglones;
    try {
      renglones = leerInventario(csv);
    } on FormatException catch (e) {
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'csv': e.message},
      );
    }
    final errores = <ErrorRenglon>[];
    final cambios = <CambioExistencia>[];
    final nuevos = <Map<String, Object?>>[];
    final editados = <Map<String, Object?>>[];
    final vistos = <String>{};
    var sinCambios = 0;
    for (final r in renglones) {
      final codigo = r.codigo;
      final fallas = {
        ...r.errores,
        for (final c in columnasObligatoriasCsv)
          if (r.valores[c] == null) c: 'Es obligatorio',
        if (codigo != null && !vistos.add(codigo)) 'codigo': 'Repetido',
      };
      if (fallas.isNotEmpty) {
        errores.add(
          ErrorRenglon(renglon: r.renglon, codigo: codigo, campos: fallas),
        );
        continue;
      }
      final actual = productos.where((p) => p.codigo == codigo).firstOrNull;
      final existencia = r.valores['existencia'] as int?;
      final valores = {...r.valores}..remove('existencia');
      if (actual == null) {
        nuevos.add({...valores, 'existenciaPiezas': ?existencia});
        continue;
      }
      final json = {
        ...actual.toJson(),
        ...valores,
        'existenciaPiezas': existencia ?? actual.existenciaPiezas,
      };
      if (json.entries.every((e) => actual.toJson()[e.key] == e.value)) {
        sinCambios++;
        continue;
      }
      if (existencia != null && existencia != actual.existenciaPiezas) {
        cambios.add(
          CambioExistencia(
            renglon: r.renglon,
            codigo: actual.codigo,
            nombre: json['nombre'] as String,
            antes: actual.existenciaPiezas,
            despues: existencia,
          ),
        );
      }
      editados.add(json);
    }
    final guardar = errores.isEmpty && !soloRevisar;
    if (guardar) {
      for (final datos in nuevos) {
        await crearProducto(datos);
      }
      editados.forEach(_reemplazar);
    }
    return ResultadoImportacion(
      guardado: guardar,
      creados: nuevos.length,
      actualizados: editados.length,
      sinCambios: sinCambios,
      cambiosExistencia: cambios,
      errores: errores,
    );
  }

  Producto _producto(String id) =>
      productos.where((p) => p.id == id).firstOrNull ??
      (throw const FalloApi(
        'no_encontrado',
        'No existe el producto',
        estado: 404,
      ));

  Producto _reemplazar(Map<String, Object?> json) {
    final p = Producto.fromJson(json);
    productos[productos.indexWhere((x) => x.id == p.id)] = p;
    return p;
  }

  Producto _moverExistencia(
    Producto p,
    String tipo,
    int piezas, {
    String? nota,
    String? caducidad,
  }) {
    final nueva = p.existenciaPiezas + piezas;
    final lista = movimientos.putIfAbsent(p.id, () => []);
    lista.add(
      Movimiento(
        id: lista.length + 1,
        tipo: tipo,
        piezas: piezas,
        existenciaResultante: nueva,
        origen: 'Caja',
        nota: nota,
        fecha: '2026-10-02T18:30:00Z',
      ),
    );
    return _reemplazar({
      ...p.toJson(),
      'existenciaPiezas': nueva,
      if (tipo == 'entrada') 'caducidad': caducidad,
    });
  }

  @override
  Future<CodigoEmparejamiento> crearCodigoEmparejamiento() async =>
      CodigoEmparejamiento(
        codigo: '482913',
        expira: instanteIso(DateTime.now().add(const Duration(minutes: 10))),
      );

  @override
  Future<List<Terminal>> listarTerminales() async => List.of(terminales);

  @override
  Future<void> revocarTerminal(String id) async =>
      terminales.removeWhere((t) => t.id == id);

  /// Ventas cobradas, por clave de idempotencia.
  final ventas = <String, VentaRegistrada>{};

  /// Tickets cobrados, del más nuevo al más viejo.
  final detalles = <DetalleVenta>[];

  /// Vacíos de crédito de cada venta, para revertirlos al cancelar.
  final _creditos = <String, Map<String, int>>{};

  /// Depósito cobrado por pieza en cada línea (`ventaId:lineaId`).
  final _depositos = <String, int>{};
  var _lineas = 0;
  var _devoluciones = 0;

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
  }) async {
    final repetida = ventas[claveIdempotencia];
    if (repetida != null) return repetida;
    final turnoId = _turnoAbiertoId();
    final usuario = _usuarioActivo(usuarioId);

    var total = 0;
    var envN = 0;
    var envMonto = 0;
    final piezas = <String, int>{};
    final envPorFormato = <String, int>{};
    final lineasTicket = <LineaTicket>[];
    final depositos = <int, int>{};
    for (final l in lineas) {
      final p = productos.firstWhere((p) => p.id == l.productoId);
      final lista = l.porCaja ? p.precioCaja! : p.precio;
      final precio = lista - lista * l.descuento ~/ 100;
      final n = (l.porCaja ? p.piezasPorCaja! : 1) * l.cantidad;
      total += precio * l.cantidad;
      piezas[p.id] = (piezas[p.id] ?? 0) + n;
      if (p.envase != null) {
        envN += n;
        envPorFormato[p.envase!] = (envPorFormato[p.envase!] ?? 0) + n;
      }
      final lineaId = ++_lineas;
      final deposito = envModo == 'cobrar' && p.envase != null
          ? envases[p.envase!]!.precio
          : 0;
      if (deposito > 0) {
        depositos[lineaId] = deposito;
        envMonto += deposito * n;
      }
      lineasTicket.add(
        LineaTicket(
          lineaId: lineaId,
          productoId: p.id,
          nombre: p.nombre,
          unidad: l.porCaja ? 'caja' : 'pieza',
          cantidad: l.cantidad,
          piezas: n,
          precioLista: lista,
          descuento: l.descuento,
          precioUnit: precio,
          subtotal: precio * l.cantidad,
          deposito: deposito,
        ),
      );
    }
    for (final e in piezas.entries) {
      final p = _producto(e.key);
      if (p.existenciaPiezas < e.value) {
        throw FalloApi(
          'stock_insuficiente',
          'No hay suficiente ${p.nombre}: quedan ${p.existenciaPiezas} piezas',
          estado: 409,
        );
      }
    }
    total += envMonto;
    final credito = {
      for (final e in envCredito.entries)
        if (e.value > 0) e.key: e.value,
    };
    final envCreditoMonto = credito.entries.fold(
      0,
      (t, e) => t + e.value * envases[e.key]!.precio,
    );
    if (envCreditoMonto > total) {
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {
          'envCredito':
              'El crédito ($envCreditoMonto) pasa del total ($total): usa '
              'Devolver depósito',
        },
        estado: 400,
      );
    }
    total -= envCreditoMonto;

    final venta = _cobrar(
      claveIdempotencia: claveIdempotencia,
      turnoId: turnoId,
      total: total,
      metodo: metodo,
      recibido: recibido,
      envModo: envModo,
      envN: envN,
      envMonto: envMonto,
      envCredito: envCreditoMonto,
      usuario: usuario,
      lineas: lineasTicket,
    );
    for (final e in piezas.entries) {
      final p = _producto(e.key);
      _reemplazar({
        ...p.toJson(),
        'existenciaPiezas': p.existenciaPiezas - e.value,
      });
    }
    depositos.forEach((linea, d) => _depositos['${venta.id}:$linea'] = d);
    if (envModo == 'trae') {
      envPorFormato.forEach((f, n) => _moverEnvases(f, bodega: n));
    } else if (envModo == 'prestamo') {
      envPorFormato.forEach((f, n) {
        prestamos.insert(
          0,
          PrestamoEnvase(
            id: 'pre_${prestamos.length + 1}',
            cliente: envCliente ?? 'Cliente Mostrador',
            formato: f,
            cantidad: n,
            fecha: '2026-10-02T18:30:00Z',
          ),
        );
        _moverEnvases(f, prestados: n);
      });
    }
    credito.forEach((f, n) => _moverEnvases(f, bodega: n));
    _creditos[venta.id] = credito;
    return venta;
  }

  VentaRegistrada _cobrar({
    required String claveIdempotencia,
    required String turnoId,
    required int total,
    required String metodo,
    required int? recibido,
    required String envModo,
    required int envN,
    required int envMonto,
    int envCredito = 0,
    Usuario? usuario,
    required List<LineaTicket> lineas,
  }) {
    final pagado = metodo == 'tarjeta' ? total : (recibido ?? total);
    if (pagado < total) {
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {
          'recibido': 'Recibido ($pagado) es menor que el total ($total)',
        },
        estado: 400,
      );
    }
    final venta = VentaRegistrada(
      id: 'v_${ventas.length + 1}',
      folio: 1001 + ventas.length,
      fecha: '2026-10-02T18:30:00Z',
      diaNegocio: '2026-10-02',
      total: total,
      metodo: metodo,
      recibido: pagado,
      cambio: pagado - total,
      turnoId: turnoId,
    );
    ventas[claveIdempotencia] = venta;
    detalles.insert(
      0,
      DetalleVenta(
        id: venta.id,
        folio: venta.folio,
        fecha: venta.fecha,
        diaNegocio: venta.diaNegocio,
        total: total,
        metodo: metodo,
        recibido: pagado,
        cambio: pagado - total,
        envModo: envModo,
        envN: envN,
        envMonto: envMonto,
        envCredito: envCredito,
        origen: 'Caja',
        cancelada: false,
        turnoId: turnoId,
        usuario: usuario == null
            ? null
            : UsuarioBreve(id: usuario.id, nombre: usuario.nombre),
        lineas: lineas,
      ),
    );
    return venta;
  }

  @override
  Future<List<ResumenVenta>> listarVentas({
    String? turno,
    String? usuario,
  }) async {
    final turnoId = turno == 'actual' ? _abierto?.id : turno;
    if (turno != null && turnoId == null) return [];
    return [
      for (final d in detalles)
        if ((turnoId == null || d.turnoId == turnoId) &&
            (usuario == null || d.usuario?.id == usuario))
          ResumenVenta(
            id: d.id,
            folio: d.folio,
            fecha: d.fecha,
            total: d.total,
            metodo: d.metodo,
            origen: d.origen,
            cancelada: d.cancelada,
            turnoId: d.turnoId,
            devuelto: d.devuelto,
            usuario: d.usuario,
          ),
    ];
  }

  @override
  Future<DetalleVenta> obtenerVenta(String id) async => _detalle(id);

  @override
  Future<void> cancelarVenta(
    String id, {
    String? pin,
    String destino = 'inventario',
    String? motivo,
  }) async {
    final d = _devolvible(id);
    final autorizo = _autorizar(pin);
    _devolver(d, null, destino, motivo, autorizo);
  }

  @override
  Future<({Devolucion devolucion, DetalleVenta venta})> devolverVenta(
    String id, {
    required Map<int, int> lineas,
    String destino = 'inventario',
    String? motivo,
    String? pin,
  }) async {
    final d = _devolvible(id);
    final autorizo = _autorizar(pin);
    final devolucion = _devolver(d, lineas, destino, motivo, autorizo);
    return (devolucion: devolucion, venta: _detalle(id));
  }

  DetalleVenta _devolvible(String id) {
    final d = _detalle(id);
    if (d.cancelada) {
      throw const FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'cancelada': 'La venta ya fue cancelada'},
        estado: 400,
      );
    }
    if (d.turnoId == null || d.turnoId != _abierto?.id) {
      throw const FalloApi(
        'turno_cerrado',
        'La venta es de un turno que ya tiene corte: no se puede cancelar',
        estado: 409,
      );
    }
    return d;
  }

  /// Como `_devolver` del servidor: [pedidas] `null` es todo lo que falta.
  Devolucion _devolver(
    DetalleVenta d,
    Map<int, int>? pedidas,
    String destino,
    String? motivo,
    Usuario? autorizo,
  ) {
    final aDevolver = <int, int>{};
    for (final l in d.lineas) {
      final pedida = pedidas == null ? l.porDevolver : pedidas[l.lineaId];
      if (pedida == null || pedida == 0) continue;
      if (pedida > l.porDevolver) {
        throw FalloApi(
          'datos_invalidos',
          'Revisa los campos marcados',
          campos: {
            'lineas':
                'De ${l.nombre} solo faltan ${l.porDevolver} por devolver',
          },
          estado: 400,
        );
      }
      aDevolver[l.lineaId] = pedida;
    }
    if (pedidas != null) {
      for (final id in pedidas.keys) {
        if (!d.lineas.any((l) => l.lineaId == id)) {
          throw FalloApi(
            'datos_invalidos',
            'Revisa los campos marcados',
            campos: {'lineas': 'La línea $id no es de esta venta'},
            estado: 400,
          );
        }
      }
    }
    final completa = d.lineas.every(
      (l) => l.porDevolver == (aDevolver[l.lineaId] ?? 0),
    );

    var monto = 0;
    final envPorFormato = <String, int>{};
    final lineas = [
      for (final l in d.lineas)
        if (aDevolver[l.lineaId] case final n?)
          LineaTicket.fromJson({...l.toJson(), 'devueltas': l.devueltas + n})
        else
          l,
    ];
    for (final l in d.lineas) {
      final n = aDevolver[l.lineaId];
      if (n == null) continue;
      final piezas = l.piezas ~/ l.cantidad * n;
      monto +=
          l.precioUnit * n + (_depositos['${d.id}:${l.lineaId}'] ?? 0) * piezas;
      final i = productos.indexWhere((p) => p.id == l.productoId);
      if (i < 0) continue;
      final p = productos[i];
      if (destino == 'inventario') {
        productos[i] = Producto.fromJson({
          ...p.toJson(),
          'existenciaPiezas': p.existenciaPiezas + piezas,
        });
      }
      if (p.envase != null) {
        envPorFormato[p.envase!] = (envPorFormato[p.envase!] ?? 0) + piezas;
      }
    }
    if (d.envModo == 'trae') {
      envPorFormato.forEach((f, n) => _moverEnvases(f, bodega: -n));
    } else if (d.envModo == 'prestamo') {
      envPorFormato.forEach((f, n) => _moverEnvases(f, prestados: -n));
    }
    if (completa) {
      monto = d.total - d.devuelto;
      _creditos[d.id]?.forEach((f, n) => _moverEnvases(f, bodega: -n));
    }

    final devolucion = Devolucion(
      id: 'dev_${++_devoluciones}',
      fecha: '2026-10-02T19:00:00Z',
      monto: monto,
      destino: destino,
      motivo: motivo,
      autorizo: autorizo == null
          ? null
          : UsuarioBreve(id: autorizo.id, nombre: autorizo.nombre),
    );
    detalles[detalles.indexOf(d)] = DetalleVenta.fromJson({
      ...d.toJson(),
      'cancelada': completa,
      'devuelto': d.devuelto + monto,
      'lineas': [for (final l in lineas) l.toJson()],
      'devoluciones': [
        for (final x in d.devoluciones) x.toJson(),
        devolucion.toJson(),
      ],
    });
    return devolucion;
  }

  DetalleVenta _detalle(String id) =>
      detalles.where((d) => d.id == id).firstOrNull ??
      (throw const FalloApi(
        'no_encontrado',
        'No existe la venta',
        estado: 404,
      ));

  // --- Envases ---

  @override
  Future<Map<String, BalanceEnvase>> obtenerBalanceEnvases() async =>
      Map.of(envases);

  @override
  Future<List<PrestamoEnvase>> listarPrestamos() async => List.of(prestamos);

  /// Bitácora de envases de esta API falsa, del más nuevo al más viejo.
  final movimientosEnvases = <MovimientoEnvase>[];

  @override
  Future<List<MovimientoEnvase>> listarMovimientosEnvases({
    int limite = 50,
  }) async => movimientosEnvases.take(limite).toList();

  @override
  Future<PrestamoEnvase> prestarEnvases({
    required String cliente,
    String? telefono,
    required String formato,
    required int cantidad,
  }) async {
    _sacarDeBodega(formato, cantidad);
    final p = PrestamoEnvase(
      id: 'pre_${prestamos.length + 1}',
      cliente: cliente.trim(),
      telefono: telefono,
      formato: formato,
      cantidad: cantidad,
      fecha: '2026-10-02T18:30:00Z',
    );
    prestamos.insert(0, p);
    _moverEnvases(formato, prestados: cantidad);
    _bitacora(
      formato,
      'prestamo',
      bodega: -cantidad,
      prestados: cantidad,
      cliente: p.cliente,
    );
    return p;
  }

  @override
  Future<void> devolverPrestamo(String id, {int? cantidad}) async {
    final p =
        prestamos.where((p) => p.id == id).firstOrNull ??
        (throw const FalloApi(
          'no_encontrado',
          'No existe el préstamo',
          estado: 404,
        ));
    final n = cantidad ?? p.cantidad;
    if (n < 1 || n > p.cantidad) {
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'cantidad': 'Solo faltan ${p.cantidad} envases por devolver'},
        estado: 400,
      );
    }
    final i = prestamos.indexOf(p);
    if (n == p.cantidad) {
      prestamos.removeAt(i);
    } else {
      prestamos[i] = PrestamoEnvase(
        id: p.id,
        cliente: p.cliente,
        telefono: p.telefono,
        formato: p.formato,
        cantidad: p.cantidad - n,
        devueltos: p.devueltos + n,
        fecha: p.fecha,
      );
    }
    _moverEnvases(p.formato, bodega: n, prestados: -n);
    _bitacora(
      p.formato,
      'devolucion_prestamo',
      bodega: n,
      prestados: -n,
      cliente: p.cliente,
    );
  }

  @override
  Future<VentaRegistrada> venderVacios({
    required String formato,
    required int cantidad,
    required String metodo,
    int? recibido,
    required String claveIdempotencia,
  }) async {
    final repetida = ventas[claveIdempotencia];
    if (repetida != null) return repetida;
    final turnoId = _turnoAbiertoId();
    final total = cantidad * envases[formato]!.precio;
    _sacarDeBodega(formato, cantidad);
    final venta = _cobrar(
      claveIdempotencia: claveIdempotencia,
      turnoId: turnoId,
      total: total,
      metodo: metodo,
      recibido: recibido,
      envModo: 'cobrar',
      envN: cantidad,
      envMonto: total,
      lineas: const [],
    );
    _bitacora(
      formato,
      'venta_vacios',
      bodega: -cantidad,
      monto: total,
      referencia: 'Folio ${venta.folio}',
    );
    return venta;
  }

  @override
  Future<Map<String, BalanceEnvase>> recibirVacios({
    required String formato,
    required int cantidad,
  }) async {
    _moverEnvases(formato, bodega: cantidad);
    _bitacora(formato, 'entrada', bodega: cantidad);
    return Map.of(envases);
  }

  @override
  Future<Map<String, BalanceEnvase>> sacarVacios({
    required String formato,
    required int cantidad,
    required String motivo,
  }) async {
    _sacarDeBodega(formato, cantidad);
    _bitacora(formato, 'salida', bodega: -cantidad, referencia: motivo);
    return Map.of(envases);
  }

  @override
  Future<({Map<String, BalanceEnvase> balance, Turno turno})> devolverDeposito({
    required String formato,
    required int cantidad,
    String? cliente,
    required String claveIdempotencia,
  }) async {
    final monto = cantidad * envases[formato]!.precio;
    final mov = await registrarMovimientoCaja(
      tipo: 'retiro',
      monto: monto,
      motivo:
          'Devolución de depósito: $cantidad $formato'
          '${cliente == null ? '' : ' - $cliente'}',
      claveIdempotencia: claveIdempotencia,
    );
    _moverEnvases(formato, bodega: cantidad);
    _bitacora(
      formato,
      'devolucion_deposito',
      bodega: cantidad,
      cliente: cliente,
      monto: -monto,
    );
    return (balance: Map.of(envases), turno: mov.turno);
  }

  void _sacarDeBodega(String formato, int cantidad) {
    final enBodega = envases[formato]!.bodega;
    if (enBodega < cantidad) {
      throw FalloApi(
        'envases_insuficientes',
        'No hay suficientes envases $formato vacíos: quedan $enBodega en '
            'bodega',
        estado: 409,
      );
    }
    _moverEnvases(formato, bodega: -cantidad);
  }

  void _bitacora(
    String formato,
    String tipo, {
    int bodega = 0,
    int prestados = 0,
    String? cliente,
    int? monto,
    String? referencia,
  }) => movimientosEnvases.insert(
    0,
    MovimientoEnvase(
      id: movimientosEnvases.length + 1,
      fecha: '2026-10-02T18:30:00Z',
      formato: formato,
      tipo: tipo,
      bodega: bodega,
      prestados: prestados,
      cliente: cliente,
      monto: monto,
      referencia: referencia,
    ),
  );

  // --- Caja ---

  _TurnoFalso? _abierto;
  final _cortes = <_TurnoFalso>[];
  var _turnos = 0;
  var _movimientos = 0;

  /// Respuestas de movimientos y cierres, por clave de idempotencia.
  final _respuestasCaja = <String, Object>{};

  String _turnoAbiertoId() =>
      _abierto?.id ??
      (throw const FalloApi(
        'caja_cerrada',
        'La caja está cerrada: abre un turno para continuar',
        estado: 409,
      ));

  _TurnoFalso _abrir(int fondo, [Usuario? usuario]) {
    return _abierto = _TurnoFalso('tur_${++_turnos}', fondo, usuario);
  }

  Turno _turno(_TurnoFalso t) {
    final propias = [
      for (final d in detalles)
        if (d.turnoId == t.id) d,
    ];
    int suma(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
    int cobrado(String metodo) => suma([
      for (final d in propias)
        if (d.metodo == metodo) d.total,
    ]);
    int devuelto(String metodo) => suma([
      for (final d in propias)
        if (d.metodo == metodo) d.devuelto,
    ]);
    final efectivo = cobrado('efectivo') - devuelto('efectivo');
    final ingresos = suma([
      for (final m in t.movimientos)
        if (m.tipo == 'ingreso') m.monto,
    ]);
    final retiros = suma([
      for (final m in t.movimientos)
        if (m.tipo == 'retiro') m.monto,
    ]);
    final esperado = t.fondo + efectivo + ingresos - retiros;
    UsuarioBreve? breve(Usuario? u) =>
        u == null ? null : UsuarioBreve(id: u.id, nombre: u.nombre);
    return Turno(
      id: t.id,
      estado: t.contado == null ? 'abierto' : 'cerrado',
      apertura: '2026-10-02T14:00:00Z',
      cierre: t.contado == null ? null : '2026-10-02T23:00:00Z',
      diaNegocio: '2026-10-02',
      fondo: t.fondo,
      resumen: ResumenTurno(
        ventas: propias.where((d) => !d.cancelada).length,
        canceladas: propias.where((d) => d.cancelada).length,
        ventasEfectivo: efectivo,
        ventasTarjeta: cobrado('tarjeta') - devuelto('tarjeta'),
        envases: suma([
          for (final d in propias)
            if (!d.cancelada) d.envMonto - d.envCredito,
        ]),
        devoluciones: devuelto('efectivo') + devuelto('tarjeta'),
        ingresos: ingresos,
        retiros: retiros,
        esperado: esperado,
      ),
      contado: t.contado,
      diferencia: t.contado == null ? null : t.contado! - esperado,
      nota: t.nota,
      usuarioApertura: breve(t.usuarioApertura),
      usuarioCierre: breve(t.usuarioCierre),
    );
  }

  @override
  Future<DetalleTurno> turnoActual() async {
    final t = _abierto;
    if (t == null) return const DetalleTurno(turno: null, movimientos: []);
    return DetalleTurno(turno: _turno(t), movimientos: List.of(t.movimientos));
  }

  @override
  Future<Turno> abrirCaja({required int fondo, String? usuarioId}) async {
    if (_abierto != null) {
      throw const FalloApi(
        'caja_abierta',
        'Ya hay un turno de caja abierto',
        estado: 409,
      );
    }
    return _turno(_abrir(fondo, _usuarioActivo(usuarioId)));
  }

  @override
  Future<({MovimientoCaja movimiento, Turno turno})> registrarMovimientoCaja({
    required String tipo,
    required int monto,
    required String motivo,
    required String claveIdempotencia,
  }) async {
    final repetida = _respuestasCaja[claveIdempotencia];
    if (repetida != null) {
      return repetida as ({MovimientoCaja movimiento, Turno turno});
    }
    _turnoAbiertoId();
    final t = _abierto!;
    if (tipo == 'retiro' && monto > _turno(t).resumen.esperado) {
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {
          'monto':
              'El retiro ($monto) es mayor que el efectivo esperado en '
              'caja (${_turno(t).resumen.esperado})',
        },
        estado: 400,
      );
    }
    final m = MovimientoCaja(
      id: 'mc_${++_movimientos}',
      tipo: tipo,
      monto: monto,
      motivo: motivo.trim(),
      fecha: '2026-10-02T18:30:00Z',
    );
    t.movimientos.add(m);
    final r = (movimiento: m, turno: _turno(t));
    _respuestasCaja[claveIdempotencia] = r;
    return r;
  }

  @override
  Future<Turno> cerrarCaja({
    required int contado,
    String? nota,
    String? usuarioId,
    required String claveIdempotencia,
  }) async {
    final repetida = _respuestasCaja[claveIdempotencia];
    if (repetida != null) return repetida as Turno;
    _turnoAbiertoId();
    final t = _abierto!;
    final esperado = _turno(t).resumen.esperado;
    final textoNota = nota?.trim();
    if (contado != esperado && (textoNota == null || textoNota.isEmpty)) {
      final diferencia = contado - esperado;
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {
          'nota':
              'Explica la diferencia: hay '
              '${diferencia < 0 ? 'un faltante' : 'un sobrante'} de '
              '${diferencia.abs()} centavos',
        },
        estado: 400,
      );
    }
    t
      ..contado = contado
      ..nota = textoNota
      ..usuarioCierre = _usuarioActivo(usuarioId);
    _abierto = null;
    _cortes.insert(0, t);
    final corte = _turno(t);
    _respuestasCaja[claveIdempotencia] = corte;
    return corte;
  }

  @override
  Future<List<Turno>> listarCortes({String? desde, String? hasta}) async => [
    for (final t in _cortes) _turno(t),
  ];

  @override
  Future<DetalleTurno> obtenerCorte(String id) async {
    final t =
        [?_abierto, ..._cortes].where((t) => t.id == id).firstOrNull ??
        (throw const FalloApi(
          'no_encontrado',
          'No existe el turno',
          estado: 404,
        ));
    return DetalleTurno(turno: _turno(t), movimientos: List.of(t.movimientos));
  }

  // --- Usuarios ---

  /// Personal y su PIN, en el orden en que se dio de alta.
  final usuarios = <({Usuario usuario, String pin})>[];

  Usuario? _usuarioActivo(String? id) {
    if (id == null) return null;
    final u = usuarios.where((u) => u.usuario.id == id).firstOrNull?.usuario;
    if (u == null || !u.activo) {
      throw const FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'usuarioId': 'No hay un usuario activo con ese id'},
        estado: 400,
      );
    }
    return u;
  }

  Usuario _porPin(String pin) =>
      usuarios
          .where((u) => u.usuario.activo && u.pin == pin)
          .firstOrNull
          ?.usuario ??
      (throw const FalloApi(
        'pin_invalido',
        'Se necesita el PIN de un gerente o del dueño',
        estado: 403,
      ));

  Usuario _autorizador(String? pin) {
    final u = _porPin(pin ?? '');
    if (!u.autoriza) {
      throw const FalloApi(
        'sin_permiso',
        'Ese PIN no tiene permiso para autorizar esta acción',
        estado: 403,
      );
    }
    return u;
  }

  /// Como el servidor: sin dueños ni gerentes activos no se pide PIN.
  Usuario? _autorizar(String? pin) =>
      usuarios.any((u) => u.usuario.activo && u.usuario.autoriza)
      ? _autorizador(pin)
      : null;

  void _pinLibre(String pin, {String? excepto}) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'pin': 'Debe tener de 4 a 6 dígitos'},
        estado: 400,
      );
    }
    if (usuarios.any(
      (u) => u.usuario.activo && u.pin == pin && u.usuario.id != excepto,
    )) {
      throw const FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'pin': 'Ese PIN ya lo usa otra persona'},
        estado: 400,
      );
    }
  }

  @override
  Future<List<Usuario>> listarUsuarios() async =>
      [for (final u in usuarios) u.usuario]
        ..sort((a, b) => a.nombre.compareTo(b.nombre));

  @override
  Future<Usuario> crearUsuario({
    required String nombre,
    required String rol,
    required String pin,
    String? pinAutoriza,
  }) async {
    if (usuarios.isEmpty) {
      if (rol != 'dueno') {
        throw const FalloApi(
          'datos_invalidos',
          'Revisa los campos marcados',
          campos: {
            'rol': 'El primer usuario es la cuenta maestra: debe ser dueno',
          },
          estado: 400,
        );
      }
    } else {
      final quien = _autorizador(pinAutoriza);
      if (rol == 'dueno' && quien.rol != 'dueno') {
        throw const FalloApi(
          'sin_permiso',
          'Ese PIN no tiene permiso para autorizar esta acción',
          estado: 403,
        );
      }
    }
    _pinLibre(pin);
    final u = Usuario(
      id: 'u_${usuarios.length + 1}',
      nombre: nombre.trim(),
      rol: rol,
      activo: true,
      creado: '2026-10-02T14:00:00Z',
    );
    usuarios.add((usuario: u, pin: pin));
    return u;
  }

  @override
  Future<Usuario> editarUsuario(
    String id, {
    String? nombre,
    String? rol,
    bool? activo,
    String? pin,
    required String pinAutoriza,
  }) async {
    final i = usuarios.indexWhere((u) => u.usuario.id == id);
    if (i < 0) {
      throw const FalloApi(
        'no_encontrado',
        'No existe el usuario',
        estado: 404,
      );
    }
    final actual = usuarios[i];
    final quien = _autorizador(pinAutoriza);
    if ((actual.usuario.rol == 'dueno' || rol == 'dueno') &&
        quien.rol != 'dueno') {
      throw const FalloApi(
        'sin_permiso',
        'Ese PIN no tiene permiso para autorizar esta acción',
        estado: 403,
      );
    }
    if (pin != null) _pinLibre(pin, excepto: id);
    final u = Usuario(
      id: id,
      nombre: nombre?.trim() ?? actual.usuario.nombre,
      rol: rol ?? actual.usuario.rol,
      activo: activo ?? actual.usuario.activo,
      creado: actual.usuario.creado,
    );
    final nuevos = List.of(usuarios)
      ..[i] = (usuario: u, pin: pin ?? actual.pin);
    if (!nuevos.any((x) => x.usuario.activo && x.usuario.rol == 'dueno')) {
      throw FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {
          actual.usuario.rol == 'dueno' && u.rol != 'dueno' ? 'rol' : 'activo':
              'El depósito necesita al menos un dueño activo',
        },
        estado: 400,
      );
    }
    usuarios[i] = nuevos[i];
    return u;
  }

  @override
  Future<Usuario> verificarPin(String pin, {String? usuarioId}) async {
    final u = _porPin(pin);
    if (usuarioId != null && u.id != usuarioId) {
      throw const FalloApi(
        'pin_invalido',
        'Se necesita el PIN de un gerente o del dueño',
        estado: 403,
      );
    }
    return u;
  }

  // --- Alertas ---

  /// Día de negocio contra el que se calculan las caducidades.
  var hoy = '2026-10-02';

  @override
  Future<({String dia, int dias, List<Alerta> alertas})> listarAlertas({
    int? dias,
  }) async {
    final ventana = dias ?? diasAlertaCaducidad;
    if (ventana < 1 || ventana > maxDiasAlertaCaducidad) {
      throw const FalloApi(
        'datos_invalidos',
        'Revisa los campos marcados',
        campos: {'dias': 'Debe ser un entero de 1 a 365'},
      );
    }
    return (
      dia: hoy,
      dias: ventana,
      alertas: calcularAlertas(productos, hoy: hoy, dias: ventana),
    );
  }

  // --- Ajustes y respaldo ---

  var ajustes = const AjustesNegocio();

  @override
  Future<AjustesNegocio> obtenerAjustes() async => ajustes;

  @override
  Future<AjustesNegocio> guardarAjustes(Map<String, String?> cambios) async {
    ajustes = AjustesNegocio.fromJson({...ajustes.toJson(), ...cambios});
    return ajustes;
  }

  @override
  Future<({Uint8List bytes, String nombre})> descargarRespaldo() async => (
    bytes: Uint8List.fromList('SQLite format 3\u0000'.codeUnits),
    nombre: 'anaquel-20261002-183000.db',
  );

  void _moverEnvases(String formato, {int bodega = 0, int prestados = 0}) {
    final b = envases[formato]!;
    envases[formato] = BalanceEnvase(
      formato: formato,
      bodega: b.bodega + bodega,
      prestados: b.prestados + prestados,
      precio: b.precio,
    );
  }
}

/// Fondo del turno con que arranca la caja falsa, como el servidor con datos
/// de ejemplo: $500.00.
const fondoDePrueba = 50000;

/// Turno en memoria de [ApiFalsa]; cerrado cuando tiene [contado].
class _TurnoFalso {
  _TurnoFalso(this.id, this.fondo, [this.usuarioApertura]);

  final String id;
  final int fondo;
  final Usuario? usuarioApertura;
  final movimientos = <MovimientoCaja>[];
  int? contado;
  String? nota;
  Usuario? usuarioCierre;
}

/// El balance con que arranca la base (migraciones m002 y m005). Como en el
/// servidor, los prestados son la suma de lo pendiente de [prestamos].
Map<String, BalanceEnvase> balanceDePrueba({
  List<PrestamoEnvase> prestamos = const [],
}) {
  int prestados(String formato) => prestamos
      .where((p) => p.formato == formato)
      .fold(0, (t, p) => t + p.cantidad);
  return {
    'mega': BalanceEnvase(
      formato: 'mega',
      bodega: 84,
      prestados: prestados('mega'),
      precio: 800,
    ),
    'media': BalanceEnvase(
      formato: 'media',
      bodega: 240,
      prestados: prestados('media'),
      precio: 300,
    ),
    'cuarto': BalanceEnvase(
      formato: 'cuarto',
      bodega: 168,
      prestados: prestados('cuarto'),
      precio: 300,
    ),
  };
}

Producto _p(
  String id,
  String codigo,
  String nombre,
  String categoria,
  String presentacion,
  int precio,
  int existencia,
  int minimo, {
  int? precioCaja,
  int? piezasPorCaja,
  String? envase,
  String? caducidad,
}) => Producto(
  id: id,
  codigo: codigo,
  nombre: nombre,
  categoria: categoria,
  presentacion: presentacion,
  precio: precio,
  precioCaja: precioCaja,
  piezasPorCaja: piezasPorCaja,
  existenciaPiezas: existencia,
  minimo: minimo,
  envase: envase,
  caducidad: caducidad,
  creado: '2026-10-02T18:30:00Z',
  actualizado: '2026-10-02T18:30:00Z',
);

List<Producto> productosDePrueba() {
  return [
    _p(
      'p_1',
      '7501064191015',
      'Victoria Mega',
      'cerveza',
      'Mega 1.2 L',
      4200,
      66,
      36,
      precioCaja: 48000,
      piezasPorCaja: 12,
      envase: 'mega',
      caducidad: '2027-01-29',
    ),
    _p(
      'p_2',
      '7501064191022',
      'Corona Mega',
      'cerveza',
      'Mega 1.2 L',
      4400,
      30,
      36,
      precioCaja: 50000,
      piezasPorCaja: 12,
      envase: 'mega',
      caducidad: '2027-01-04',
    ),
    _p(
      'p_3',
      '7501064191046',
      'Corona Cuarto',
      'cerveza',
      'Cuarto 210 ml',
      1700,
      200,
      48,
      precioCaja: 38000,
      piezasPorCaja: 24,
      envase: 'cuarto',
      caducidad: '2026-10-21',
    ),
    _p(
      'p_4',
      '7502000000017',
      'Hielo en bolsa',
      'hielo',
      'Bolsa 5 kg',
      3500,
      18,
      10,
    ),
    _p(
      'p_5',
      '7502000000024',
      'Coca-Cola',
      'refresco',
      'Botella 600 ml',
      2200,
      40,
      24,
      caducidad: '2027-02-28',
    ),
    _p(
      'p_6',
      '7502000000048',
      'Papas adobadas',
      'botana',
      'Bolsa 45 g',
      2000,
      25,
      20,
      caducidad: '2026-10-13',
    ),
  ];
}

/// El catálogo de la app en web (no hay servidor): el de pruebas más los
/// productos de las fotos del diseño de Pablo.
List<Producto> productosDeDemo() => [
  ...productosDePrueba(),
  _p(
    'p_7',
    '7501064191039',
    'Modelo Especial',
    'cerveza',
    'Media 355 ml',
    2400,
    120,
    48,
    precioCaja: 54000,
    piezasPorCaja: 24,
    envase: 'media',
    caducidad: '2026-11-29',
  ),
  _p(
    'p_8',
    '7502000000055',
    'Cacahuates japoneses',
    'botana',
    'Bolsa 100 g',
    1800,
    6,
    15,
    caducidad: '2026-12-04',
  ),
  _p(
    'p_9',
    '7502000000062',
    'Doritos Nacho',
    'botana',
    'Bolsa 62 g',
    1800,
    15,
    10,
    caducidad: '2026-12-19',
  ),
];
