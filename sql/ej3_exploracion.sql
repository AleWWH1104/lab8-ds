-- 0 Vistas sobre los Parquet
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

-- 3.1 Cantidad de archivos
SELECT regexp_extract(file, '/(yellow|green)/', 1) AS tipo,
       regexp_extract(file, '/(\d{4})/', 1) AS anio,
       count(*) AS archivos,
       min(regexp_extract(file, '(\d{4}-\d{2})')) AS primer_mes,
       max(regexp_extract(file, '(\d{4}-\d{2})')) AS ultimo_mes
FROM glob('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo, anio;

-- 3.2 Cantidad de registros
SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo,
       count(*) AS archivos,
       sum(num_rows) AS registros
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo;

-- 3.2 Registros por mes
SELECT tipo, anio_archivo AS anio, mes_archivo AS mes, count(*) AS registros
FROM viajes
GROUP BY ALL
ORDER BY tipo, anio, mes;

-- 3.3 Columnas presentes en cada archivo
WITH esquema AS (
    SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo, file_name, name AS columna
    FROM parquet_schema('data/raw/*/*/*.parquet')
    WHERE num_children IS NULL
)
SELECT tipo, columna,
       count(DISTINCT file_name) AS archivos_con_columna,
       (SELECT count(DISTINCT file_name) FROM esquema e2 WHERE e2.tipo = esquema.tipo) AS archivos_total
FROM esquema
GROUP BY tipo, columna
ORDER BY tipo, columna;

-- 3.3 Columnas que solo existen en un tipo de taxi
WITH y AS (SELECT column_name FROM (DESCRIBE SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true))),
     g AS (SELECT column_name FROM (DESCRIBE SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true)))
SELECT coalesce(y.column_name, g.column_name) AS columna,
       y.column_name IS NOT NULL AS en_yellow,
       g.column_name IS NOT NULL AS en_green
FROM y FULL OUTER JOIN g ON y.column_name = g.column_name
WHERE y.column_name IS NULL OR g.column_name IS NULL
ORDER BY columna;

-- 3.4 Tipos de datos yellow
DESCRIBE SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true);

-- 3.4 Tipos de datos green
DESCRIBE SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true);

-- 3.5 Muestra de registros yellow
SELECT * EXCLUDE (filename)
FROM yellow
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);

-- 3.5 Muestra de registros green
SELECT * EXCLUDE (filename)
FROM green
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);

-- 3.6 Perfil de columnas yellow
SUMMARIZE SELECT * EXCLUDE (filename) FROM yellow;

-- 3.6 Perfil de columnas green
SUMMARIZE SELECT * EXCLUDE (filename) FROM green;

-- 3.6 Problemas de calidad por regla
WITH reglas AS (
    SELECT tipo,
           count(*) AS total,
           count(*) FILTER (year(pickup) <> anio_archivo OR month(pickup) <> mes_archivo) AS "pickup fuera del mes del archivo",
           count(*) FILTER (dropoff < pickup) AS "dropoff antes del pickup",
           count(*) FILTER (dropoff = pickup) AS "duracion = 0",
           count(*) FILTER (dropoff - pickup > INTERVAL 6 HOUR) AS "duracion > 6 horas",
           count(*) FILTER (trip_distance = 0) AS "distancia = 0",
           count(*) FILTER (trip_distance > 100) AS "distancia > 100 millas",
           count(*) FILTER (passenger_count IS NULL) AS "pasajeros nulo",
           count(*) FILTER (passenger_count = 0) AS "pasajeros = 0",
           count(*) FILTER (passenger_count > 6) AS "pasajeros > 6",
           count(*) FILTER (fare_amount < 0) AS "tarifa negativa",
           count(*) FILTER (total_amount < 0) AS "total negativo",
           count(*) FILTER (total_amount = 0) AS "total = 0",
           count(*) FILTER (fare_amount > 500) AS "tarifa > 500 USD",
           count(*) FILTER (RatecodeID IS NULL) AS "RatecodeID nulo",
           count(*) FILTER (RatecodeID NOT IN (1, 2, 3, 4, 5, 6)) AS "RatecodeID fuera del diccionario",
           count(*) FILTER (payment_type NOT IN (1, 2, 3, 4, 5, 6)) AS "payment_type fuera del diccionario",
           count(*) FILTER (PULocationID NOT BETWEEN 1 AND 263 OR DOLocationID NOT BETWEEN 1 AND 263) AS "zona desconocida",
           count(*) FILTER (abs(total_amount - (
                   coalesce(fare_amount, 0) + coalesce(extra, 0) + coalesce(mta_tax, 0)
                 + coalesce(tip_amount, 0) + coalesce(tolls_amount, 0)
                 + coalesce(improvement_surcharge, 0) + coalesce(congestion_surcharge, 0)
                 + coalesce(airport_fee, 0) + coalesce(ehail_fee, 0)
                 + coalesce(cbd_congestion_fee, 0))) > 0.01) AS "total distinto a la suma"
    FROM viajes
    GROUP BY tipo
)
SELECT tipo, regla, registros, round(100.0 * registros / total, 3) AS pct
FROM (UNPIVOT reglas ON COLUMNS(* EXCLUDE (tipo, total)) INTO NAME regla VALUE registros)
ORDER BY tipo DESC, pct DESC;

-- 3.6 Rango de fechas de pickup
SELECT tipo,
       min(pickup) AS pickup_min,
       max(pickup) AS pickup_max,
       min(make_date(anio_archivo, mes_archivo, 1)) AS esperado_desde,
       max(make_date(anio_archivo, mes_archivo, 1) + INTERVAL 1 MONTH) AS esperado_hasta
FROM viajes
GROUP BY tipo
ORDER BY tipo DESC;

-- 3.6 Pickups fuera del mes de su archivo
SELECT tipo, strftime(pickup, '%Y-%m') AS mes_pickup, count(*) AS registros
FROM viajes
WHERE year(pickup) <> anio_archivo OR month(pickup) <> mes_archivo
GROUP BY ALL
ORDER BY tipo DESC, mes_pickup;

-- 3.6 Valores de columnas categoricas
SELECT tipo, columna, valor, count(*) AS registros
FROM (
    UNPIVOT (
        SELECT tipo,
               VendorID::VARCHAR AS VendorID,
               RatecodeID::VARCHAR AS RatecodeID,
               payment_type::VARCHAR AS payment_type,
               store_and_fwd_flag::VARCHAR AS store_and_fwd_flag,
               trip_type::VARCHAR AS trip_type
        FROM viajes
    ) ON COLUMNS(* EXCLUDE (tipo)) INTO NAME columna VALUE valor
)
GROUP BY ALL
ORDER BY tipo DESC, columna, valor;

-- 3.6 Viajes duplicados
SELECT tipo,
       count(*) AS grupos_duplicados,
       sum(n) - count(*) AS registros_sobrantes
FROM (
    SELECT tipo, count(*) AS n
    FROM viajes
    GROUP BY tipo, VendorID, pickup, dropoff, PULocationID, DOLocationID, total_amount
    HAVING count(*) > 1
)
GROUP BY tipo
ORDER BY tipo DESC;
