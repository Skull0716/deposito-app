import 'package:dio/dio.dart';

import '../textos.dart';

/// Error de la API ya traducido para mostrarlo en pantalla.
///
/// [codigo] es el del contrato (`datos_invalidos`, `no_autorizado`...) o
/// `sin_conexion` cuando no se pudo llegar al servidor.
class FalloApi implements Exception {
  const FalloApi(
    this.codigo,
    this.mensaje, {
    this.campos = const {},
    this.estado,
  });

  final String codigo;
  final String mensaje;
  final Map<String, String> campos;
  final int? estado;

  bool get sinConexion => codigo == 'sin_conexion';

  bool get noAutorizado => estado == 401;

  factory FalloApi.desdeDio(DioException e) {
    final datos = e.response?.data;
    if (datos is Map && datos['error'] is Map) {
      final error = datos['error'] as Map;
      return FalloApi(
        error['codigo'] as String? ?? 'error',
        error['mensaje'] as String? ?? Textos.ocurrioUnError,
        campos: (error['campos'] as Map?)?.cast<String, String>() ?? const {},
        estado: e.response?.statusCode,
      );
    }
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => const FalloApi(
        'sin_conexion',
        Textos.sinConexionWiFi,
      ),
      _ => FalloApi(
        'error',
        Textos.respuestaInesperada(e.response?.statusCode),
        estado: e.response?.statusCode,
      ),
    };
  }

  @override
  String toString() => 'FalloApi($codigo: $mensaje)';
}

/// Mensaje legible para cualquier error que llegue a una pantalla.
String mensajeDeError(Object error) =>
    error is FalloApi ? error.mensaje : Textos.errorInesperado;
