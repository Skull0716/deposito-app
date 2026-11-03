/// Estado del servidor para la pantalla de Diagnóstico
/// (`GET /api/v1/diagnostico`).
class Diagnostico {
  const Diagnostico({
    required this.version,
    required this.iniciado,
    required this.esquema,
    required this.bytesBaseDatos,
    required this.conexiones,
    required this.terminalesConectadas,
    required this.ultimosErrores,
  });

  /// Versión del servidor, la misma que manda `conexion.lista`.
  final String version;

  /// Instante en que arrancó el servidor (ISO 8601 UTC).
  final String iniciado;

  /// Última migración aplicada.
  final int esquema;

  final int bytesBaseDatos;

  /// WebSocket abiertos, contando los de la caja.
  final int conexiones;

  /// Terminales distintas con al menos un WebSocket abierto.
  final int terminalesConectadas;

  /// Hasta 50 errores desde que arrancó, el más reciente primero.
  final List<String> ultimosErrores;

  factory Diagnostico.fromJson(Map<String, Object?> j) => Diagnostico(
    version: j['version'] as String,
    iniciado: j['iniciado'] as String,
    esquema: j['esquema'] as int,
    bytesBaseDatos: j['bytesBaseDatos'] as int,
    conexiones: j['conexiones'] as int,
    terminalesConectadas: j['terminalesConectadas'] as int,
    ultimosErrores: (j['ultimosErrores'] as List).cast<String>(),
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'iniciado': iniciado,
    'esquema': esquema,
    'bytesBaseDatos': bytesBaseDatos,
    'conexiones': conexiones,
    'terminalesConectadas': terminalesConectadas,
    'ultimosErrores': ultimosErrores,
  };
}
