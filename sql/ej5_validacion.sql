-- 0 Vistas sobre los Parquet y filtro base
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

-- 5.5 Archivos por tipo y anio
SELECT regexp_extract(file, '/(yellow|green)/', 1) AS tipo,
       regexp_extract(file, '/(\d{4})/', 1)::INTEGER AS anio,
       count(*) AS archivos,
       min(regexp_extract(file, '(\d{4}-\d{2})')) AS primer_mes,
       max(regexp_extract(file, '(\d{4}-\d{2})')) AS ultimo_mes
FROM glob('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo DESC, anio;

-- 5.5 Registros por tipo y anio segun metadatos y segun lectura de datos
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

-- 5.6 Consulta conjunta de 2024 y 2026 por mes
SELECT tipo, mes_archivo AS mes,
       count(*) FILTER (anio_archivo = 2024) AS viajes_2024,
       count(*) FILTER (anio_archivo = 2026) AS viajes_2026,
       round(100.0 * (count(*) FILTER (anio_archivo = 2026) - count(*) FILTER (anio_archivo = 2024))
             / nullif(count(*) FILTER (anio_archivo = 2024), 0), 1) AS cambio_pct
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, mes;

-- 5.6 Rango de fechas por anio de archivo
SELECT tipo, anio_archivo AS anio,
       count(DISTINCT mes_archivo) AS meses,
       min(pickup) AS pickup_min,
       max(pickup) AS pickup_max,
       count(*) FILTER (year(pickup) <> anio_archivo OR month(pickup) <> mes_archivo) AS fuera_del_mes
FROM viajes
GROUP BY ALL
ORDER BY tipo DESC, anio;

-- 5.7 Columnas que no estan en todos los archivos
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

-- 5.7 Columnas con tipo de dato distinto entre anios
SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo, name AS columna,
       string_agg(DISTINCT regexp_extract(file_name, '/(\d{4})/', 1) || ': ' || type, ', ') AS tipos
FROM parquet_schema('data/raw/*/*/*.parquet')
WHERE num_children IS NULL
GROUP BY ALL
HAVING count(DISTINCT type) > 1
ORDER BY tipo DESC, columna;

-- 5.7 Tipos de datos resultantes en la vista viajes
SELECT column_name, column_type
FROM (DESCRIBE viajes);

-- 5.7 Cambios en columnas y categorias entre anios
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

-- 5.7 Registros que conserva el filtro base por anio
SELECT b.tipo, b.anio, b.registros AS originales, l.registros AS limpios,
       round(100.0 * l.registros / b.registros, 2) AS pct_conservado
FROM (SELECT tipo, anio_archivo AS anio, count(*) AS registros FROM viajes GROUP BY ALL) b
JOIN (SELECT tipo, anio_archivo AS anio, count(*) AS registros FROM viajes_limpios GROUP BY ALL) l USING (tipo, anio)
ORDER BY b.tipo DESC, b.anio;
