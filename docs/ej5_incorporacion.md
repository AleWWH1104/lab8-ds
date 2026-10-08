# Ejercicio 5 - Incorporacion de los datos de 2024

Script de descarga: [`scripts/download_data.py`](../scripts/download_data.py)
Consultas de validacion: [sql/ej5_validacion.sql](../sql/ej5_validacion.sql)
SQL y resultados completos: [resultados/ej5_validacion.md](resultados/ej5_validacion.md)

Resultados de los Ej. 3 y 4 con los dos anios:
[resultados/ej3_exploracion_2024_2026.md](resultados/ej3_exploracion_2024_2026.md) y
[resultados/ej4_analisis_2024_2026.md](resultados/ej4_analisis_2024_2026.md)

Ejecutar:

```bash
docker compose exec lab python scripts/download_data.py
docker compose exec lab python scripts/download_data.py --verificar
docker compose exec lab python scripts/run_sql.py sql/ej5_validacion.sql --md docs/resultados/ej5_validacion.md
```

## 5.1 Cambios al sistema de descarga

El script del Ej. 2 ya recibia los anios como parametro (`--anios`), asi que descargar 2024 no requirio cambiar la logica, solo el comando:

```bash
docker compose exec lab python scripts/download_data.py --anios 2024 2026
```

El unico cambio en el codigo fue el valor por defecto: `ANIOS_POR_DEFECTO = (2024, 2026)` (antes `(2026,)`). Asi, ejecutar el script sin argumentos reproduce el conjunto con el que trabaja el laboratorio, y la persona que siga el README no tiene que recordar que anios pasar. En el Ej. 8 basta con agregar 2025 a esa tupla.

## 5.2 - 5.4 Ejecucion

Primera corrida con `--anios 2024 2026` (2026-10-08):

```text
descargados   : 24
ya existian   : 16
no publicados : 8   (yellow y green 2026-09 a 2026-12)
fallidos      : 0
```

- 5.2: los 16 archivos de 2026 se conservaron. Sus fechas de modificacion no cambiaron (siguen siendo las de la descarga del Ej. 2) y el script los reporto como "ya existian".
- 5.3: una segunda corrida dio `descargados: 0`, `ya existian: 40`. Los archivos validos se omiten sin consultar el servidor.
- 5.4: `--verificar` reporto `completos: 40`, `faltantes: 0`.

Estructura resultante:

```text
data/raw/
+-- yellow/2024/  12 archivos (2024-01 a 2024-12)  667 MB
+-- yellow/2026/   8 archivos (2026-01 a 2026-08)  505 MB
+-- green/2024/   12 archivos (2024-01 a 2024-12)   15 MB
+-- green/2026/    8 archivos (2026-01 a 2026-08)  7.9 MB
```

## 5.5 - 5.6 Validacion con DuckDB (5.8 documentacion de las consultas)

Todas las consultas estan en `sql/ej5_validacion.sql`. El bloque `-- 0` es el mismo del Ej. 4 (vistas `yellow`, `green`, `viajes` y `viajes_limpios`), sin ningun cambio.

### 5.5 Archivos por tipo y anio

- Objetivo: confirmar que estan los 12 meses de 2024 y los 8 de 2026.
- Fuente: `glob('data/raw/*/*/*.parquet')`.
- Resultado: yellow y green tienen 12 archivos de 2024 (2024-01 a 2024-12) y 8 de 2026 (2026-01 a 2026-08). En total 40.
- Decision: el conjunto esta completo.

### 5.5 Registros segun metadatos y segun lectura de datos

- Objetivo: comprobar que DuckDB lee todos los registros de los archivos nuevos. Se compara el conteo de los metadatos de cada Parquet con un `count(*)` que lee los datos a traves de la vista `viajes`.
- Fuente: `parquet_file_metadata('data/raw/*/*/*.parquet')` y la vista `viajes`.

| tipo | anio | archivos | registros (metadatos) | registros (leidos) | coinciden |
|---|---:|---:|---:|---:|---|
| yellow | 2024 | 12 | 41,169,720 | 41,169,720 | si |
| yellow | 2026 | 8 | 29,703,355 | 29,703,355 | si |
| green | 2024 | 12 | 660,218 | 660,218 | si |
| green | 2026 | 8 | 337,114 | 337,114 | si |

- Resultado: en total hay 71,870,407 registros, 2.4 veces lo que habia solo con 2026, y los dos conteos coinciden.
- Decision: no se pierden registros al leer los archivos nuevos.

### 5.6 Consulta conjunta de 2024 y 2026 por mes

- Objetivo: demostrar que una sola consulta trabaja con los dos anios y compararlos mes a mes.
- Fuente: vista `viajes`.
- Resultado:
  - yellow tiene mas viajes en 2026 en todos los meses comparables: +25.6% en enero y entre +8% y +15% de febrero a agosto.
  - green tiene menos viajes en 2026 en todos los meses: entre -19% y -30%.
  - Septiembre a diciembre aparecen como -100% porque esos meses de 2026 todavia no estan publicados. No es una caida real: esos meses se deben excluir al comparar anios.

### 5.6 Rango de fechas por anio de archivo

| tipo | anio | meses | pickup minimo | pickup maximo | fuera del mes |
|---|---:|---:|---|---|---:|
| yellow | 2024 | 12 | 2002-12-31 | 2026-06-26 | 420 |
| yellow | 2026 | 8 | 2001-01-01 | 2026-08-31 | 146 |
| green | 2024 | 12 | 2008-12-31 | 2025-01-01 | 164 |
| green | 2026 | 8 | 2008-12-31 | 2026-08-31 | 98 |

- Resultado: 2024 tiene el mismo problema que 2026: unos cientos de viajes con fecha fuera del mes del archivo. Uno de ellos, en un archivo de 2024, tiene fecha de 2026-06-26.
- Decision: por eso el anio de un viaje se toma del nombre del archivo (`anio_archivo`) y no de `year(pickup)`. El filtro base descarta los viajes con fecha fuera del mes, y asi ese registro no se cuenta como viaje de 2026.

## 5.7 Las consultas anteriores necesitan cambios?

Se volvieron a ejecutar `sql/ej3_exploracion.sql` y `sql/ej4_analisis.sql` sin cambiar las rutas. Las vistas leen `data/raw/<tipo>/*/*.parquet`, asi que incluyeron 2024 automaticamente.

### Esquema

| tipo | columna | archivos con la columna | desde | hasta |
|---|---|---:|---|---|
| yellow y green | `cbd_congestion_fee` | 8 de 20 | 2026-01 | 2026-08 |
| yellow y green | `request_source` | 3 de 20 | 2026-06 | 2026-08 |

- `cbd_congestion_fee` no existe en 2024: el cargo por entrar a la zona de congestion de Manhattan empezo en enero de 2025. Gracias a `union_by_name = true`, DuckDB la deja en NULL en los archivos de 2024 y la vista `viajes` no falla.
- Ninguna columna cambia de tipo de dato entre anios (la consulta "Columnas con tipo de dato distinto entre anios" devuelve 0 filas).

### Categorias y nulos por anio

| tipo | anio | % `cbd_congestion_fee` nulo | % `payment_type = 0` | % `payment_type` nulo | proveedores |
|---|---:|---:|---:|---:|---|
| yellow | 2024 | 100 | 9.94 | 0 | 1, 2, 6, 7 |
| yellow | 2026 | 0 | 25.98 | 0 | 1, 2, 6, 7 |
| green | 2024 | 100 | 0 | 3.68 | 1, 2 |
| green | 2026 | 0 | 0 | 14.47 | 1, 2, 6 |

- Flex Fare (`payment_type = 0`) ya existia en 2024, pero era el 10% de yellow. En 2026 es el 26%.
- En green, los pagos nulos subieron de 3.7% a 14.5%, y en 2026 aparece el proveedor 6. Esto confirma lo del Ej. 4: los nulos de green en 2026 vienen sobre todo del proveedor 6.

### Resultado de volver a correr los Ej. 3 y 4

Las consultas se ejecutan sin errores de sintaxis ni de esquema, pero se encontraron cuatro cosas:

1. **Hubo que ajustar la memoria.** Con 72 millones de registros, la ultima consulta del Ej. 4 fallo con `Out of Memory Error` (limite de 4 GB del contenedor). La deduplicacion con `QUALIFY row_number() OVER (...)` necesita tener en memoria todas las columnas de cada particion, y ese operador no logro pasar suficiente a disco. Bajar los hilos (`SET threads`) no lo resolvio. Se cambio por `SELECT DISTINCT ON (<llave del viaje>) *`, que DuckDB resuelve como una agregacion y puede pasar a disco. Ademas se agrego `SET temp_directory = 'data/processed/tmp'`, porque una base en memoria no tiene carpeta temporal por defecto. El resultado es el mismo (68,013,481 viajes limpios de yellow en los dos casos) y la consulta tarda unos 20 s en vez de fallar. El cambio se aplico en `sql/ej4_analisis.sql`, `sql/ej5_validacion.sql` y `scripts/crear_tabla.py`. `DISTINCT ON` sin `ORDER BY` conserva cualquiera de las filas duplicadas, pero como son el mismo viaje (mismo proveedor, horarios, zonas y total), no cambia los resultados.
2. **Las consultas que no separan por anio mezclan los dos anios.** Por ejemplo, la P6 del Ej. 4 muestra que el 30% de los viajes de yellow paga el cargo de la zona de congestion. Con solo 2026 era el 72%. No es que el cargo haya bajado: en 2024 no existia. Lo mismo pasa con las reglas de calidad del Ej. 3 (por ejemplo, "pasajeros nulo" baja de 26% a 17%). Las consultas que comparan periodos ya agrupan por `anio_archivo` (P1 y P10). Para el tablero (Ej. 7 y 8), los indicadores deben filtrar o agrupar por anio.
3. **Los meses que faltan en 2026 sesgan los totales anuales.** 2024 tiene 12 meses y 2026 solo 8. Las comparaciones entre anios deben usar los mismos meses (enero a agosto) o promedios por dia.
4. **Aparecieron valores extremos nuevos.** En 2024 hay un viaje de yellow de 2 millas y 15 minutos con `total_amount = 335,550.94` USD (`payment_type = 3`, sin cargo). El filtro base no lo quita porque no tiene limite superior para el total. No cambia medianas ni percentiles, pero si suma 335 mil USD a los ingresos de noviembre de 2024. En todo el conjunto hay 94 registros con total mayor a 1,000 USD. Se recomienda agregar `total_amount < 1000` al filtro base en los indicadores de ingresos.

La muestra de registros del Ej. 3 (3.5) tambien cambio: `USING SAMPLE ... REPEATABLE (42)` es reproducible solo mientras los datos sean los mismos. Al agregar archivos, la muestra sale de otros registros.

### Hallazgos con los dos anios

Comparando [resultados/ej4_analisis.md](resultados/ej4_analisis.md) (solo 2026) con [resultados/ej4_analisis_2024_2026.md](resultados/ej4_analisis_2024_2026.md):

- Yellow crecio: mas viajes diarios en cada mes comparable (por ejemplo, enero: 92,588 viajes por dia en 2024 y 113,447 en 2026) y un total promedio mas alto (27.32 USD en enero de 2024, 29.67 en enero de 2026).
- Green se redujo: de unos 1,700 viajes diarios en 2024 a unos 1,300 en 2026.
- El efectivo bajo: con los dos anios es el 11.5% de yellow, contra 9.1% solo en 2026.
- Los patrones por hora y por dia de la semana son practicamente iguales en los dos anios.

## 5.9 Por que el diseno permite agregar anios sin cambiar el flujo

1. **El anio es un parametro, no una constante.** El script de descarga recibe `--anios`, y las rutas se arman con el anio (`data/raw/<tipo>/<anio>/`). Agregar un anio es un cambio de comando, o de una tupla.
2. **Descarga idempotente.** El script omite los archivos validos que ya existen, sin consultar la red, y solo baja lo que falta. Volver a ejecutarlo siempre es seguro.
3. **Consultas sobre patrones, no sobre archivos.** Las vistas leen `data/raw/<tipo>/*/*.parquet`. Un archivo nuevo en esa estructura aparece en la siguiente consulta sin ningun paso de carga ni cambio en el SQL.
4. **El periodo sale del nombre del archivo.** `anio_archivo` y `mes_archivo` se calculan con `filename = true`, asi que cada consulta puede agrupar o filtrar por anio aunque las fechas de pickup tengan errores.
5. **`union_by_name = true`.** Las columnas que existen solo en algunos anios (`cbd_congestion_fee`, `request_source`) no rompen la lectura, solo quedan en NULL donde faltan.
6. **Vistas en un solo bloque.** Todo el analisis se apoya en `viajes` y `viajes_limpios`. Un cambio de esquema o de limpieza se hace en un solo lugar (el bloque `-- 0`).
7. **Los datos crudos no se modifican.** La limpieza vive en una vista, asi que agregar archivos no obliga a reprocesar nada.

Lo que si hubo que ajustar fue la configuracion de memoria, porque el volumen crecio 2.4 veces. Es un recordatorio de que un flujo que funciona con un anio no necesariamente escala sin cambios.
