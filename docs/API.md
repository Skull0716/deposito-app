# Contrato de la API

Este documento es el acuerdo entre `backend/` y `app/`. Ningún endpoint se programa sin estar primero aquí.

Los cambios a este archivo se hacen por pull request con la etiqueta `contrato`.

## Convenciones

| Tema | Regla |
| --- | --- |
| Prefijo | Las rutas empiezan con `/api/v1`, salvo `/salud` |
| Formato | JSON en UTF-8 |
| Nombres | En español, sin acentos, en `camelCase`: `precioCaja`, `piezasPorCaja` |
| Dinero | Entero en centavos: $42.50 se manda como `4250`. Un número con decimales es `datos_invalidos` |
| Instantes | ISO 8601 en UTC, sin milisegundos: `2026-10-02T18:30:00Z` |
| Fechas de calendario | `AAAA-MM-DD` en la hora local del negocio: `2027-03-15` (caducidad, día de un reporte) |
| Existencias | Siempre en piezas. Las cajas son solo visuales |
| IDs | Texto generado por el servidor, con prefijo por tipo: `p_` producto, `t_` terminal, `v_` venta, `ped_` pedido, `pre_` préstamo, `tur_` turno de caja, `mc_` movimiento de caja, `u_` usuario, `dev_` devolución |
| Autenticación | Encabezado `X-Clave-Terminal` en toda petición, salvo las marcadas como públicas |
| Reintentos | Los cobros llevan el encabezado `X-Clave-Idempotencia` (ver [Registrar venta](#registrar-venta)) |
| Errores | `{ "error": { "codigo": "stock_insuficiente", "mensaje": "..." } }` |

### Quién llama

| Rol | Cómo se identifica | Puede |
| --- | --- | --- |
| Caja | La clave de caja que el servidor embebido le da a la app al arrancar | Todo |
| Terminal | La clave que recibió al registrarse con el código del QR | Consultar, y lo que cada endpoint indique |

Un endpoint marcado **Solo caja** responde `403 solo_caja` a una terminal.

### Errores

| HTTP | `codigo` | Cuándo |
| --- | --- | --- |
| `400` | `datos_invalidos` | Falta un campo o tiene un formato o valor no permitido. Incluye `campos` (abajo) |
| `400` | `json_invalido` | El cuerpo no es JSON válido |
| `401` | `no_autorizado` | Falta `X-Clave-Terminal`, no existe o fue revocada |
| `401` | `codigo_invalido` | Código de emparejamiento incorrecto o vencido |
| `403` | `solo_caja` | Una terminal intenta algo que solo hace la caja |
| `404` | `no_encontrado` | El recurso o la ruta no existe |
| `409` | `codigo_duplicado` | Ya existe un producto activo con ese código de barras |
| `409` | `stock_insuficiente` | No hay piezas suficientes para una venta o una merma |
| `409` | `envases_insuficientes` | No hay suficientes envases vacíos en bodega para venderlos |
| `409` | `caja_cerrada` | Se intenta cobrar, registrar un movimiento de caja o cerrar sin turno abierto |
| `409` | `caja_abierta` | Se intenta abrir la caja con un turno ya abierto |
| `409` | `turno_cerrado` | Se intenta cancelar o devolver una venta de un turno que ya tiene corte |
| `403` | `pin_invalido` | Falta el PIN de autorización o no es de un usuario activo |
| `403` | `sin_permiso` | El PIN es válido pero su rol no puede autorizar esa acción |
| `429` | `demasiados_intentos` | Cinco PIN incorrectos seguidos: se bloquea la verificación 1 minuto |
| `500` | `error_interno` | Error no previsto. El detalle queda en el log del servidor |

Los errores de validación dicen qué campo falló, para que la app lo muestre junto al campo:

```json
{
  "error": {
    "codigo": "datos_invalidos",
    "mensaje": "Revisa los campos marcados",
    "campos": { "precio": "Debe ser un entero mayor que 0 (centavos)" }
  }
}
```

## Endpoints

### Salud

`GET /salud` · Pública

Comprueba que el servidor responde.

- Respuesta `200`: el texto `ok`.

### Terminales

Una terminal se vincula así:

1. La caja pide un código de emparejamiento y lo muestra en un QR.
2. La terminal escanea el QR y se registra con ese código.
3. El servidor le entrega una clave propia, que la terminal guarda y manda en cada petición.

El QR contiene este JSON:

```json
{ "v": 1, "host": "192.168.1.20", "puerto": 8080, "codigo": "482913" }
```

#### Crear código de emparejamiento

`POST /api/v1/terminales/codigo` · Solo caja

Genera un código de 6 dígitos que vence en 10 minutos. Pedir uno nuevo invalida el anterior. Cinco intentos fallidos también lo invalidan, y sirve para registrar una sola terminal.

- Respuesta `201`:

```json
{ "codigo": "482913", "expira": "2026-10-02T18:40:00Z" }
```

#### Registrar terminal

`POST /api/v1/terminales/registro` · Pública

```json
{ "nombre": "Terminal S24", "codigo": "482913" }
```

- `nombre`: de 1 a 40 caracteres.
- Respuesta `201`. La `clave` se entrega **solo esta vez**; el servidor guarda únicamente su hash:

```json
{
  "terminal": {
    "id": "t_8f2a4c9d1e",
    "nombre": "Terminal S24",
    "registrada": "2026-10-02T18:31:00Z",
    "ultimaConexion": "2026-10-02T18:31:00Z",
    "conectada": false
  },
  "clave": "Zq0vX3...43 caracteres..."
}
```

- `400 datos_invalidos`, `401 codigo_invalido`.

#### Listar terminales

`GET /api/v1/terminales` · Solo caja

- Respuesta `200`: `{ "terminales": [ <terminal>, ... ] }`, sin las revocadas. `conectada` es `true` si tiene un WebSocket abierto.

#### Revocar terminal

`DELETE /api/v1/terminales/{id}` · Solo caja

La clave deja de servir de inmediato y se cierra su WebSocket.

- Respuesta `204` sin cuerpo. `404 no_encontrado`.

### Productos

#### El objeto producto

```json
{
  "id": "p_3k9x2m7q1z",
  "codigo": "7501064191015",
  "nombre": "Victoria Mega",
  "categoria": "cerveza",
  "presentacion": "Mega 1.2 L",
  "precio": 4200,
  "precioCaja": 48000,
  "piezasPorCaja": 12,
  "existenciaPiezas": 66,
  "minimo": 36,
  "envase": "mega",
  "caducidad": "2027-01-29",
  "foto": null,
  "creado": "2026-10-02T18:30:00Z",
  "actualizado": "2026-10-02T18:30:00Z"
}
```

| Campo | Tipo | Regla |
| --- | --- | --- |
| `codigo` | texto | Código de barras, de 1 a 64 letras o dígitos. Único entre productos activos |
| `nombre` | texto | De 1 a 80 caracteres |
| `categoria` | texto | De 1 a 40 caracteres, en minúsculas: `cerveza`, `refresco`, `botana`, `hielo`... |
| `presentacion` | texto o `null` | Hasta 40 caracteres |
| `precio` | entero | Centavos por pieza, mayor que 0 |
| `precioCaja` | entero o `null` | Centavos por caja, mayor que 0. Va junto con `piezasPorCaja`: los dos o ninguno |
| `piezasPorCaja` | entero o `null` | 2 o más |
| `existenciaPiezas` | entero | 0 o más. Solo lectura después de crear: cambia por entradas, ventas o ajustes |
| `minimo` | entero | 0 o más. Bajo este número se genera alerta. Por omisión `0` |
| `envase` | texto o `null` | `mega`, `media` o `cuarto` si usa envase retornable |
| `caducidad` | fecha o `null` | `AAAA-MM-DD`, la más próxima |
| `foto` | texto o `null` | Ruta de la foto en el servidor (ver [Foto](#foto)). Solo lectura |

#### Listar y buscar

`GET /api/v1/productos?q=victoria&categoria=cerveza`

- `q` (opcional): busca en nombre y código, sin distinguir mayúsculas ni acentos.
- `categoria` (opcional): filtro exacto.
- Respuesta `200`: `{ "productos": [ <producto>, ... ] }`, ordenados por nombre. Sin paginación: el catálogo de un depósito cabe en una respuesta.

#### Detalle

`GET /api/v1/productos/{id}`

- Respuesta `200`: el producto. `404 no_encontrado`.

#### Crear

`POST /api/v1/productos` · Solo caja

El cuerpo es el producto sin `id`, `foto`, `creado` ni `actualizado`. `existenciaPiezas` es la existencia inicial (por omisión `0`) y queda registrada como movimiento de inventario.

```json
{
  "codigo": "7501064191015",
  "nombre": "Victoria Mega",
  "categoria": "cerveza",
  "presentacion": "Mega 1.2 L",
  "precio": 4200,
  "precioCaja": 48000,
  "piezasPorCaja": 12,
  "existenciaPiezas": 66,
  "minimo": 36,
  "envase": "mega",
  "caducidad": "2027-01-29"
}
```

- Respuesta `201`: el producto creado. Emite `producto.actualizado`.
- `400 datos_invalidos`, `409 codigo_duplicado`.

#### Buscar por código de barras

`GET /api/v1/productos/codigo/{codigo}`

Lo usa el escáner: el código debe coincidir completo, no es una búsqueda.

- Respuesta `200`: el producto. `404 no_encontrado` si no hay un producto activo con ese código.

#### Editar

`PUT /api/v1/productos/{id}` · Solo caja

El cuerpo es el mismo que al crear y reemplaza todos los campos editables: un campo opcional que no viene queda en `null` (o `0` en `minimo`). Si viene `existenciaPiezas`, se ignora: las existencias solo cambian con [entradas](#recibir-mercancía) y [ajustes](#ajustar-existencia), para que editar el nombre no borre una venta hecha mientras el formulario estaba abierto.

- Respuesta `200`: el producto actualizado. Emite `producto.actualizado`.
- `400 datos_invalidos`, `404 no_encontrado`, `409 codigo_duplicado`.

#### Eliminar

`DELETE /api/v1/productos/{id}` · Solo caja

Borrado lógico: deja de aparecer en listas y búsquedas, pero sus ventas y movimientos se conservan. Su código queda libre para otro producto.

- Respuesta `204` sin cuerpo. Emite `producto.eliminado`. `404 no_encontrado`.

#### Recibir mercancía

`POST /api/v1/productos/{id}/entradas` · Solo caja

```json
{ "cajas": 5, "piezas": 3, "caducidad": "2027-03-15", "nota": "Proveedor Modelo" }
```

| Campo | Tipo | Regla |
| --- | --- | --- |
| `cajas` | entero o ausente | 0 o más. Solo si el producto tiene `piezasPorCaja` |
| `piezas` | entero o ausente | 0 o más, sueltas |
| `caducidad` | fecha o ausente | `AAAA-MM-DD` del lote que llega |
| `nota` | texto o ausente | Hasta 120 caracteres: proveedor, factura... |

- Entran `cajas × piezasPorCaja + piezas` piezas, que deben ser más de 0. Queda un movimiento `entrada`.
- `caducidad` del producto: si no tenía existencias o no tenía caducidad, toma la del lote; si no, se queda con la más próxima de las dos.
- Respuesta `200`: el producto actualizado. Emite `producto.actualizado`.
- `400 datos_invalidos`, `404 no_encontrado`.

#### Ajustar existencia

`POST /api/v1/productos/{id}/ajustes` · Solo caja

Corrige existencias fuera de una venta o entrada. Hay dos motivos:

```json
{ "motivo": "conteo", "existenciaPiezas": 60, "nota": "Conteo del lunes" }
```

```json
{ "motivo": "merma", "piezas": 3, "nota": "Se rompieron al bajar" }
```

| Campo | Tipo | Regla |
| --- | --- | --- |
| `motivo` | texto | `conteo` (se contó físicamente) o `merma` (rotas, caducadas, regaladas) |
| `existenciaPiezas` | entero | Solo con `conteo`: lo que se contó, 0 o más. Queda un movimiento `ajuste` por la diferencia |
| `piezas` | entero | Solo con `merma`: piezas que salen, mayor que 0. Queda un movimiento `merma` |
| `nota` | texto o ausente | Hasta 120 caracteres |

- Un `conteo` igual a la existencia actual no deja movimiento.
- Respuesta `200`: el producto actualizado. Emite `producto.actualizado`.
- `400 datos_invalidos`, `404 no_encontrado`, `409 stock_insuficiente` (merma mayor que la existencia).

#### Movimientos de un producto

`GET /api/v1/productos/{id}/movimientos`

- Respuesta `200`: los últimos 200, del más nuevo al más viejo:

```json
{
  "movimientos": [
    {
      "id": 412,
      "tipo": "venta",
      "piezas": -3,
      "existenciaResultante": 63,
      "referencia": "Folio 1001",
      "origen": "Caja",
      "nota": null,
      "fecha": "2026-10-02T18:30:00Z"
    }
  ]
}
```

- `tipo`: `inicial`, `entrada`, `venta`, `cancelacion`, `ajuste` o `merma`. `piezas` lleva signo.
- `404 no_encontrado`.

#### Foto

`PUT /api/v1/productos/{id}/foto` · Solo caja

El cuerpo es la imagen sin envolver (no `multipart`), con `Content-Type` `image/jpeg`, `image/png` o `image/webp`, de hasta 5 MB. La app la reduce antes de subirla (800 px de lado basta). Reemplaza la anterior.

- Respuesta `200`: el producto, con `foto` apuntando a la imagen nueva. Emite `producto.actualizado`.
- `400 datos_invalidos` (campo `foto`: tipo no permitido, vacía, muy grande o el contenido no es esa imagen), `404 no_encontrado`.

`GET /api/v1/productos/{id}/foto`

- Respuesta `200`: la imagen con su `Content-Type`. Lleva la misma autenticación que el resto (en Flutter, `Image.network(url, headers: {...})`). `404 no_encontrado` si no tiene foto.
- `foto` en el producto es la ruta relativa al servidor con una versión: `/api/v1/productos/p_3k9x2m7q1z/foto?v=1790965800000`. Cambia cada vez que se sube una, así la app puede guardarla en caché sin mostrar una vieja.

`DELETE /api/v1/productos/{id}/foto` · Solo caja

- Respuesta `200`: el producto con `foto: null`. Emite `producto.actualizado`. `404 no_encontrado`.

#### Importar desde CSV

`POST /api/v1/productos/importar` · Solo caja

Carga o actualiza muchos productos de una vez desde una hoja de cálculo guardada como CSV. Plantilla: [`docs/plantilla_inventario.csv`](plantilla_inventario.csv).

```json
{ "csv": "codigo,nombre,categoria,precio,existencia\n7501064191015,Victoria Mega,cerveza,42.00,66\n", "soloRevisar": true }
```

- `csv`: el texto del archivo, en UTF-8, hasta 2 MB y 5000 renglones de productos.
- `soloRevisar`: obligatorio. `true` revisa y dice qué haría sin guardar nada; `false` guarda.

**El archivo**

- El primer renglón son los nombres de las columnas, en cualquier orden y sin distinguir mayúsculas. Se separa con coma o con punto y coma (Excel en español guarda con `;`). Las celdas pueden ir entre comillas.
- Obligatorias: `codigo`, `nombre`, `categoria`, `precio`. Opcionales: `presentacion`, `precioCaja`, `piezasPorCaja`, `existencia`, `minimo`, `envase`, `caducidad`. Una columna con otro nombre es error.
- Mismas reglas que [Crear](#crear), salvo:
  - `precio` y `precioCaja` van **en pesos**: `42`, `42.50`, `$1,234.50`. Los centavos van con punto; `42,50` es error porque no se sabe si son pesos o centavos.
  - `caducidad` acepta `AAAA-MM-DD` o `DD/MM/AAAA`.
  - `existencia` son piezas.
- Los renglones vacíos se ignoran.

**Qué hace cada renglón** (se busca el producto activo por `codigo`)

| | Producto nuevo | Producto que ya existe |
| --- | --- | --- |
| Celda con valor | Se usa | Reemplaza el valor actual |
| Celda vacía o columna ausente | Valor por omisión de [Crear](#crear) | No cambia |
| `existencia` | Existencia inicial, con movimiento `inicial` | Se fija a ese número, con movimiento `ajuste` por la diferencia (como un conteo) |

Los movimientos llevan la nota `Importación CSV`. Un código repetido dentro del archivo es error en el segundo renglón.

**Todo o nada:** si un renglón tiene error, no se guarda ninguno.

- Respuesta `200`, en los dos modos:

```json
{
  "guardado": false,
  "creados": 118,
  "actualizados": 2,
  "sinCambios": 5,
  "cambiosExistencia": [
    { "renglon": 4, "codigo": "7501064191015", "nombre": "Victoria Mega", "antes": 66, "despues": 80 }
  ],
  "errores": [
    { "renglon": 14, "codigo": "7501055300846", "campos": { "precio": "Debe ser un precio en pesos con punto para los centavos, como 42.50" } }
  ]
}
```

- `guardado`: `true` solo si `soloRevisar` es `false` y no hubo errores.
- `renglon` es el número de renglón del archivo, como lo muestra Excel: el encabezado es el 1.
- `cambiosExistencia`: los productos que ya existían y cambian de existencia, para revisarlos antes de guardar.
- `errores`: por renglón, con la columna que falló. `codigo` es `null` si no se pudo leer.
- Al guardar emite `producto.actualizado` por cada producto creado o cambiado, y `alerta.nueva` si corresponde.
- `400 datos_invalidos` en `csv` si el archivo no se puede leer: vacío, demasiado grande, sin encabezado, falta una columna obligatoria o tiene una desconocida.

### Ventas

#### Registrar venta

`POST /api/v1/ventas` · Solo caja

Cobra, descuenta existencias y mueve envases en una sola transacción: o pasa todo o no pasa nada.

**Encabezado obligatorio `X-Clave-Idempotencia`:** un texto único por cobro, de 8 a 100 caracteres (la app genera uno al tocar "Cobrar" y lo reutiliza si reintenta). Si la clave ya se usó, el servidor responde la **misma venta** sin cobrar ni descontar otra vez. Así un reintento por mala red nunca cobra dos veces.

```json
{
  "metodo": "efectivo",
  "recibido": 60000,
  "envModo": "trae",
  "lineas": [
    { "productoId": "p_3k9x2m7q1z", "unidad": "caja", "cantidad": 1 },
    { "productoId": "p_3k9x2m7q1z", "unidad": "pieza", "cantidad": 2 }
  ]
}
```

| Campo | Tipo | Regla |
| --- | --- | --- |
| `metodo` | texto | `efectivo` o `tarjeta` |
| `recibido` | entero o ausente | Centavos que entregó el cliente en efectivo; no puede ser menor que el total. Si falta, se asume el monto exacto. Con `tarjeta` se ignora y se cobra exacto |
| `tarjeta` | texto o ausente | Tipo de tarjeta, hasta 20 caracteres |
| `envModo` | texto | Qué pasa con los envases retornables: `na` (por omisión), `cobrar` (se cobra el depósito), `trae` (el cliente trae vacíos: suben a bodega), `prestamo` (se le prestan) |
| `envCliente` | texto o ausente | Nombre del cliente para `prestamo`, hasta 80 caracteres |
| `envCredito` | objeto o ausente | Vacíos **extra** que entrega el cliente para que se le descuente su depósito: `{ "mega": 2, "media": 0 }`. Entran a bodega. El crédito es `cantidad × precio` del formato y se resta del total. No puede dejar el total en negativo (para eso está [Devolver depósito](#devolver-depósito)). Se combina con cualquier `envModo` |
| `usuarioId` | texto o ausente | Quien cobra (`u_...`), para el historial y "ventas del empleado" |
| `lineas` | lista | Al menos una. `unidad` es `pieza` o `caja`; `cantidad` es entero mayor que 0. Un producto puede venir en varias líneas. `descuento` (opcional) es un porcentaje entero de 0 a 99 |

**Descuento:** se calcula por unidad y se trunca al centavo: `precioUnit = precio − (precio × descuento ÷ 100)`, con división entera. Así cada unidad tiene un precio exacto y una devolución parcial regresa exactamente lo cobrado. Ejemplo: $42.00 con 15 % es `4200 − 630 = 3570`.

- Respuesta `201`:

```json
{
  "id": "v_7h2k9d1m3x",
  "folio": 1001,
  "fecha": "2026-10-02T18:30:00Z",
  "diaNegocio": "2026-10-02",
  "total": 56400,
  "metodo": "efectivo",
  "recibido": 60000,
  "cambio": 3600,
  "turnoId": "tur_4m8q2x7k1z"
}
```

- `total` = productos (ya con descuento) + depósito de envases − crédito por vacíos.
- Requiere turno abierto: la venta queda en ese turno (`turnoId`). Ver [Caja](#caja).
- Emite `producto.actualizado` por cada producto, `venta.registrada` y, si hubo envases, `envases.actualizado`.
- `400 datos_invalidos` (incluye falta de `X-Clave-Idempotencia`, un `usuarioId` que no existe o está inactivo, y un crédito mayor que el total), `404 no_encontrado` (producto), `409 stock_insuficiente`, `409 caja_cerrada`.

#### Listar ventas

`GET /api/v1/ventas?dia=2026-10-02` o `GET /api/v1/ventas?turno=actual`

- `dia` (opcional): día de negocio `AAAA-MM-DD`.
- `turno` (opcional): `actual` para las del turno abierto (lista vacía si la caja está cerrada) o el id de un turno (`tur_...`). No se combina con `dia`: si vienen los dos, `400 datos_invalidos`.
- `usuario` (opcional): solo las que cobró ese usuario (`u_...`). Se combina con `dia` o `turno`.
- Sin filtros, las últimas 100.
- Respuesta `200`: `{ "ventas": [ { "id", "folio", "fecha", "total", "metodo", "origen", "cancelada", "turnoId", "devuelto", "usuario" }, ... ] }`, del folio más nuevo al más viejo. `turnoId` es `null` en las ventas anteriores a la caja. `devuelto` son los centavos ya regresados por devoluciones parciales o cancelación. `usuario` es `{ "id", "nombre" }` o `null`.

#### Detalle de venta

`GET /api/v1/ventas/{id}`

- Respuesta `200`: la venta con `tarjeta`, `envModo`, `envN`, `envMonto`, `envCredito` (centavos), `origen`, `cancelada`, `turnoId`, `devuelto`, `usuario` y `lineas` (`lineaId`, `productoId`, `nombre`, `unidad`, `cantidad`, `piezas`, `precioLista`, `descuento`, `precioUnit`, `subtotal`, `devueltas`, `deposito`), más `devoluciones`: `[ { "id", "fecha", "monto", "destino", "motivo", "autorizo" } ]`. `devueltas` es cuántas unidades de la línea ya se devolvieron; `deposito`, los centavos de depósito que se cobraron por pieza (0 si no se cobró). `404 no_encontrado`.

#### Autorización

Cancelar y devolver necesitan el **PIN de un gerente o del dueño** en el campo `pin`, si hay al menos un usuario activo con esos roles. Mientras nadie se haya registrado (antes de crear la cuenta maestra), no se pide. Un PIN de cajero responde `403 sin_permiso`; uno que no existe, `403 pin_invalido`. Quien autorizó queda en la devolución (`autorizo`).

#### Cancelar venta

`POST /api/v1/ventas/{id}/cancelar` · Solo caja

```json
{ "pin": "4321", "destino": "inventario", "motivo": "El cliente se arrepintió" }
```

El cuerpo es opcional: sin `destino` es `inventario`. `destino` es `inventario` (la mercancía regresa a existencias) o `merma` (llegó rota o abierta: no regresa). `motivo` hasta 120 caracteres.

Regresa las existencias (queda como movimiento `cancelacion`) y revierte los envases: los vacíos que entraron a bodega, los vacíos vendidos (que regresan a bodega) y los préstamos de esa venta que no se han devuelto.

Solo se cancelan ventas del turno abierto: el dinero que se devuelve sale de ese turno y deja de contar en su resumen. Una venta de un turno con corte ya no se cancela, para que el corte no cambie después de cerrarse. Si ya tenía devoluciones parciales, se regresa solo lo que falta. También revierte el crédito por vacíos (esos vacíos salen de bodega).

- Respuesta `204`. Emite `producto.actualizado`, `envases.actualizado` y `venta.cancelada`.
- `400 datos_invalidos` si ya estaba cancelada, `403 pin_invalido` o `sin_permiso`, `404 no_encontrado`, `409 turno_cerrado` si la venta es de otro turno o anterior a la caja, `409 envases_insuficientes` si era `trae` (o tenía crédito) y esos vacíos ya no están en bodega (por ejemplo, se vendieron).

#### Devolver parte de una venta

`POST /api/v1/ventas/{id}/devolver` · Solo caja

El cliente regresa algunos productos. Mismas reglas de turno y autorización que [Cancelar venta](#cancelar-venta).

```json
{
  "lineas": [{ "lineaId": 12, "cantidad": 1 }],
  "destino": "merma",
  "motivo": "Botella rota",
  "pin": "4321"
}
```

- `cantidad` en la unidad de la línea (piezas o cajas), sin pasar de lo que falta por devolver.
- Se regresa `precioUnit × cantidad` de cada línea. Si la venta fue con `envModo`:
  - `cobrar`: también el depósito de esos envases;
  - `trae`: los vacíos que dejó el cliente salen de bodega;
  - `prestamo`: el préstamo de esa venta baja en esas piezas.
- Si con esta devolución ya no queda nada por devolver, la venta queda cancelada, igual que con [Cancelar venta](#cancelar-venta).
- Respuesta `201`: `{ "devolucion": { "id", "fecha", "monto", "destino", "motivo", "autorizo" }, "venta": <detalle de venta> }`. Emite `producto.actualizado` (si `inventario`), `envases.actualizado` si cambió el balance, y `venta.devuelta` (`{ "id", "monto" }`).
- `400 datos_invalidos` (línea que no es de la venta o cantidad de más), `403 pin_invalido` o `sin_permiso`, `404 no_encontrado`, `409 turno_cerrado`, `409 envases_insuficientes`.

### Caja

Un turno empieza al abrir la caja con un fondo inicial y termina con el corte: se cuenta el efectivo y se compara con lo esperado. Solo puede haber un turno abierto. Sin turno abierto no se cobra (`409 caja_cerrada`). Un turno puede cruzar la medianoche: el corte es del turno, no del día.

Todo en esta sección es **Solo caja**.

Con datos de ejemplo (`datosEjemplo`, la app en desarrollo y `bin/server.dart`), el servidor abre un turno con fondo de $500.00 la primera vez que arranca, para poder cobrar desde el inicio. Después de un corte, la caja se queda cerrada.

**El turno** (`<turno>`), igual abierto que cerrado:

```json
{
  "id": "tur_4m8q2x7k1z",
  "estado": "abierto",
  "apertura": "2026-10-24T14:00:00Z",
  "cierre": null,
  "diaNegocio": "2026-10-24",
  "fondo": 50000,
  "resumen": {
    "ventas": 42,
    "canceladas": 1,
    "ventasEfectivo": 1250000,
    "ventasTarjeta": 380000,
    "envases": 9600,
    "devoluciones": 0,
    "ingresos": 20000,
    "retiros": 15000,
    "esperado": 1305000
  },
  "contado": null,
  "diferencia": null,
  "nota": null
}
```

| Campo | Regla |
| --- | --- |
| `estado` | `abierto` o `cerrado` |
| `diaNegocio` | Día de negocio de la apertura |
| `fondo` | Centavos en efectivo con que se abrió |
| `resumen.ventas` | Ventas no canceladas del turno, incluidas las de vacíos |
| `resumen.canceladas` | Ventas del turno que se cancelaron |
| `resumen.ventasEfectivo`, `resumen.ventasTarjeta` | Lo cobrado por método, menos lo devuelto (cancelaciones y devoluciones parciales) de ese método. El total ya incluye el depósito de envases y el crédito por vacíos |
| `resumen.envases` | De esas sumas, cuánto fue depósito de envases y venta de vacíos, menos el crédito por vacíos. Es informativo: no se suma otra vez |
| `resumen.devoluciones` | Centavos regresados en el turno por cancelaciones y devoluciones parciales, de los dos métodos. Informativo |
| `resumen.ingresos`, `resumen.retiros` | Suma de los [movimientos de caja](#registrar-movimiento) |
| `resumen.esperado` | `fondo + ventasEfectivo + ingresos − retiros`: el efectivo que debe haber en el cajón |
| `contado` | Efectivo contado al cerrar. `null` mientras está abierto |
| `diferencia` | `contado − esperado`. Negativo es faltante, positivo es sobrante. `null` mientras está abierto |
| `nota` | Justificación del cierre, o `null` |
| `usuarioApertura`, `usuarioCierre` | `{ "id", "nombre" }` de quien abrió o cerró, o `null` |

El `resumen` de un turno cerrado queda fijo al cerrar: no cambia aunque después se edite un producto o un envase.

**El movimiento de caja** (`<movimiento>`): efectivo que entra o sale del cajón sin ser una venta (pagar el hielo al proveedor, poner más cambio).

```json
{ "id": "mc_9x2k7d1m3q", "tipo": "retiro", "monto": 15000, "motivo": "Pago proveedor hielo", "fecha": "2026-10-24T17:20:00Z" }
```

#### Turno actual

`GET /api/v1/caja/turno`

- Respuesta `200`: `{ "turno": <turno>, "movimientos": [ <movimiento>, ... ] }`, con los movimientos del más viejo al más nuevo. Si la caja está cerrada: `{ "turno": null, "movimientos": [] }`.

#### Abrir caja

`POST /api/v1/caja/abrir`

```json
{ "fondo": 50000, "usuarioId": "u_..." }
```

- `fondo`: entero mayor o igual que 0, en centavos. `usuarioId` opcional: quien abre.
- Respuesta `201`: `{ "turno": <turno> }`. Emite `caja.abierta`.
- `400 datos_invalidos`, `409 caja_abierta`.

#### Registrar movimiento

`POST /api/v1/caja/movimientos`

Lleva el encabezado obligatorio `X-Clave-Idempotencia`, igual que [Registrar venta](#registrar-venta): un reintento no registra el retiro dos veces.

```json
{ "tipo": "retiro", "monto": 15000, "motivo": "Pago proveedor hielo" }
```

| Campo | Regla |
| --- | --- |
| `tipo` | `ingreso` o `retiro` |
| `monto` | Entero mayor que 0, en centavos. Un retiro no puede dejar el esperado en negativo |
| `motivo` | Obligatorio, de 1 a 120 caracteres |

- Respuesta `201`: `{ "movimiento": <movimiento>, "turno": <turno> }`. Emite `caja.actualizada`.
- `400 datos_invalidos` (incluye un retiro mayor que el esperado), `409 caja_cerrada`.

#### Cerrar caja (corte)

`POST /api/v1/caja/cerrar`

Lleva el encabezado obligatorio `X-Clave-Idempotencia`: si la respuesta se pierde y la app reintenta, recibe el mismo corte en lugar de `409 caja_cerrada`.

```json
{ "contado": 1300000, "nota": "Faltó cambio al cliente de la mañana", "usuarioId": "u_..." }
```

| Campo | Regla |
| --- | --- |
| `contado` | Entero mayor o igual que 0, en centavos |
| `nota` | Hasta 200 caracteres. **Obligatoria si `contado` no coincide con el esperado** |
| `usuarioId` | Opcional: quien hace el corte |

- Respuesta `200`: `{ "turno": <turno> }`, ya `cerrado`, con `contado`, `diferencia` y `nota`. Emite `caja.cerrada`.
- `400 datos_invalidos` (incluye falta de `nota` con diferencia), `409 caja_cerrada`.

#### Cortes anteriores

`GET /api/v1/caja/cortes?desde=2026-10-01&hasta=2026-10-31`

- `desde` y `hasta` (opcionales): días de negocio `AAAA-MM-DD`, inclusivos, sobre el `diaNegocio` del turno. Sin ellos, los últimos 30 cortes.
- Respuesta `200`: `{ "cortes": [ <turno>, ... ] }`, solo turnos cerrados, del más nuevo al más viejo.

#### Detalle de corte

`GET /api/v1/caja/cortes/{id}`

- Respuesta `200`: `{ "turno": <turno>, "movimientos": [ <movimiento>, ... ] }`. Sirve también para el turno abierto. `404 no_encontrado`.

Las ventas del turno se piden con [Listar ventas](#listar-ventas) y `?turno=tur_...`.

### Pedidos

Una terminal arma el pedido del cliente y lo manda a la caja para cobrarlo.

#### Crear pedido

`POST /api/v1/pedidos`

```json
{
  "nota": "Mesa 3",
  "lineas": [{ "productoId": "p_3k9x2m7q1z", "unidad": "pieza", "cantidad": 2 }]
}
```

- `nota`: opcional, hasta 120 caracteres. Las líneas siguen las reglas de las ventas y el producto debe existir. No se revisan existencias: se revisan al cobrar.
- Respuesta `201`: `{ "id", "origen", "fecha", "nota", "lineas" }`. Emite `pedido.creado`.
- `400 datos_invalidos`.

#### Pedidos pendientes

`GET /api/v1/pedidos`

- Respuesta `200`: `{ "pedidos": [ <pedido>, ... ] }`, del más viejo al más nuevo.

#### Descartar o marcar como cobrado

`DELETE /api/v1/pedidos/{id}` · Solo caja

- Respuesta `204`. Emite `pedido.atendido`. `404 no_encontrado` si no existe o ya se atendió.

### Envases

Los formatos retornables son `mega`, `media` y `cuarto`. `precio` es el depósito por envase, en centavos.

#### Balance

`GET /api/v1/envases`

- Respuesta `200`:

```json
{
  "balance": {
    "mega": { "bodega": 84, "prestados": 36, "precio": 800 },
    "media": { "bodega": 240, "prestados": 48, "precio": 300 },
    "cuarto": { "bodega": 168, "prestados": 24, "precio": 300 }
  }
}
```

#### Préstamos activos

`GET /api/v1/envases/prestamos`

- Respuesta `200`: `{ "prestamos": [ { "id", "cliente", "telefono", "formato", "cantidad", "devueltos", "fecha" }, ... ] }`, sin los devueltos por completo. `cantidad` es lo que falta por devolver y `devueltos`, lo que ya regresó en devoluciones parciales.

#### Prestar envases

`POST /api/v1/envases/prestamos` · Solo caja

```json
{ "cliente": "Don Pedro", "telefono": "55 1234 5678", "formato": "mega", "cantidad": 10 }
```

Se le prestan **vacíos de bodega**: salen de bodega y pasan a prestados. (Los préstamos que nacen de una venta con `envModo: "prestamo"` no tocan bodega: salen llenos.)

- `telefono` opcional, hasta 20 caracteres.
- Respuesta `201`: el préstamo. Emite `envases.actualizado`. `400 datos_invalidos`, `409 envases_insuficientes`.

#### Devolver préstamo

`POST /api/v1/envases/prestamos/{id}/devolver` · Solo caja

Los envases regresan a bodega. El cuerpo es opcional:

```json
{ "cantidad": 4 }
```

- Sin cuerpo (o sin `cantidad`) se devuelve todo lo pendiente.
- `cantidad`: entero mayor que 0 y no mayor que lo pendiente. Si es menor, el préstamo sigue activo con lo que falta.
- Respuesta `204`. Emite `envases.actualizado`. `400 datos_invalidos`, `404 no_encontrado` si no existe o ya se devolvió.

#### Recibir vacíos

`POST /api/v1/envases/entrada` · Solo caja

Entran envases vacíos a bodega sin una venta (por ejemplo, los que deja el proveedor).

```json
{ "formato": "mega", "cantidad": 24 }
```

- `cantidad`: entero mayor que 0.
- Respuesta `200`: `{ "balance": <balance> }`. Emite `envases.actualizado`. `400 datos_invalidos`.

#### Sacar vacíos

`POST /api/v1/envases/salida` · Solo caja

Salen vacíos de bodega sin cobro (por ejemplo, se los lleva el proveedor o se rompieron).

```json
{ "formato": "mega", "cantidad": 24, "motivo": "Cambio con el proveedor" }
```

- `motivo` obligatorio, hasta 120 caracteres.
- Respuesta `200`: `{ "balance": <balance> }`. Emite `envases.actualizado`. `400 datos_invalidos`, `409 envases_insuficientes`.

#### Devolver depósito

`POST /api/v1/envases/devolucion-deposito` · Solo caja

El cliente regresa vacíos por los que pagó depósito y se le devuelve el dinero en efectivo. Los vacíos entran a bodega y el dinero sale del cajón como un [retiro de caja](#registrar-movimiento) con motivo "Devolución de depósito". Lleva `X-Clave-Idempotencia`.

```json
{ "formato": "media", "cantidad": 12, "cliente": "Don José" }
```

- `cliente` opcional, hasta 80 caracteres. El monto es `cantidad × precio` del formato.
- Respuesta `201`: `{ "balance": <balance>, "movimiento": <movimiento de caja>, "turno": <turno> }`. Emite `envases.actualizado` y `caja.actualizada`.
- `400 datos_invalidos` (incluye un monto mayor que el efectivo esperado), `409 caja_cerrada`.

#### Movimientos de envases

`GET /api/v1/envases/movimientos?limite=50`

Bitácora de todo lo que cambia el balance, del más nuevo al más viejo. `limite` de 1 a 200, 50 por omisión.

- Respuesta `200`:

```json
{
  "movimientos": [
    {
      "id": 31,
      "fecha": "2026-10-24T17:20:00Z",
      "formato": "media",
      "tipo": "devolucion_deposito",
      "bodega": 12,
      "prestados": 0,
      "cliente": "Don José",
      "monto": -3600,
      "referencia": null
    }
  ]
}
```

| Campo | Regla |
| --- | --- |
| `tipo` | `entrada`, `salida`, `prestamo`, `devolucion_prestamo`, `venta_trae`, `venta_prestamo`, `credito`, `venta_vacios`, `devolucion_deposito`, `cancelacion` |
| `bodega`, `prestados` | Cambio con signo en cada uno |
| `monto` | Centavos que entraron (+) o salieron (−) de caja por ese movimiento, o `null` |
| `referencia` | `Folio 1001` u otra referencia, o `null` |

#### Vender vacíos

`POST /api/v1/envases/venta-vacios` · Solo caja

Cobra envases vacíos de bodega al precio de depósito. Es un cobro: queda como venta con folio (sin `lineas`, con `envModo: "cobrar"`), aparece en el historial y se cancela con [Cancelar venta](#cancelar-venta), que regresa los envases a bodega.

Lleva el encabezado obligatorio `X-Clave-Idempotencia`, igual que [Registrar venta](#registrar-venta).

```json
{ "formato": "mega", "cantidad": 10, "metodo": "efectivo", "recibido": 10000 }
```

- `metodo`, `recibido` y `tarjeta` siguen las reglas de Registrar venta. El total es `cantidad × precio` del formato.
- Requiere turno abierto, igual que Registrar venta.
- Respuesta `201`: la venta, con la misma forma que en Registrar venta. Emite `envases.actualizado` y `venta.registrada`.
- `400 datos_invalidos`, `409 envases_insuficientes`, `409 caja_cerrada`.

### Usuarios

Personal del depósito con PIN. El primero es el dueño (la "cuenta maestra"). Todo es **Solo caja**.

**El usuario** (`<usuario>`); el PIN nunca sale del servidor:

```json
{ "id": "u_8k2m4x9q1z", "nombre": "Sofía Vega", "rol": "cajero", "activo": true, "creado": "2026-10-24T14:00:00Z" }
```

- `rol`: `dueno`, `gerente` o `cajero`.
- El PIN es de 4 a 6 dígitos y no se repite entre usuarios activos: así un PIN solo identifica a una persona.

#### Listar usuarios

`GET /api/v1/usuarios`

- Respuesta `200`: `{ "usuarios": [ <usuario>, ... ] }`, por nombre, activos e inactivos.

#### Crear usuario

`POST /api/v1/usuarios`

```json
{ "nombre": "Sofía Vega", "rol": "cajero", "pin": "482913" }
```

- El primer usuario debe ser `dueno`. Después, crear un usuario necesita `pinAutoriza`: el PIN de un dueño o gerente activo (`403 pin_invalido` o `sin_permiso`).
- Respuesta `201`: `{ "usuario": <usuario> }`. `400 datos_invalidos` (incluye un PIN repetido).

#### Editar usuario

`PUT /api/v1/usuarios/{id}`

```json
{ "nombre": "Sofía Vega", "rol": "gerente", "activo": true, "pin": "123456", "pinAutoriza": "4321" }
```

- Todos los campos son opcionales salvo `pinAutoriza` (dueño o gerente activo). Solo un dueño puede crear, editar o dar de baja a otro dueño.
- No se puede dejar el depósito sin un dueño activo (`400 datos_invalidos`).
- Respuesta `200`: `{ "usuario": <usuario> }`. `403`, `404 no_encontrado`.

#### Verificar PIN

`POST /api/v1/usuarios/verificar`

```json
{ "pin": "482913", "usuarioId": "u_8k2m4x9q1z" }
```

Para el inicio de turno ("selecciona tu usuario y escribe tu PIN") y para pedir autorización antes de una acción. `usuarioId` es opcional: sin él, busca de quién es el PIN.

- Respuesta `200`: `{ "usuario": <usuario> }`. `403 pin_invalido`, `429 demasiados_intentos`.

### Alertas

Productos por resurtir o por revisar su caducidad. Se calculan en cada petición: no se guardan ni se marcan como vistas.

#### Listar alertas

`GET /api/v1/alertas?dias=15`

- `dias` (opcional): cuántos días hacia adelante se revisan las caducidades, de 1 a 365. Por omisión `15`, lo que muestra el Inicio. Otro valor es `400 datos_invalidos` con `campos.dias`.
- Respuesta `200`:

```json
{
  "dia": "2026-10-26",
  "dias": 15,
  "alertas": [
    { "tipo": "agotado", "producto": { "id": "p_3k9x2m7q1z", "existenciaPiezas": 0, "minimo": 36 }, "diasParaCaducar": null },
    { "tipo": "por_caducar", "producto": { "id": "p_8d1w5n0r4t", "caducidad": "2026-11-02" }, "diasParaCaducar": 7 }
  ]
}
```

(`producto` es el [objeto producto](#el-objeto-producto) completo; aquí va recortado).

| `tipo` | Cuándo |
| --- | --- |
| `agotado` | `minimo` mayor que 0 y `existenciaPiezas` en 0 |
| `poco_stock` | `existenciaPiezas` mayor que 0 y menor que `minimo` |
| `caducado` | Hay existencia y la `caducidad` es anterior a hoy |
| `por_caducar` | Hay existencia y la `caducidad` es hoy o dentro de los próximos `dias` |

- Un producto con `minimo` en `0` nunca tiene alerta de existencia. Sin existencia no tiene alerta de caducidad: no hay nada que revisar en bodega.
- Un producto puede salir dos veces: una por existencia y otra por caducidad.
- `dia` es hoy en la hora local del negocio, el día contra el que se calculó todo.
- `diasParaCaducar`: días de `dia` a la caducidad. `0` caduca hoy, negativo ya caducó. `null` en las alertas de existencia.
- Orden: `agotado`, `poco_stock` (el que tiene menos existencia respecto a su mínimo primero), `caducado` (el más vencido primero) y `por_caducar` (el más próximo primero). Empates por nombre.
- Lo pueden pedir la caja y las terminales.

Para el contador de la campana, la app vuelve a pedir esta lista al recibir `alerta.nueva`, `producto.actualizado` o `producto.eliminado` y al reconectarse.

### Ajustes

Datos del negocio para el ticket y la cuenta maestra.

#### Leer ajustes

`GET /api/v1/ajustes`

- Respuesta `200`: `{ "nombreNegocio": "Depósito Don Beto", "direccion": "Av. Central Pte. 120", "telefono": "961 123 4567", "mensajeTicket": "Gracias por su compra" }`. Los que no se han capturado son `null`.

#### Guardar ajustes

`PUT /api/v1/ajustes` · Solo caja

- Mismos campos, todos opcionales: los que vienen se reemplazan. `nombreNegocio` y `direccion` hasta 80 caracteres, `telefono` hasta 20 y `mensajeTicket` hasta 120. `null` borra un campo.
- Respuesta `200`: los ajustes. `400 datos_invalidos`.

### Respaldo

#### Descargar respaldo

`GET /api/v1/respaldo` · Solo caja

Copia completa y consistente de la base, para guardarla fuera del iPad.

- Respuesta `200`: el archivo SQLite (`application/vnd.sqlite3`), con `content-disposition: attachment; filename="anaquel-AAAAMMDD-HHMMSS.db"`.

Restaurar un respaldo lo hace la app **antes** de arrancar el servidor (al configurar la caja): reemplaza el archivo de la base. No hay endpoint para restaurar con el servidor andando.

## WebSocket

`GET /api/v1/ws`

Lleva la misma autenticación que el resto: el encabezado `X-Clave-Terminal`, o `?clave=` en la URL si el cliente no puede mandar encabezados.

Todos los mensajes del servidor tienen esta forma:

```json
{ "tipo": "producto.actualizado", "datos": { "producto": { } }, "fecha": "2026-10-02T18:30:00Z" }
```

| Tipo | Cuándo | `datos` |
| --- | --- | --- |
| `conexion.lista` | Al conectarse | `{ "version": "0.1.0" }` |
| `producto.actualizado` | Se crea o cambia un producto (también por ventas, cancelaciones, entradas, ajustes y fotos) | `{ "producto": <producto> }` |
| `producto.eliminado` | Se elimina un producto | `{ "id": "p_..." }` |
| `pedido.creado` | Una terminal manda un pedido | `{ "pedido": <pedido> }` |
| `pedido.atendido` | La caja descarta o cobra un pedido | `{ "id": "ped_..." }` |
| `envases.actualizado` | Cambia el balance de envases | `{ "balance": <balance> }` |
| `venta.registrada` | Se cobra una venta o una venta de vacíos | `{ "venta": <venta> }`, con la forma de la respuesta de Registrar venta y `turnoId` |
| `venta.cancelada` | Se cancela una venta | `{ "id": "v_..." }` |
| `venta.devuelta` | Se devuelve parte de una venta | `{ "id": "v_...", "monto": 4200 }` |
| `caja.abierta` | Se abre un turno | `{ "turno": <turno> }` |
| `caja.actualizada` | Se registra un movimiento de caja | `{ "turno": <turno> }` |
| `caja.cerrada` | Se hace el corte | `{ "turno": <turno> }` |
| `alerta.nueva` | Un producto baja de su mínimo o se agota (ver abajo) | `{ "alerta": <alerta> }`, con la forma de un elemento de [Listar alertas](#listar-alertas) |

Los eventos `caja.*` **solo se mandan a la caja**: el `<turno>` trae montos que una terminal no puede pedir (la sección [Caja](#caja) es Solo caja). Los demás eventos llegan a todos.

`alerta.nueva` se manda cuando la alerta de existencia de un producto empeora: de nada a `poco_stock` o `agotado`, o de `poco_stock` a `agotado`. Da igual la causa: venta, merma, conteo, alta del producto o un mínimo editado. Mientras siga igual no se repite; si se resurte y vuelve a bajar, se manda otra vez. Las caducidades no mandan evento porque cambian con el día, no con una operación.

Se sigue mandando también `producto.actualizado`, así que una pantalla que ya escucha ese evento queda al día sin escuchar `alerta.nueva`. Sirve para la notificación.

- El servidor manda ping cada 20 segundos. Si no hay respuesta, cierra la conexión.
- Al reconectarse, la app vuelve a pedir los datos completos con `GET` en lugar de confiar en los eventos que se perdió.
- El cliente no manda mensajes por ahora.

## Pendientes

Se documentarán aquí, en este orden:

- **Sprint 4:** reportes, resurtido y diagnóstico.
