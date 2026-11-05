# Estándares técnicos

Estas reglas son obligatorias en `backend/` y `app/`. Cada una previene un tipo de error que en proyectos reales se corrige una y otra vez: es más barato evitarlo desde el primer commit.

Un PR que no las cumple no se aprueba, aunque funcione.

## Dinero

- Se maneja como **entero en centavos** en la API, la base de datos y el código. `$42.50` es `4250`.
- Un número con decimales en la API es `datos_invalidos`. **No se redondea.**
- En la app hay **un solo formateador de moneda**, en `core/`. Ninguna pantalla formatea dinero por su cuenta.
- Todo cálculo de dinero (cambio, total, envases, corte) tiene prueba unitaria.

## Fechas

- Los instantes se guardan y viajan en **UTC**, con `instanteIso()`: `2026-10-02T18:30:00Z`.
- El **día del negocio** se calcula solo con `diaNegocio()`, con la zona horaria de los ajustes. Nunca con `DateTime.now().day` ni con la zona del dispositivo.
- Los rangos de un día para reportes y cortes salen de `rangoDiaNegocio()`.
- Toda función que dependa de la hora recibe un `Reloj`, para probarla con fechas fijas.
- Las fechas de calendario (caducidad) son texto `AAAA-MM-DD`.
- Hay pruebas con ventas a las 23:59 y a las 00:01 hora local.

## Datos

- Toda operación de dinero o existencias va dentro de `transaccion()`: termina completa o no se hace.
- Cada cambio de existencia deja un registro en `movimientos`, con tipo, piezas con signo, origen y fecha. Esa tabla nunca se edita ni se borra.
- Los duplicados se impiden **en la base** con `UNIQUE`, no solo en el código.
- Con borrado lógico, los índices únicos son parciales (`WHERE eliminado = 0`).
- Ventas y cortes nunca se borran: se cancelan y queda el registro.
- Los cobros llevan clave de idempotencia (`X-Clave-Idempotencia`), para que un reintento no cobre dos veces.

## Migraciones

- Una migración nueva es un archivo nuevo en `backend/lib/src/db/migraciones/` con el siguiente número, registrado en `migraciones.dart`.
- **Nunca** se edita una migración que ya salió en un tag.
- El CI aplica todas las migraciones sobre una base vacía.

## API y errores

- Ningún endpoint se programa sin estar antes en `docs/API.md`.
- Todo error sale con el formato del contrato. Las rutas y servicios lanzan `ErrorApi`; el middleware lo responde.
- Los errores de validación devuelven `campos`, para que la app marque el campo que falló.
- Un error no previsto queda en el log con su pila y al cliente le llega `error_interno`, sin detalles técnicos.
- La autenticación vive en un solo middleware, para HTTP y WebSocket.
- Los eventos del WebSocket se emiten **después** de confirmar la transacción.

## Capas

| Capa | Hace | No hace |
| --- | --- | --- |
| `rutas/` | Lee la petición, llama al servicio, responde | Reglas de negocio, SQL |
| `servicios/` | Valida y aplica reglas de negocio, abre transacciones, emite eventos | SQL directo |
| `db/` | SQL y conversión de filas a modelos | Reglas de negocio |

En la app, cada `feature` tiene `datos` (llamadas a la API), `estado` (providers) y `pantallas` (widgets).

## Interfaz

- Componentes compartidos en `core/widgets/` para confirmar, mostrar errores, estado vacío y cargando. No se crea un diálogo nuevo por pantalla.
- Toda pantalla que carga datos maneja cargando, error, vacío y con datos.
- Al reconectarse, la app vuelve a pedir los datos completos.
- Los textos visibles van en `app/lib/core/textos.dart` (`Textos.*`), con acentos. Los textos propios de una sola pantalla pueden quedarse en su archivo; si se repiten, se mueven a `Textos`.

## Código

- `dart format` antes de cada commit. El CI lo revisa.
- Cero avisos de `dart analyze` / `flutter analyze`.
- Nombres de clases, variables y endpoints en español sin acentos: `Producto`, `precioCaja`, `diaNegocio`.
- Comentarios solo donde la lógica no es obvia: dinero, envases, fechas, resurtido.
- Nada sensible en el repo: claves de Apple, keystores, bases de datos con datos reales.

## Commits y ramas

- Ramas: `feature/back-...`, `feature/front-...`, `fix/...`, `chore/...`, desde `develop`.
- Commits con prefijo y la tarjeta de Trello: `feat(back): registrar venta (ANQ-12)`.
- **Hotfix** en producción: rama `hotfix/...` desde `main`, corrección con prueba, PR a `main` y a `develop`, sube el número de parche.
