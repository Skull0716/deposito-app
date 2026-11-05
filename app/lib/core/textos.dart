/// Textos visibles que se comparten entre pantallas.
///
/// `docs/ESTANDARES.md` pide un solo lugar para las cadenas repetidas: así el
/// mismo botón dice lo mismo en toda la app y se corrige una vez. Los textos
/// propios de una sola pantalla se quedan junto a esa pantalla; cuando se
/// repiten, se mueven aquí.
///
/// Reglas:
/// - No cambiar el valor de una constante sin revisar las pruebas y capturas.
/// - Los textos con datos variables se exponen como funciones.
abstract final class Textos {
  Textos._();

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------
  static const cancelar = 'Cancelar';
  static const cerrar = 'Cerrar';
  static const guardar = 'Guardar';
  static const reintentar = 'Reintentar';
  static const volver = 'Volver';
  static const continuar = 'Continuar';
  static const buscar = 'Buscar';
  static const confirmar = 'Confirmar';
  static const eliminar = 'Eliminar';
  static const aceptar = 'Aceptar';

  // ---------------------------------------------------------------------------
  // Estados y errores
  // ---------------------------------------------------------------------------
  static const cargando = 'Cargando…';
  static const sinConexionCaja = 'Sin conexión con la caja';
  static const algoSalioMal = 'Algo salió mal';
  static const ocurrioUnError = 'Ocurrió un error';
  static const errorInesperado = 'Ocurrió un error inesperado.';
  static const sinConexionWiFi =
      'No hay conexión con la caja. Revisa que estén en la misma Wi-Fi.';

  static String respuestaInesperada(int? estado) =>
      'Respuesta inesperada del servidor (${estado ?? 'sin código'})';

  // ---------------------------------------------------------------------------
  // Conexión
  // ---------------------------------------------------------------------------
  static const enLinea = 'En línea';
  static const conectando = 'Conectando…';
  static const sinConexionReintentando = 'Sin conexión, reintentando';

  // ---------------------------------------------------------------------------
  // Accesibilidad (etiquetas para lectores de pantalla)
  // ---------------------------------------------------------------------------
  static const pin = 'PIN';
  static const borrar = 'Borrar';

  static String conexion(String estado) => 'Conexión: $estado';

  // ---------------------------------------------------------------------------
  // Carga e inicialización
  // ---------------------------------------------------------------------------
  static const preparandoEspacio = 'Preparando tu espacio de trabajo';
  static const baseDatosLista = '¡Base de datos lista!';
  static const inicializandoBaseDatos = 'Inicializando base de datos local...';

  // ---------------------------------------------------------------------------
  // Terminal
  // ---------------------------------------------------------------------------
  static const terminalNoVinculada =
      'Esta terminal no está vinculada a una caja.';
  static const nombreTerminalPorDefecto = 'Terminal';
  static const respaldoDeAnaquel = 'Respaldo de Anaquel';

  // ---------------------------------------------------------------------------
  // Configuración inicial
  // ---------------------------------------------------------------------------
  static const configurarPuntoDeVenta = 'Configura tu punto de venta';
  static const eligeQueDeseasHacer =
      'Elige qué deseas hacer en este dispositivo.';
  static const seleccionaUnaOpcion = 'Selecciona una opción';
  static const crearServidorPos = 'Crear Nuevo Servidor POS';
  static const descripcionCrearServidor =
      'Configura este dispositivo como la caja principal.';
  static const vincularCelular = 'Vincular Celular como Terminal';
  static const descripcionVincularCelular =
      'Vincula este equipo a un Servidor Host existente.';
  static const restaurarServidor = 'Restaurar Servidor desde Respaldo';
  static const descripcionRestaurarServidor =
      'Recupera inventario, personal y cortes de caja.';
  static const desarrolladoPor = 'Desarrollado por Equipo Umizommi';
}
