/// Un registro del CSV con el renglón del archivo donde empieza (el primero
/// es 1), para reportar errores como los numera Excel.
typedef RegistroCsv = ({int renglon, List<String> celdas});

/// Lee un CSV (RFC 4180) como lo guarda una hoja de cálculo: quita el BOM,
/// acepta `\r\n` o `\n`, celdas entre comillas con `""` para una comilla y
/// saltos de línea dentro de ellas. El separador es `;` si el primer
/// renglón tiene `;` y no `,` (Excel en español); si no, `,`.
///
/// Lanza [FormatException] si una comilla queda abierta.
List<RegistroCsv> leerCsv(String texto) {
  if (texto.startsWith('\uFEFF')) texto = texto.substring(1);
  final finPrimero = texto.indexOf('\n');
  final primero = finPrimero < 0 ? texto : texto.substring(0, finPrimero);
  final separador = primero.contains(';') && !primero.contains(',') ? ';' : ',';

  final registros = <RegistroCsv>[];
  var celdas = <String>[];
  final celda = StringBuffer();
  var renglon = 1;
  var inicio = 1;
  var entreComillas = false;

  void cerrarCelda() {
    celdas.add(celda.toString());
    celda.clear();
  }

  void cerrarRegistro() {
    cerrarCelda();
    registros.add((renglon: inicio, celdas: celdas));
    celdas = <String>[];
  }

  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (entreComillas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          celda.write('"');
          i++;
        } else {
          entreComillas = false;
        }
      } else {
        if (c == '\n') renglon++;
        celda.write(c);
      }
    } else if (c == '"' && celda.isEmpty) {
      entreComillas = true;
    } else if (c == separador) {
      cerrarCelda();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < texto.length && texto[i + 1] == '\n') i++;
      cerrarRegistro();
      renglon++;
      inicio = renglon;
    } else {
      celda.write(c);
    }
  }
  if (entreComillas) {
    throw FormatException(
      'Hay una comilla sin cerrar desde el renglón $inicio',
    );
  }
  if (celda.isNotEmpty || celdas.isNotEmpty) cerrarRegistro();
  return registros;
}
