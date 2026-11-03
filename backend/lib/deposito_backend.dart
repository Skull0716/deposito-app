/// Servidor de Anaquel y modelos compartidos con la app.
///
/// La app importa este paquete para:
/// - arrancar [DepositoServer] en modo Caja;
/// - usar los mismos modelos ([Producto], [Turno], [Terminal], [Evento]...) que el
///   servidor, así los campos nunca se desincronizan.
library;

export 'src/comun/bitacora.dart' show Bitacora;
export 'src/comun/fechas.dart'
    show Reloj, diaNegocio, instanteIso, rangoDiaNegocio;
export 'src/comun/constantes.dart';
export 'src/comun/texto.dart' show normalizarBusqueda;
export 'src/modelos/ajustes.dart';
export 'src/modelos/alerta.dart';
export 'src/modelos/caja.dart';
export 'src/modelos/envase.dart';
export 'src/modelos/evento.dart';
export 'src/modelos/importacion.dart';
export 'src/modelos/movimiento.dart';
export 'src/modelos/producto.dart';
export 'src/modelos/terminal.dart';
export 'src/modelos/usuario.dart';
export 'src/modelos/venta.dart';
export 'src/seed/fotos_ejemplo.dart';
// En web no hay dart:io ni SQLite: la app usa ApiFalsa y este servidor vacío.
export 'src/servidor_stub.dart'
    if (dart.library.io) 'src/servidor.dart'
    show DepositoServer, versionServidor;
export 'src/respaldo_stub.dart'
    if (dart.library.io) 'src/db/respaldo.dart'
    show EstadoRespaldo, verificarRespaldo, restaurarRespaldo;
