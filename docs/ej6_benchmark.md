# Ejercicio 6 - Parquet versus tablas DuckDB

- Tabla materializada: [`scripts/crear_tabla.py`](../scripts/crear_tabla.py) -> `data/processed/taxis.duckdb`
- Script del benchmark: [`scripts/benchmark.py`](../scripts/benchmark.py)
- Consultas del benchmark: [sql/ej6_benchmark.sql](../sql/ej6_benchmark.sql)
- Resultados crudos: [resultados/ej6_benchmark.csv](resultados/ej6_benchmark.csv)

Ejecutar:

```bash
docker compose exec lab python scripts/crear_tabla.py
docker compose exec lab python scripts/benchmark.py
```

`benchmark.py` acepta `--volumenes` y `--repeticiones`. Con los valores por defecto (3 volumenes, 5 repeticiones) tarda unos minutos.

## 6.1 - 6.2 Las dos estrategias

**Parquet directo.** Una vista `viajes` que lee los archivos con `read_parquet(..., filename = true, union_by_name = true)`, igual que en los Ej. 3 a 5. No guarda datos: cada consulta vuelve a leer los archivos.

**Tabla materializada.** `scripts/crear_tabla.py` ejecuta `CREATE TABLE viajes AS SELECT ...` con el mismo `SELECT` que la vista, de modo que la tabla tiene exactamente las mismas columnas y registros (incluidos `anio_archivo` y `mes_archivo`). Tambien crea la vista `viajes_limpios` con el filtro base. El archivo se borra y se vuelve a crear en cada ejecucion, asi que al agregar un anio (Ej. 8) basta con volver a correrlo.

| | Parquet (2024 + 2026) | Tabla DuckDB (2024 + 2026) |
|---|---:|---:|
| registros | 71,870,407 | 71,870,407 |
| tamanio en disco | 1,172 MiB (40 archivos) | 1,979 MiB (un archivo) |
| tiempo de preparacion | 0 s (se consulta al descargar) | 9.2 s (`CREATE TABLE`) |

La tabla ocupa 1.7 veces mas que los Parquet porque DuckDB usa una compresion mas ligera que la de los archivos de la TLC. Ademas, los datos quedan duplicados: los Parquet siguen siendo la fuente y la tabla es una copia.

## 6.3 Consultas seleccionadas (6.8 documentacion)

Se eligieron 6 consultas del Ej. 4 que representan distintos tipos de trabajo. Todas usan la relacion `viajes`. El script cambia el `search_path` para que `viajes` sea la vista sobre Parquet o la tabla, sin cambiar el SQL.

| # | Consulta | Origen | Que mide |
|---|---|---|---|
| Q1 | Conteo de viajes por tipo y anio | 3.2 | Agregacion trivial. No lee ninguna columna de datos. |
| Q2 | Viajes e ingresos por mes | P1 | Filtro de calidad sobre 6 columnas, agrupacion y suma. |
| Q3 | Viajes y velocidad mediana por hora | P2 | Funcion de fecha, calculo por fila y mediana (requiere ordenar). |
| Q4 | Formas de pago por tipo | P7 | Agrupacion sobre una columna de baja cardinalidad y funcion de ventana. |
| Q5 | Propinas con tarjeta | P8 | Filtro por `payment_type` (65% de las filas) y mediana de un calculo. |
| Q6 | Zonas mas frecuentes en una semana | P5 | Filtro muy selectivo por fecha (1 semana de enero de 2026). |

## 6.4 - 6.6 Metodologia

- Volumenes (6.6): **1 mes** (enero de 2026, 3.8 M registros), **2026** (enero a agosto, 30.0 M) y **2024 + 2026** (71.9 M).
- Para cada volumen se crea la tabla y la vista en una base temporal (`data/processed/benchmark.duckdb`, que se borra al terminar).
- Cada consulta se ejecuta una vez "en frio" (la primera vez en esa conexion) y luego 5 veces mas. Se reporta la **mediana** de las 5 repeticiones, ademas del minimo y el maximo. La mediana no se ve afectada por una ejecucion lenta aislada.
- Se mide el tiempo hasta traer todas las filas a Python (`fetchall()`).
- Ambiente: contenedor Docker con 10 CPU y 7.6 GB de RAM, DuckDB 1.5.5, `memory_limit = 4GB`. Datos en un volumen montado desde macOS.
- Limitacion: "frio" no es un arranque en frio real, porque el sistema operativo ya tiene los archivos en cache despues de las corridas anteriores. Por eso la diferencia entre la primera ejecucion y las repeticiones es pequena.

## 6.7 Resultados

Mediana de 5 ejecuciones, en segundos. "Parquet / tabla" mayor a 1 significa que la tabla es mas rapida.

### 1 mes (3.8 M registros, 62 MiB de Parquet, tabla creada en 1.05 s)

| Consulta | Parquet | Tabla | Parquet / tabla |
|---|---:|---:|---:|
| Q1 Conteo | 0.005 | 0.009 | 0.6 |
| Q2 Viajes e ingresos por mes | 0.070 | 0.021 | 3.3 |
| Q3 Velocidad mediana por hora | 0.094 | 0.037 | 2.5 |
| Q4 Formas de pago | 0.033 | 0.021 | 1.5 |
| Q5 Propinas con tarjeta | 0.057 | 0.034 | 1.7 |
| Q6 Zonas en una semana | 0.033 | 0.003 | 9.6 |

### 2026 (30.0 M registros, 496 MiB de Parquet, tabla creada en 4.05 s)

| Consulta | Parquet | Tabla | Parquet / tabla |
|---|---:|---:|---:|
| Q1 Conteo | 0.015 | 0.037 | 0.4 |
| Q2 Viajes e ingresos por mes | 0.248 | 0.127 | 2.0 |
| Q3 Velocidad mediana por hora | 0.385 | 0.250 | 1.5 |
| Q4 Formas de pago | 0.081 | 0.099 | 0.8 |
| Q5 Propinas con tarjeta | 0.478 | 0.403 | 1.2 |
| Q6 Zonas en una semana | 0.031 | 0.004 | 8.3 |

### 2024 + 2026 (71.9 M registros, 1,172 MiB de Parquet, tabla creada en 9.20 s)

| Consulta | Parquet | Tabla | Parquet / tabla |
|---|---:|---:|---:|
| Q1 Conteo | 0.033 | 0.076 | 0.4 |
| Q2 Viajes e ingresos por mes | 0.576 | 0.311 | 1.9 |
| Q3 Velocidad mediana por hora | 0.889 | 0.646 | 1.4 |
| Q4 Formas de pago | 0.182 | 0.208 | 0.9 |
| Q5 Propinas con tarjeta | 1.093 | 1.119 | 1.0 |
| Q6 Zonas en una semana | 0.074 | 0.004 | 18.4 |
| **Suma de las 6** | **2.847** | **2.364** | **1.2** |

### Como crece el tiempo con el volumen

| Consulta | Parquet 1 mes -> 2024+2026 | Tabla 1 mes -> 2024+2026 |
|---|---:|---:|
| Q2 | 0.070 -> 0.576 (x8) | 0.021 -> 0.311 (x15) |
| Q3 | 0.094 -> 0.889 (x9) | 0.037 -> 0.646 (x17) |
| Q5 | 0.057 -> 1.093 (x19) | 0.034 -> 1.119 (x33) |
| Q6 | 0.033 -> 0.074 (x2) | 0.003 -> 0.004 (x1.3) |

El volumen crece 19 veces (de 3.8 M a 71.9 M registros).

## 6.9 Analisis

1. **La tabla gana en las consultas que leen varias columnas y filtran (Q2, Q3), pero la ventaja se reduce con el volumen.** Con 1 mes, la tabla es 2.5 a 3.3 veces mas rapida. Con 72 M registros, solo 1.4 a 1.9 veces. Con pocos datos, el costo fijo de Parquet pesa mucho: abrir los archivos, leer los pies, descomprimir y extraer el anio y el mes del nombre del archivo. Con muchos datos domina el trabajo de calcular (agrupar, ordenar para la mediana), que es igual en las dos estrategias. Por eso el tiempo con Parquet crece menos que el volumen (x8 a x9 para Q2 y Q3, con 19 veces mas datos), mientras que el de la tabla crece mas proporcionalmente.

2. **El filtro selectivo es donde la tabla gana por mas (Q6, hasta 18 veces).** DuckDB guarda para cada bloque de filas el minimo y el maximo de cada columna (zonemaps). Como la tabla se cargo en orden de archivo, cada bloque cubre un rango corto de fechas y DuckDB salta casi todos los bloques: 4 ms aunque crezca el volumen. Los Parquet tambien tienen minimo y maximo por grupo de filas, pero DuckDB tiene que abrir y leer los metadatos de los 40 archivos antes de decidir que saltar, y ese costo crece con el numero de archivos (de 33 a 74 ms).

3. **El conteo (Q1) es mas rapido sobre Parquet.** El conteo por tipo y anio no necesita leer datos: el anio sale del nombre del archivo y la cantidad de filas esta en los metadatos de cada Parquet. En la tabla, DuckDB tiene que recorrer la columna `anio_archivo`. Es el caso en que el formato de archivo trae la respuesta casi lista.

4. **En agrupaciones simples sobre pocas columnas (Q4, Q5) no hay diferencia real.** Con 30 M y 72 M registros, las dos estrategias quedan dentro de 10-20% una de la otra, y en Q4 Parquet es un poco mas rapido. Los Parquet de la TLC estan muy comprimidos: leer 2 o 3 columnas de enteros es barato, y el tiempo se va en agregar y en calcular medianas, que cuesta igual en las dos estrategias.

5. **El costo de materializar se recupera con pocas consultas, pero no es gratis.** Crear la tabla de 72 M registros tomo 9.2 s. En la suma de las 6 consultas, la tabla ahorra 0.48 s por ronda. Hacen falta unas 19 rondas (unas 115 consultas de este tipo) para recuperar la carga, menos si las consultas son selectivas como Q6. A cambio, la tabla ocupa 1.98 GB extra y hay que regenerarla cada vez que llegan archivos nuevos. Si no, queda desactualizada respecto a los Parquet.

6. **Todas las consultas, con cualquier estrategia, tardan alrededor de 1 segundo o menos sobre 72 M registros.** La diferencia entre estrategias es de fracciones de segundo. En este volumen, la eleccion depende mas de la operacion (frecuencia de las consultas, actualizacion de los datos, herramientas que se conectan) que de la velocidad.

## 6.10 Cuando conviene cada estrategia

**Consultar directamente los Parquet** conviene cuando:

- los datos llegan como archivos nuevos con frecuencia (como aqui, un archivo por mes) y se quiere consultarlos en cuanto se descargan, sin un paso de carga;
- el analisis es exploratorio o se ejecuta pocas veces;
- importa el espacio en disco o no se quiere tener dos copias de los datos que mantener sincronizadas;
- las consultas usan metadatos (conteos, rangos, esquema) o pocas columnas;
- otros procesos o herramientas (Spark, pandas, pyarrow) leen los mismos archivos.

**Materializar una tabla DuckDB** conviene cuando:

- las mismas consultas se repiten muchas veces, por ejemplo en un tablero que se refresca o en una API;
- hay filtros selectivos frecuentes (por fecha, por zona), donde las zonemaps de la tabla dan mejoras de un orden de magnitud;
- se quiere guardar en un solo archivo los datos ya limpios o enriquecidos (filtro base, columnas calculadas, uniones con la tabla de zonas), para no repetir esas transformaciones en cada consulta;
- una herramienta externa necesita una base de datos a la cual conectarse. Es el caso de Metabase en el Ej. 7, que se conecta a `taxis.duckdb` en modo solo lectura.

En este proyecto se usan las dos: Parquet como fuente unica y reproducible, que crece con cada descarga, y una tabla DuckDB regenerada con `crear_tabla.py` para el tablero, donde las consultas se repiten.
