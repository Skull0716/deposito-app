import '../comun/csv.dart';
import '../comun/texto.dart';

/// Máximo del texto CSV que acepta `POST /api/v1/productos/importar`.
const maxCaracteresCsv = 2 * 1024 * 1024;

/// Máximo de renglones de productos (sin el encabezado).
const maxRenglonesCsv = 5000;

/// Columnas obligatorias del CSV de inventario.
const columnasObligatoriasCsv = ['codigo', 'nombre', 'categoria', 'precio'];

/// Columnas opcionales, en el orden de la plantilla.
const columnasOpcionalesCsv = [
  'presentacion',
  'precioCaja',
  'piezasPorCaja',
  'existencia',
  'minimo',
  'envase',
  'caducidad',
];

const _columnasEnteras = {'piezasPorCaja', 'existencia', 'minimo'};
const _columnasPesos = {'precio', 'precioCaja'};

/// Un renglón del CSV ya leído: [valores] trae solo las celdas con algo,
/// con su tipo (pesos en centavos, enteros, fechas `AAAA-MM-DD`) y con las
/// columnas nombradas como en la API, salvo `existencia`. [errores] trae las
/// celdas que no se pudieron leer.
class RenglonInventario {
  const RenglonInventario({
    required this.renglon,
    required this.valores,
    required this.errores,
  });

  final int renglon;
  final Map<String, Object?> valores;
  final Map<String, String> errores;

  String? get codigo => valores['codigo'] as String?;
}

/// Lee el CSV de inventario (docs/API.md, Importar desde CSV) sin tocar la
/// base: lo usan el servidor y la API falsa de la app. Lanza
/// [FormatException] con el motivo si el archivo entero no sirve.
List<RenglonInventario> leerInventario(String csv) {
  if (csv.length > maxCaracteresCsv) {
    throw const FormatException('El archivo pasa de 2 MB');
  }
  final registros = leerCsv(csv)
      .where((r) => r.celdas.any((c) => c.trim().isNotEmpty))
      .toList();
  if (registros.isEmpty) throw const FormatException('El archivo está vacío');
  if (registros.length - 1 > maxRenglonesCsv) {
    throw const FormatException(
      'Tiene más de $maxRenglonesCsv renglones de productos',
    );
  }

  final columnas = <String>[];
  for (final nombre in registros.first.celdas) {
    final columna = _columna(nombre);
    if (columna == null) {
      throw FormatException('No se conoce la columna "${nombre.trim()}"');
    }
    if (columnas.contains(columna)) {
      throw FormatException('La columna "$columna" viene dos veces');
    }
    columnas.add(columna);
  }
  final faltan = columnasObligatoriasCsv.where((c) => !columnas.contains(c));
  if (faltan.isNotEmpty) {
    throw FormatException('Faltan las columnas: ${faltan.join(', ')}');
  }

  return [for (final r in registros.skip(1)) _leerRenglon(r, columnas)];
}

RenglonInventario _leerRenglon(RegistroCsv r, List<String> columnas) {
  final valores = <String, Object?>{};
  final errores = <String, String>{};
  for (var i = 0; i < r.celdas.length; i++) {
    final texto = r.celdas[i].trim();
    if (texto.isEmpty) continue;
    if (i >= columnas.length) {
      errores['csv'] = 'Tiene más celdas que el encabezado';
      continue;
    }
    final columna = columnas[i];
    if (_columnasPesos.contains(columna)) {
      final centavos = centavosDePesos(texto);
      if (centavos == null) {
        errores[columna] = 'Debe ser un precio en pesos con punto para los centavos, como 42.50';
      } else {
        valores[columna] = centavos;
      }
    } else if (_columnasEnteras.contains(columna)) {
      final n = RegExp(r'^-?\d{1,9}$').hasMatch(texto)
          ? int.parse(texto)
          : null;
      if (n == null) {
        errores[columna] = 'Debe ser un número entero';
      } else {
        valores[columna] = n;
      }
    } else if (columna == 'caducidad') {
      valores[columna] = _fechaIso(texto);
    } else if (columna == 'envase') {
      valores[columna] = texto.toLowerCase();
    } else {
      valores[columna] = texto;
    }
  }
  final existencia = valores['existencia'] as int?;
  if (existencia != null && existencia < 0) {
    errores['existencia'] = 'Debe ser 0 o más';
  }
  return RenglonInventario(
    renglon: r.renglon,
    valores: valores,
    errores: errores,
  );
}

/// Nombre de columna de la API para un encabezado escrito por una persona:
/// sin distinguir mayúsculas, acentos, espacios ni guiones bajos.
String? _columna(String encabezado) {
  final clave = normalizarBusqueda(encabezado).replaceAll(RegExp(r'[\s_]'), '');
  for (final c in [...columnasObligatoriasCsv, ...columnasOpcionalesCsv]) {
    if (c.toLowerCase() == clave) return c;
  }
  return null;
}

/// Pesos escritos por una persona (`42`, `42.5`, `$1,234.50`) en centavos
/// exactos, sin pasar por `double`. `null` si no es válido, incluido `42,50`:
/// con coma decimal no se sabe si son pesos o centavos.
int? centavosDePesos(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s$]'), '');
  final m = RegExp(r'^(\d{1,3}(?:,\d{3})+|\d{1,9})(?:\.(\d{1,2}))?$')
      .firstMatch(limpio);
  if (m == null) return null;
  final pesos = int.parse(m[1]!.replaceAll(',', ''));
  final centavos = m[2] == null ? 0 : int.parse(m[2]!.padRight(2, '0'));
  return pesos * 100 + centavos;
}

/// `DD/MM/AAAA` a `AAAA-MM-DD`; cualquier otro texto se regresa igual para
/// que la validación de fechas diga qué está mal.
String _fechaIso(String texto) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto);
  if (m == null) return texto;
  return '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
}

/// Un producto que ya existía y cambia de existencia al importar.
class CambioExistencia {
  const CambioExistencia({
    required this.renglon,
    required this.codigo,
    required this.nombre,
    required this.antes,
    required this.despues,
  });

  final int renglon;
  final String codigo;
  final String nombre;
  final int antes;
  final int despues;

  factory CambioExistencia.fromJson(Map<String, Object?> j) => CambioExistencia(
    renglon: j['renglon'] as int,
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    antes: j['antes'] as int,
    despues: j['despues'] as int,
  );

  Map<String, Object?> toJson() => {
    'renglon': renglon,
    'codigo': codigo,
    'nombre': nombre,
    'antes': antes,
    'despues': despues,
  };
}

/// Un renglón que no se puede importar, con el motivo por columna.
class ErrorRenglon {
  const ErrorRenglon({
    required this.renglon,
    required this.codigo,
    required this.campos,
  });

  final int renglon;
  final String? codigo;
  final Map<String, String> campos;

  factory ErrorRenglon.fromJson(Map<String, Object?> j) => ErrorRenglon(
    renglon: j['renglon'] as int,
    codigo: j['codigo'] as String?,
    campos: (j['campos'] as Map).cast(),
  );

  Map<String, Object?> toJson() => {
    'renglon': renglon,
    'codigo': codigo,
    'campos': campos,
  };
}

/// Respuesta de `POST /api/v1/productos/importar`.
class ResultadoImportacion {
  const ResultadoImportacion({
    required this.guardado,
    required this.creados,
    required this.actualizados,
    required this.sinCambios,
    required this.cambiosExistencia,
    required this.errores,
  });

  /// `true` solo si se pidió guardar y no hubo errores.
  final bool guardado;
  final int creados;
  final int actualizados;
  final int sinCambios;
  final List<CambioExistencia> cambiosExistencia;
  final List<ErrorRenglon> errores;

  factory ResultadoImportacion.fromJson(Map<String, Object?> j) =>
      ResultadoImportacion(
        guardado: j['guardado'] as bool,
        creados: j['creados'] as int,
        actualizados: j['actualizados'] as int,
        sinCambios: j['sinCambios'] as int,
        cambiosExistencia: [
          for (final c in j['cambiosExistencia'] as List)
            CambioExistencia.fromJson((c as Map).cast()),
        ],
        errores: [
          for (final e in j['errores'] as List)
            ErrorRenglon.fromJson((e as Map).cast()),
        ],
      );

  Map<String, Object?> toJson() => {
    'guardado': guardado,
    'creados': creados,
    'actualizados': actualizados,
    'sinCambios': sinCambios,
    'cambiosExistencia': [for (final c in cambiosExistencia) c.toJson()],
    'errores': [for (final e in errores) e.toJson()],
  };
}
