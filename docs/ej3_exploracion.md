# Ejercicio 3 - Consultas directas sobre archivos Parquet

Consultas: [sql/ej3_exploracion.sql](../sql/ej3_exploracion.sql)
SQL y resultados completos: [resultados/ej3_exploracion.md](resultados/ej3_exploracion.md)

Ejecutar:

```bash
docker compose exec lab python scripts/run_sql.py sql/ej3_exploracion.sql --md docs/resultados/ej3_exploracion.md
```

Todas las consultas leen los archivos con `read_parquet()`, `glob()`, `parquet_file_metadata()` o `parquet_schema()`. No se crea ninguna tabla. Las vistas `yellow`, `green` y `viajes` solo guardan la consulta, no los datos.

## 3.8 Documentacion de las consultas

### 0 Vistas sobre los Parquet

- Objetivo: no repetir la ruta de los archivos en cada consulta y unificar yellow y green con los mismos nombres de columna (`pickup`, `dropoff`).
- Fuente: `data/raw/yellow/*/*.parquet` y `data/raw/green/*/*.parquet`.
- Resultado: vistas `yellow`, `green` y `viajes`. Agregan `anio_archivo` y `mes_archivo`, tomados del nombre del archivo.
- Decision: usar `*` en el anio de la ruta para que los anios nuevos (Ej. 5 y 8) se incluyan sin cambiar las consultas. Usar `union_by_name` porque no todos los archivos tienen las mismas columnas.

### 3.1 Cantidad de archivos

- Objetivo: contar los archivos descargados por tipo y anio.
- Fuente: `glob('data/raw/*/*/*.parquet')`.
- Resultado: 8 archivos de yellow y 8 de green, de 2026-01 a 2026-08.
- Decision: coincide con lo publicado por la TLC (ver Ej. 2). Se trabaja con 16 archivos.

### 3.2 Cantidad de registros

- Objetivo: contar los registros sin leer los datos, solo los metadatos de cada Parquet.
- Fuente: `parquet_file_metadata('data/raw/*/*/*.parquet')`.
- Resultado: yellow 29,703,355 y green 337,114, en total 30,040,469 registros. Tarda 0.01 s porque solo lee el pie de cada archivo.
- Decision: yellow tiene 88 veces mas viajes que green. Las comparaciones entre los dos deben usar proporciones o promedios, no totales.

### 3.2 Registros por mes

- Objetivo: confirmar que ningun mes esta vacio o incompleto.
- Fuente: vista `viajes`.
- Resultado: yellow entre 3.3 y 4.1 millones por mes, green entre 37 mil y 45 mil. Coincide con los metadatos.
- Decision: no hay meses faltantes ni anormalmente bajos.

### 3.3 Columnas presentes en cada archivo

- Objetivo: ver que columnas tiene cada archivo y si alguna falta en algunos meses.
- Fuente: `parquet_schema('data/raw/*/*/*.parquet')`.
- Resultado: yellow tiene 21 columnas y green 22. `request_source` solo aparece en los archivos de 2026-06 a 2026-08 de ambos tipos.
- Decision: `request_source` es una columna nueva que no existe en los meses anteriores. Se lee con `union_by_name` y queda en NULL en esos meses. No se usa en el analisis.

### 3.3 Columnas que solo existen en un tipo de taxi

- Objetivo: encontrar las diferencias de esquema entre yellow y green.
- Fuente: `DESCRIBE` sobre los Parquet de cada tipo.
- Resultado: solo yellow tiene `tpep_pickup_datetime`, `tpep_dropoff_datetime` y `Airport_fee`. Solo green tiene `lpep_pickup_datetime`, `lpep_dropoff_datetime`, `ehail_fee` y `trip_type`.
- Decision: la vista `viajes` renombra las fechas a `pickup` y `dropoff` y pone NULL en las columnas que no existen en cada tipo.

### 3.4 Tipos de datos

- Objetivo: conocer el tipo de cada columna segun DuckDB.
- Fuente: `DESCRIBE` sobre los Parquet de cada tipo.
- Resultado: las fechas son TIMESTAMP, los montos y la distancia DOUBLE, los IDs (`VendorID`, `PULocationID`, `DOLocationID`) INTEGER, los codigos (`RatecodeID`, `payment_type`, `passenger_count`, `trip_type`) BIGINT y `store_and_fwd_flag` y `request_source` VARCHAR. Los tipos son iguales en todos los archivos.
- Decision: no hace falta convertir tipos. Los codigos numericos (`payment_type`, `RatecodeID`) son categorias y se analizan con conteos, no con promedios.

### 3.5 Muestra de registros

- Objetivo: ver como se ven los datos reales.
- Fuente: vistas `yellow` y `green`, con `USING SAMPLE reservoir(5 ROWS) REPEATABLE (42)` para que la muestra sea reproducible.
- Resultado: viajes cortos, de 1 a 10 millas, con totales de 8 a 85 USD. En green aparece un viaje de 0.4 millas y 35 segundos con tarifa de 70 USD (`RatecodeID` 5, tarifa negociada).
- Decision: la muestra ya deja ver valores extremos, asi que se revisa la calidad de forma sistematica (3.6).

### 3.6 Perfil de columnas (SUMMARIZE)

- Objetivo: obtener minimo, maximo, promedio, cuartiles y porcentaje de nulos de todas las columnas.
- Fuente: vistas `yellow` y `green`.
- Resultado:
  - yellow: `passenger_count`, `RatecodeID`, `store_and_fwd_flag`, `congestion_surcharge` y `Airport_fee` tienen 25.98% de nulos. `trip_distance` llega a 328,522 millas. `fare_amount` va de -2,555 a 7,045 USD.
  - green: las mismas columnas y `payment_type` tienen 14.47% de nulos. `ehail_fee` es 100% nulo. `trip_distance` llega a 179,830 millas.
  - Las dos: fechas de pickup desde 2001 y 2008.
- Decision: revisar cada problema con reglas especificas (siguiente consulta). Excluir `ehail_fee` del analisis porque no tiene datos.

### 3.6 Problemas de calidad por regla

- Objetivo: contar cuantos registros rompen cada regla de calidad, por tipo.
- Fuente: vista `viajes`.
- Resultado (porcentaje sobre el total del tipo):

| Regla | yellow | green |
|---|---:|---:|
| total distinto a la suma de componentes | 36.68% | 19.87% |
| pasajeros / RatecodeID nulos | 25.98% | 14.47% |
| payment_type = 0 | 25.98% | 0% |
| distancia = 0 | 3.21% | 3.62% |
| RatecodeID = 99 | 2.59% | 0.001% |
| duracion = 0 | 1.25% | 0.07% |
| zona desconocida (264/265) | 0.68% | 1.75% |
| total negativo | 0.54% | 0.30% |
| pasajeros = 0 | 0.31% | 1.34% |
| duracion > 6 horas | 0.025% | 0.33% |
| distancia > 100 millas | 1,223 | 72 |
| pickup fuera del mes del archivo | 146 | 98 |
| dropoff antes del pickup | 10 | 5 |

- Decision: ver la lista de problemas abajo.

### 3.6 Rango de fechas y pickups fuera del mes

- Objetivo: confirmar que cada archivo solo trae viajes de su mes.
- Fuente: vista `viajes`.
- Resultado: el pickup minimo es 2001-01-01 en yellow y 2008-12-31 en green. Hay 146 viajes en yellow y 98 en green con fechas de otro mes. Algunas son de 2001, 2008, 2009 y 2025-12; la mayoria son de meses vecinos de 2026.
- Decision: filtrar por la fecha de pickup dentro del mes del archivo (`year(pickup) = anio_archivo AND month(pickup) = mes_archivo`). Se pierden menos de 0.001% de los registros.

### 3.6 Valores de columnas categoricas

- Objetivo: comparar los codigos con el diccionario de datos de la TLC.
- Fuente: vista `viajes`.
- Resultado:
  - `payment_type = 0` en 7,716,688 viajes de yellow, y son los mismos registros con `passenger_count` y `RatecodeID` nulos. En el diccionario actual de la TLC, 0 es "Flex Fare trip".
  - `RatecodeID = 99` (desconocido) en 769,693 viajes de yellow.
  - `VendorID` 6 y 7 son proveedores recientes. El 6 solo tiene viajes con `payment_type = 0`.
  - `trip_type` (solo green): 1 calle, 2 despacho.
- Decision: `payment_type = 0` no es un error, es una categoria valida (Flex Fare). Esos viajes no traen pasajeros ni tarifa, asi que se excluyen solo de los analisis que usen esas columnas. `RatecodeID = 99` se trata como desconocido.

### 3.6 Viajes duplicados

- Objetivo: buscar viajes repetidos (mismo proveedor, horarios, zonas y total).
- Fuente: vista `viajes`.
- Resultado: 32,794 registros sobrantes en yellow (0.11%) y ninguno en green.
- Decision: quitar los duplicados en el analisis con `DISTINCT` o `QUALIFY row_number() ... = 1`.

### Lista de problemas de calidad encontrados

1. Fechas fuera del rango del archivo: viajes de 2001, 2008, 2009 y de meses vecinos. Hay 244 registros.
2. Viajes Flex Fare (`payment_type = 0`): 26% de yellow sin `passenger_count`, `RatecodeID`, `store_and_fwd_flag`, `congestion_surcharge` ni `Airport_fee`. Los nulos de green (14.5%) siguen el mismo patron.
3. El total no siempre es la suma de los componentes:
   - en los viajes Flex Fare la diferencia mas comun es +2.5 USD, porque el total incluye un recargo cuya columna esta en NULL;
   - en el resto, la diferencia mas comun es -3.25 USD (2.8 millones de viajes), que es igual a `congestion_surcharge` (2.5) + `cbd_congestion_fee` (0.75). Parece que `extra` ya incluye esos recargos en algunos registros.

   Decision: usar `total_amount` tal como viene y no recalcularlo.
4. Montos negativos: tarifa y total negativos en 0.5% de yellow y 0.3% de green. Probablemente son reembolsos o ajustes (`payment_type` 3 o 4, sin cargo o disputa).
5. Distancias imposibles: viajes de hasta 328,522 millas, 1,295 viajes de mas de 100 millas, y 3% con distancia 0.
6. Duraciones invalidas: dropoff antes del pickup (15), duracion 0 (1.25% de yellow) y viajes de mas de 6 horas.
7. Pasajeros 0 o mas de 6.
8. Codigos desconocidos: `RatecodeID = 99`, zonas 264 y 265 ("Unknown" / "Outside of NYC").
9. Columna `ehail_fee` totalmente vacia en green.
10. Esquema que cambia entre meses: `request_source` solo existe desde 2026-06.
11. Duplicados: 32,794 en yellow.

Para el analisis (Ej. 4 en adelante) se propone un filtro base: pickup dentro del mes del archivo, `dropoff > pickup`, duracion menor a 6 horas, `trip_distance` entre 0 y 100, `total_amount >= 0` y sin duplicados. Los datos originales no se modifican; el filtro se aplica en las consultas.

## 3.9 Consultar directamente un archivo Parquet

Consultar directamente un Parquet significa ejecutar SQL sobre el archivo tal como esta en disco, por ejemplo `SELECT ... FROM read_parquet('data/raw/yellow/*/*.parquet')`, sin importarlo antes a una tabla. DuckDB lee el archivo en el momento de la consulta.

Por que es util con mucho volumen:

- Sin paso de carga: no hay que copiar 30 millones de registros a una base antes de empezar. Un archivo nuevo se puede consultar en cuanto se descarga.
- Lee solo lo necesario: Parquet guarda los datos por columnas, asi que DuckDB solo lee las columnas que usa la consulta. Cada grupo de filas guarda el minimo y el maximo de cada columna, y DuckDB salta los grupos que no cumplen el filtro.
- Metadatos sin leer datos: el conteo de 30 millones de registros (3.2) tomo 0.01 s porque se leyo solo el pie de cada archivo, sin escanear ningun dato.
- Compresion: los 30 millones de registros ocupan 496 MB en Parquet. Cargados en pandas ocuparian varias veces eso en memoria.
- Varios archivos como una tabla: con un patron (`*/*.parquet`) DuckDB lee todos los meses y anios juntos, y `union_by_name` resuelve las columnas que cambian entre archivos (como `request_source`).
- No duplica los datos: los Parquet originales son la unica copia. No hay una base que mantener sincronizada.

La limitacion es que cada consulta vuelve a leer y descomprimir los archivos. Por ejemplo, `SUMMARIZE` de yellow tomo unos 18 s porque recorre todas las columnas. Si las mismas consultas se repiten muchas veces, puede convenir materializar una tabla; eso se compara en el Ejercicio 6.
