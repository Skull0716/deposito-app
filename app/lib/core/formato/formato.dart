import 'package:deposito_backend/deposito_backend.dart';
import 'package:intl/intl.dart';

/// El formateador de dinero de la app (docs/ESTANDARES.md). Ninguna pantalla
/// formatea dinero por su cuenta.
///
/// `4200` → `$42`, `4250` → `$42.50`, `123456` → `$1,234.56`.
String dinero(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final pesos = abs ~/ 100;
  final resto = abs % 100;
  final miles = pesos.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  final texto = resto == 0
      ? '\$$miles'
      : '\$$miles.${resto.toString().padLeft(2, '0')}';
  return negativo ? '-$texto' : texto;
}

/// Existencia legible: `66` piezas en cajas de 12 → `5 cajas + 6 pz`.
String existenciaLegible(Producto p) {
  final piezas = p.existenciaPiezas;
  final porCaja = p.piezasPorCaja;
  if (porCaja == null || piezas < porCaja) return '$piezas pz';
  final cajas = piezas ~/ porCaja;
  final sueltas = piezas % porCaja;
  final textoCajas = cajas == 1 ? '1 caja' : '$cajas cajas';
  return sueltas == 0 ? textoCajas : '$textoCajas + $sueltas pz';
}

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// `Jueves, 1 de octubre`.
String fechaLarga(DateTime f) {
  final dia = _dias[f.weekday - 1];
  return '${dia[0].toUpperCase()}${dia.substring(1)}, ${f.day} de ${_meses[f.month - 1]}';
}

/// `3 oct` a partir de `AAAA-MM-DD`.
String fechaCorta(String iso) {
  final f = DateTime.parse(iso);
  return '${f.day} ${_meses[f.month - 1].substring(0, 3)}';
}

/// `18/10/2026 • 06:30 PM` en la hora del dispositivo, a partir de un
/// instante ISO 8601 UTC.
String fechaHora(String iso) =>
    DateFormat('dd/MM/yyyy • hh:mm a').format(DateTime.parse(iso).toLocal());

/// `06:30 PM` en la hora del dispositivo.
String hora(String iso) =>
    DateFormat('hh:mm a').format(DateTime.parse(iso).toLocal());

/// Tamaño legible: `1843200` → `1.8 MB`, `512` → `512 B`.
String tamanoLegible(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}

/// Pesos para precargar un formulario: `4200` → `42`, `4250` → `42.50`.
String pesosEditables(int centavos) {
  final pesos = centavos ~/ 100;
  final resto = centavos % 100;
  return resto == 0 ? '$pesos' : '$pesos.${resto.toString().padLeft(2, '0')}';
}

/// Días de hoy a [iso] (`AAAA-MM-DD`); negativo si ya pasó.
int diasHasta(String iso, DateTime hoy) {
  final f = DateTime.parse(iso);
  return DateTime(
    f.year,
    f.month,
    f.day,
  ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
}

/// Primera letra en mayúscula: `cerveza` → `Cerveza`.
String capitalizar(String t) =>
    t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';

/// Lee pesos escritos por una persona (`42`, `42.5`, `$1,234.50`) y los
/// regresa en centavos exactos, sin pasar por `double`. `null` si no es válido.
int? centavosDesdeTexto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s$,]'), '');
  final m = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(limpio);
  if (m == null) return null;
  final pesos = int.parse(m[1]!);
  final cent = m[2] == null ? 0 : int.parse(m[2]!.padRight(2, '0'));
  return pesos * 100 + cent;
}
