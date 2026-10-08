# Resultados de ej5_validacion.sql

## 0 Vistas sobre los Parquet y filtro base

```sql
SET memory_limit = '4GB';
SET preserve_insertion_order = false;

CREATE OR REPLACE VIEW yellow AS
SELECT *,
       regexp_extract(filename, '_(\d{4})-\d{2}\.parquet$', 1)::INTEGER AS anio_archivo,
       regexp_extract(filename, '_\d{4}-(\d{2})\.parquet$', 1)::INTEGER AS mes_archivo
FROM read_parquet('data/raw/yellow/*/*.parquet', filename = true, union_by_name = true);

CREATE OR REPLACE VIEW green AS
SELECT *,
       regexp_extract(filename, '_(\d{4})-\d{2}\.parquet$', 1)::INTEGER AS anio_archivo,
       regexp_extract(filename, '_\d{4}-(\d{2})\.parquet$', 1)::INTEGER AS mes_archivo
FROM read_parquet('data/raw/green/*/*.parquet', filename = true, union_by_name = true);

CREATE OR REPLACE VIEW viajes AS
SELECT 'yellow' AS tipo, anio_archivo, mes_archivo, VendorID,
       tpep_pickup_datetime AS pickup, tpep_dropoff_datetime AS dropoff,
       passenger_count, trip_distance, RatecodeID, store_and_fwd_flag,
       PULocationID, DOLocationID, payment_type,
       fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
       congestion_surcharge, Airport_fee AS airport_fee, NULL::DOUBLE AS ehail_fee,
       cbd_congestion_fee, total_amount, NULL::BIGINT AS trip_type
FROM yellow
UNION ALL BY NAME
SELECT 'green' AS tipo, anio_archivo, mes_archivo, VendorID,
       lpep_pickup_datetime AS pickup, lpep_dropoff_datetime AS dropoff,
       passenger_count, trip_distance, RatecodeID, store_and_fwd_flag,
       PULocationID, DOLocationID, payment_type,
       fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
       congestion_surcharge, NULL::DOUBLE AS airport_fee, ehail_fee,
       cbd_congestion_fee, total_amount, trip_type
FROM green;

CREATE OR REPLACE VIEW viajes_limpios AS
SELECT *,
       date_diff('second', pickup, dropoff) / 60.0 AS duracion_min,
       trip_distance / (date_diff('second', pickup, dropoff) / 3600.0) AS velocidad_mph,
       CASE payment_type
           WHEN 0 THEN 'Flex Fare' WHEN 1 THEN 'Tarjeta' WHEN 2 THEN 'Efectivo'
           WHEN 3 THEN 'Sin cargo' WHEN 4 THEN 'Disputa' WHEN 5 THEN 'Desconocido'
           WHEN 6 THEN 'Anulado' ELSE 'Nulo' END AS forma_pago
FROM viajes
WHERE year(pickup) = anio_archivo AND month(pickup) = mes_archivo
  AND dropoff > pickup
  AND dropoff - pickup < INTERVAL 6 HOUR
  AND trip_distance > 0 AND trip_distance <= 100
  AND total_amount >= 0
QUALIFY row_number() OVER (
    PARTITION BY tipo, VendorID, pickup, dropoff, PULocationID, DOLocationID, total_amount
    ORDER BY fare_amount) = 1;
```

0 filas, 0.02 s

## 5.5 Archivos por tipo y anio

```sql
SELECT regexp_extract(file, '/(yellow|green)/', 1) AS tipo,
       regexp_extract(file, '/(\d{4})/', 1)::INTEGER AS anio,
       count(*) AS archivos,
       min(regexp_extract(file, '(\d{4}-\d{2})')) AS primer_mes,
       max(regexp_extract(file, '(\d{4}-\d{2})')) AS ultimo_mes
FROM glob('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo DESC, anio;
```

| tipo | anio | archivos | primer_mes | ultimo_mes |
|---|---|---|---|---|
| yellow | 2024 | 12 | 2024-01 | 2024-12 |
| yellow | 2026 | 8 | 2026-01 | 2026-08 |
| green | 2024 | 12 | 2024-01 | 2024-12 |
| green | 2026 | 8 | 2026-01 | 2026-08 |

4 filas, 0.00 s

## 5.5 Registros por tipo y anio segun metadatos y segun lectura de datos

```sql
SELECT m.tipo, m.anio, m.archivos, m.registros_metadatos, d.registros_leidos,
       m.registros_metadatos = d.registros_leidos AS coinciden
FROM (
    SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo,
           regexp_extract(file_name, '/(\d{4})/', 1)::INTEGER AS anio,
           count(*) AS archivos, sum(num_rows) AS registros_metadatos
    FROM parquet_file_metadata('data/raw/*/*/*.parquet')
    GROUP BY ALL
) m
JOIN (
    SELECT tipo, anio_archivo AS anio, count(*) AS registros_leidos
    FROM viajes
    GROUP BY ALL
) d USING (tipo, anio)
ORDER BY m.tipo DESC, m.anio;
```

| tipo | anio | archivos | registros_metadatos | registros_leidos | coinciden |
|---|---|---|---|---|---|
| yellow | 2024 | 12 | 41169720 | 41169720 | True |
| yellow | 2026 | 8 | 29703355 | 29703355 | True |
| green | 2024 | 12 | 660218 | 660218 | True |
| green | 2026 | 8 | 337114 | 337114 | True |

4 filas, 0.04 s

## 5.6 Consulta conjunta de 2024 y 2026 por mes

```sql
SELECT tipo, mes_archivo AS mes,
       count(*) FILTER (anio_archivo = 2024) AS viajes_2024,
       count(*) FILTER (anio_archivo = 2026) AS viajes_2026,
       round(100.0 * (count(*) FILTER (anio_archivo = 2026) - count(*) FILTER (anio_archivo = 2024))
             / nullif(count(*) FILTER (anio_archivo = 2024), 0), 1) AS cambio_pct
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, mes;
```

| tipo | mes | viajes_2024 | viajes_2026 | cambio_pct |
|---|---|---|---|---|
| yellow | 1 | 2964624 | 3724889 | 25.6 |
| yellow | 2 | 3007526 | 3399866 | 13 |
| yellow | 3 | 3582628 | 3952451 | 10.3 |
| yellow | 4 | 3514289 | 3831240 | 9 |
| yellow | 5 | 3723833 | 4090836 | 9.9 |
| yellow | 6 | 3539193 | 3837248 | 8.4 |
| yellow | 7 | 3076903 | 3530109 | 14.7 |
| yellow | 8 | 2979183 | 3336716 | 12 |
| yellow | 9 | 3633030 | 0 | -100 |
| yellow | 10 | 3833771 | 0 | -100 |
| yellow | 11 | 3646369 | 0 | -100 |
| yellow | 12 | 3668371 | 0 | -100 |
| green | 1 | 56551 | 40272 | -28.8 |
| green | 2 | 53577 | 37373 | -30.2 |
| green | 3 | 57457 | 44208 | -23.1 |
| green | 4 | 56471 | 44238 | -21.7 |
| green | 5 | 61003 | 44921 | -26.4 |
| green | 6 | 54748 | 44163 | -19.3 |
| green | 7 | 51837 | 41252 | -20.4 |
| green | 8 | 51771 | 40687 | -21.4 |
| green | 9 | 54440 | 0 | -100 |
| green | 10 | 56147 | 0 | -100 |
| green | 11 | 52222 | 0 | -100 |
| green | 12 | 53994 | 0 | -100 |

24 filas, 0.05 s

## 5.6 Rango de fechas por anio de archivo

```sql
SELECT tipo, anio_archivo AS anio,
       count(DISTINCT mes_archivo) AS meses,
       min(pickup) AS pickup_min,
       max(pickup) AS pickup_max,
       count(*) FILTER (year(pickup) <> anio_archivo OR month(pickup) <> mes_archivo) AS fuera_del_mes
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, anio;
```

| tipo | anio | meses | pickup_min | pickup_max | fuera_del_mes |
|---|---|---|---|---|---|
| yellow | 2024 | 12 | 2002-12-31 16:46:07 | 2026-06-26 23:53:12 | 420 |
| yellow | 2026 | 8 | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 146 |
| green | 2024 | 12 | 2008-12-31 00:00:00 | 2025-01-01 22:21:15 | 164 |
| green | 2026 | 8 | 2008-12-31 17:35:31 | 2026-08-31 23:58:28 | 98 |

4 filas, 0.31 s

## 5.7 Columnas que no estan en todos los archivos

```sql
WITH esquema AS (
    SELECT DISTINCT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo,
           regexp_extract(file_name, '_(\d{4}-\d{2})\.parquet$', 1) AS mes,
           name AS columna
    FROM parquet_schema('data/raw/*/*/*.parquet')
    WHERE num_children IS NULL
),
archivos AS (SELECT tipo, count(DISTINCT mes) AS total FROM esquema GROUP BY tipo)
SELECT e.tipo, e.columna, count(*) AS archivos_con_columna, a.total AS archivos_total,
       min(e.mes) AS desde, max(e.mes) AS hasta
FROM esquema e JOIN archivos a USING (tipo)
GROUP BY e.tipo, e.columna, a.total
HAVING count(*) < a.total
ORDER BY e.tipo DESC, e.columna;
```

| tipo | columna | archivos_con_columna | archivos_total | desde | hasta |
|---|---|---|---|---|---|
| yellow | cbd_congestion_fee | 8 | 20 | 2026-01 | 2026-08 |
| yellow | request_source | 3 | 20 | 2026-06 | 2026-08 |
| green | cbd_congestion_fee | 8 | 20 | 2026-01 | 2026-08 |
| green | request_source | 3 | 20 | 2026-06 | 2026-08 |

4 filas, 0.01 s

## 5.7 Columnas con tipo de dato distinto entre anios

```sql
SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo, name AS columna,
       string_agg(DISTINCT regexp_extract(file_name, '/(\d{4})/', 1) || ': ' || type, ', ') AS tipos
FROM parquet_schema('data/raw/*/*/*.parquet')
WHERE num_children IS NULL
GROUP BY ALL
HAVING count(DISTINCT type) > 1
ORDER BY tipo DESC, columna;
```

0 filas, 0.01 s

## 5.7 Tipos de datos resultantes en la vista viajes

```sql
SELECT column_name, column_type
FROM (DESCRIBE viajes);
```

| column_name | column_type |
|---|---|
| tipo | VARCHAR |
| anio_archivo | INTEGER |
| mes_archivo | INTEGER |
| VendorID | INTEGER |
| pickup | TIMESTAMP |
| dropoff | TIMESTAMP |
| passenger_count | BIGINT |
| trip_distance | DOUBLE |
| RatecodeID | BIGINT |
| store_and_fwd_flag | VARCHAR |
| PULocationID | INTEGER |
| DOLocationID | INTEGER |
| payment_type | BIGINT |
| fare_amount | DOUBLE |
| extra | DOUBLE |
| mta_tax | DOUBLE |
| tip_amount | DOUBLE |
| tolls_amount | DOUBLE |
| improvement_surcharge | DOUBLE |
| congestion_surcharge | DOUBLE |
| airport_fee | DOUBLE |
| ehail_fee | DOUBLE |
| cbd_congestion_fee | DOUBLE |
| total_amount | DOUBLE |
| trip_type | BIGINT |

25 filas, 0.00 s

## 5.7 Cambios en columnas y categorias entre anios

```sql
SELECT tipo, anio_archivo AS anio,
       count(*) AS viajes,
       round(100.0 * count(*) FILTER (cbd_congestion_fee IS NULL) / count(*), 2) AS pct_cbd_nulo,
       round(100.0 * count(*) FILTER (payment_type = 0) / count(*), 2) AS pct_payment_0,
       round(100.0 * count(*) FILTER (payment_type IS NULL) / count(*), 2) AS pct_payment_nulo,
       round(100.0 * count(*) FILTER (passenger_count IS NULL) / count(*), 2) AS pct_pasajeros_nulo,
       string_agg(DISTINCT VendorID::VARCHAR, ',' ORDER BY VendorID::VARCHAR) AS vendors
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, anio;
```

| tipo | anio | viajes | pct_cbd_nulo | pct_payment_0 | pct_payment_nulo | pct_pasajeros_nulo | vendors |
|---|---|---|---|---|---|---|---|
| yellow | 2024 | 41169720 | 100 | 9.94 | 0 | 9.94 | 1,2,6,7 |
| yellow | 2026 | 29703355 | 0 | 25.98 | 0 | 25.98 | 1,2,6,7 |
| green | 2024 | 660218 | 100 | 0 | 3.68 | 3.68 | 1,2 |
| green | 2026 | 337114 | 0 | 0 | 14.47 | 14.47 | 1,2,6 |

4 filas, 0.42 s

## 5.7 Registros que conserva el filtro base por anio

```sql
SELECT b.tipo, b.anio, b.registros AS originales, l.registros AS limpios,
       round(100.0 * l.registros / b.registros, 2) AS pct_conservado
FROM (SELECT tipo, anio_archivo AS anio, count(*) AS registros FROM viajes GROUP BY ALL) b
JOIN (SELECT tipo, anio_archivo AS anio, count(*) AS registros FROM viajes_limpios GROUP BY ALL) l USING (tipo, anio)
ORDER BY b.tipo DESC, b.anio;
```

| tipo | anio | originales | limpios | pct_conservado |
|---|---|---|---|---|
| yellow | 2024 | 41169720 | 39808793 | 96.69 |
| yellow | 2026 | 29703355 | 28204688 | 94.95 |
| green | 2024 | 660218 | 621284 | 94.1 |
| green | 2026 | 337114 | 323098 | 95.84 |

4 filas, 6.27 s
