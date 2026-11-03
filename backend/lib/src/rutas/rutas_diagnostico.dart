import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../comun/json.dart';
import '../comun/sesion.dart';
import '../servicios/servicio_diagnostico.dart';

void montarRutasDiagnostico(Router r, ServicioDiagnostico diagnostico) {
  r.get('/api/v1/diagnostico', (Request p) {
    exigirCaja(p);
    return respuestaJson(diagnostico.leer().toJson());
  });

  r.get('/api/v1/diagnostico/bitacora', (Request p) {
    exigirCaja(p);
    final log = diagnostico.bitacora();
    return Response.ok(
      log.texto,
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'content-disposition': 'attachment; filename="${log.nombre}"',
      },
    );
  });
}
