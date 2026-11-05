/// Flujo de cobro de la caja, dividido por paso para que cada archivo tenga
/// una sola responsabilidad:
///
/// - [ResumenCompra]: revisión del carrito antes de pagar (4.1).
/// - [MetodoPago]: elegir efectivo, tarjeta o saldo por envases (4.2).
/// - [CobroEfectivo] y [ModalCambio]: recibir efectivo y calcular cambio (4.3).
/// - [CobroTarjeta]: confirmar el resultado de la terminal bancaria (4.5).
/// - [VentaExitosa]: confirmación y opciones de recibo (4.7).
/// - [VistaTicketPdf]: vista previa del ticket (4.9).
///
/// Este archivo solo reexporta: quien lo importaba antes sigue igual.
library;

export 'cobro/cobro_efectivo.dart';
export 'cobro/cobro_tarjeta.dart';
export 'cobro/metodo_pago.dart';
export 'cobro/resumen_compra.dart';
export 'cobro/venta_exitosa.dart';
export 'cobro/vista_ticket_pdf.dart';
