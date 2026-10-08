# Resultados de ej3_exploracion.sql

## 0 Vistas sobre los Parquet

```sql
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
```

0 filas, 0.01 s

## 3.1 Cantidad de archivos

```sql
SELECT regexp_extract(file, '/(yellow|green)/', 1) AS tipo,
       regexp_extract(file, '/(\d{4})/', 1) AS anio,
       count(*) AS archivos,
       min(regexp_extract(file, '(\d{4}-\d{2})')) AS primer_mes,
       max(regexp_extract(file, '(\d{4}-\d{2})')) AS ultimo_mes
FROM glob('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo, anio;
```

| tipo | anio | archivos | primer_mes | ultimo_mes |
|---|---|---|---|---|
| green | 2024 | 12 | 2024-01 | 2024-12 |
| green | 2026 | 8 | 2026-01 | 2026-08 |
| yellow | 2024 | 12 | 2024-01 | 2024-12 |
| yellow | 2026 | 8 | 2026-01 | 2026-08 |

4 filas, 0.00 s

## 3.2 Cantidad de registros

```sql
SELECT regexp_extract(file_name, '/(yellow|green)/', 1) AS tipo,
       count(*) AS archivos,
       sum(num_rows) AS registros
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo;
```

| tipo | archivos | registros |
|---|---|---|
| green | 20 | 997332 |
| yellow | 20 | 70873075 |

2 filas, 0.00 s

## 3.2 Registros por mes

```sql
SELECT tipo, anio_archivo AS anio, mes_archivo AS mes, count(*) AS registros
FROM viajes
GROUP BY ALL
ORDER BY tipo, anio, mes;
```

| tipo | anio | mes | registros |
|---|---|---|---|
| green | 2024 | 1 | 56551 |
| green | 2024 | 2 | 53577 |
| green | 2024 | 3 | 57457 |
| green | 2024 | 4 | 56471 |
| green | 2024 | 5 | 61003 |
| green | 2024 | 6 | 54748 |
| green | 2024 | 7 | 51837 |
| green | 2024 | 8 | 51771 |
| green | 2024 | 9 | 54440 |
| green | 2024 | 10 | 56147 |
| green | 2024 | 11 | 52222 |
| green | 2024 | 12 | 53994 |
| green | 2026 | 1 | 40272 |
| green | 2026 | 2 | 37373 |
| green | 2026 | 3 | 44208 |
| green | 2026 | 4 | 44238 |
| green | 2026 | 5 | 44921 |
| green | 2026 | 6 | 44163 |
| green | 2026 | 7 | 41252 |
| green | 2026 | 8 | 40687 |
| yellow | 2024 | 1 | 2964624 |
| yellow | 2024 | 2 | 3007526 |
| yellow | 2024 | 3 | 3582628 |
| yellow | 2024 | 4 | 3514289 |
| yellow | 2024 | 5 | 3723833 |
| yellow | 2024 | 6 | 3539193 |
| yellow | 2024 | 7 | 3076903 |
| yellow | 2024 | 8 | 2979183 |
| yellow | 2024 | 9 | 3633030 |
| yellow | 2024 | 10 | 3833771 |
| yellow | 2024 | 11 | 3646369 |
| yellow | 2024 | 12 | 3668371 |
| yellow | 2026 | 1 | 3724889 |
| yellow | 2026 | 2 | 3399866 |
| yellow | 2026 | 3 | 3952451 |
| yellow | 2026 | 4 | 3831240 |
| yellow | 2026 | 5 | 4090836 |
| yellow | 2026 | 6 | 3837248 |
| yellow | 2026 | 7 | 3530109 |
| yellow | 2026 | 8 | 3336716 |

40 filas, 0.03 s

## 3.3 Columnas presentes en cada archivo

```sql
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
```

| tipo | columna | archivos_con_columna | archivos_total |
|---|---|---|---|
| green | DOLocationID | 20 | 20 |
| green | PULocationID | 20 | 20 |
| green | RatecodeID | 20 | 20 |
| green | VendorID | 20 | 20 |
| green | cbd_congestion_fee | 8 | 20 |
| green | congestion_surcharge | 20 | 20 |
| green | ehail_fee | 20 | 20 |
| green | extra | 20 | 20 |
| green | fare_amount | 20 | 20 |
| green | improvement_surcharge | 20 | 20 |
| green | lpep_dropoff_datetime | 20 | 20 |
| green | lpep_pickup_datetime | 20 | 20 |
| green | mta_tax | 20 | 20 |
| green | passenger_count | 20 | 20 |
| green | payment_type | 20 | 20 |
| green | request_source | 3 | 20 |
| green | store_and_fwd_flag | 20 | 20 |
| green | tip_amount | 20 | 20 |
| green | tolls_amount | 20 | 20 |
| green | total_amount | 20 | 20 |
| green | trip_distance | 20 | 20 |
| green | trip_type | 20 | 20 |
| yellow | Airport_fee | 20 | 20 |
| yellow | DOLocationID | 20 | 20 |
| yellow | PULocationID | 20 | 20 |
| yellow | RatecodeID | 20 | 20 |
| yellow | VendorID | 20 | 20 |
| yellow | cbd_congestion_fee | 8 | 20 |
| yellow | congestion_surcharge | 20 | 20 |
| yellow | extra | 20 | 20 |
| yellow | fare_amount | 20 | 20 |
| yellow | improvement_surcharge | 20 | 20 |
| yellow | mta_tax | 20 | 20 |
| yellow | passenger_count | 20 | 20 |
| yellow | payment_type | 20 | 20 |
| yellow | request_source | 3 | 20 |
| yellow | store_and_fwd_flag | 20 | 20 |
| yellow | tip_amount | 20 | 20 |
| yellow | tolls_amount | 20 | 20 |
| yellow | total_amount | 20 | 20 |
| yellow | tpep_dropoff_datetime | 20 | 20 |
| yellow | tpep_pickup_datetime | 20 | 20 |
| yellow | trip_distance | 20 | 20 |

43 filas, 0.01 s

## 3.3 Columnas que solo existen en un tipo de taxi

```sql
WITH y AS (SELECT column_name FROM (DESCRIBE SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true))),
     g AS (SELECT column_name FROM (DESCRIBE SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true)))
SELECT coalesce(y.column_name, g.column_name) AS columna,
       y.column_name IS NOT NULL AS en_yellow,
       g.column_name IS NOT NULL AS en_green
FROM y FULL OUTER JOIN g ON y.column_name = g.column_name
WHERE y.column_name IS NULL OR g.column_name IS NULL
ORDER BY columna;
```

| columna | en_yellow | en_green |
|---|---|---|
| Airport_fee | True | False |
| ehail_fee | False | True |
| lpep_dropoff_datetime | False | True |
| lpep_pickup_datetime | False | True |
| tpep_dropoff_datetime | True | False |
| tpep_pickup_datetime | True | False |
| trip_type | False | True |

7 filas, 0.00 s

## 3.4 Tipos de datos yellow

```sql
DESCRIBE SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true);
```

| column_name | column_type | null | key | default | extra |
|---|---|---|---|---|---|
| VendorID | INTEGER | YES | NULL | NULL | NULL |
| tpep_pickup_datetime | TIMESTAMP | YES | NULL | NULL | NULL |
| tpep_dropoff_datetime | TIMESTAMP | YES | NULL | NULL | NULL |
| passenger_count | BIGINT | YES | NULL | NULL | NULL |
| trip_distance | DOUBLE | YES | NULL | NULL | NULL |
| RatecodeID | BIGINT | YES | NULL | NULL | NULL |
| store_and_fwd_flag | VARCHAR | YES | NULL | NULL | NULL |
| PULocationID | INTEGER | YES | NULL | NULL | NULL |
| DOLocationID | INTEGER | YES | NULL | NULL | NULL |
| payment_type | BIGINT | YES | NULL | NULL | NULL |
| fare_amount | DOUBLE | YES | NULL | NULL | NULL |
| extra | DOUBLE | YES | NULL | NULL | NULL |
| mta_tax | DOUBLE | YES | NULL | NULL | NULL |
| tip_amount | DOUBLE | YES | NULL | NULL | NULL |
| tolls_amount | DOUBLE | YES | NULL | NULL | NULL |
| improvement_surcharge | DOUBLE | YES | NULL | NULL | NULL |
| total_amount | DOUBLE | YES | NULL | NULL | NULL |
| congestion_surcharge | DOUBLE | YES | NULL | NULL | NULL |
| Airport_fee | DOUBLE | YES | NULL | NULL | NULL |
| cbd_congestion_fee | DOUBLE | YES | NULL | NULL | NULL |
| request_source | VARCHAR | YES | NULL | NULL | NULL |

21 filas, 0.00 s

## 3.4 Tipos de datos green

```sql
DESCRIBE SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true);
```

| column_name | column_type | null | key | default | extra |
|---|---|---|---|---|---|
| VendorID | INTEGER | YES | NULL | NULL | NULL |
| lpep_pickup_datetime | TIMESTAMP | YES | NULL | NULL | NULL |
| lpep_dropoff_datetime | TIMESTAMP | YES | NULL | NULL | NULL |
| store_and_fwd_flag | VARCHAR | YES | NULL | NULL | NULL |
| RatecodeID | BIGINT | YES | NULL | NULL | NULL |
| PULocationID | INTEGER | YES | NULL | NULL | NULL |
| DOLocationID | INTEGER | YES | NULL | NULL | NULL |
| passenger_count | BIGINT | YES | NULL | NULL | NULL |
| trip_distance | DOUBLE | YES | NULL | NULL | NULL |
| fare_amount | DOUBLE | YES | NULL | NULL | NULL |
| extra | DOUBLE | YES | NULL | NULL | NULL |
| mta_tax | DOUBLE | YES | NULL | NULL | NULL |
| tip_amount | DOUBLE | YES | NULL | NULL | NULL |
| tolls_amount | DOUBLE | YES | NULL | NULL | NULL |
| ehail_fee | DOUBLE | YES | NULL | NULL | NULL |
| improvement_surcharge | DOUBLE | YES | NULL | NULL | NULL |
| total_amount | DOUBLE | YES | NULL | NULL | NULL |
| payment_type | BIGINT | YES | NULL | NULL | NULL |
| trip_type | BIGINT | YES | NULL | NULL | NULL |
| congestion_surcharge | DOUBLE | YES | NULL | NULL | NULL |
| cbd_congestion_fee | DOUBLE | YES | NULL | NULL | NULL |
| request_source | VARCHAR | YES | NULL | NULL | NULL |

22 filas, 0.00 s

## 3.5 Muestra de registros yellow

```sql
SELECT * EXCLUDE (filename)
FROM yellow
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);
```

| VendorID | tpep_pickup_datetime | tpep_dropoff_datetime | passenger_count | trip_distance | RatecodeID | store_and_fwd_flag | PULocationID | DOLocationID | payment_type | fare_amount | extra | mta_tax | tip_amount | tolls_amount | improvement_surcharge | total_amount | congestion_surcharge | Airport_fee | cbd_congestion_fee | request_source | anio_archivo | mes_archivo |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2024-01-01 00:29:59 | 2024-01-01 00:36:40 | 1 | 1.3 | 1 | N | 239 | 236 | 1 | 9.3 | 3.5 | 0.5 | 1 | 0 | 1 | 15.3 | 2.5 | 0 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-01 00:20:38 | 2024-01-01 00:32:34 | 1 | 1.89 | 1 | N | 170 | 113 | 4 | -12.8 | -1 | -0.5 | 0 | 0 | -1 | -17.8 | -2.5 | 0 | NULL | NULL | 2024 | 1 |
| 1 | 2024-01-01 02:25:40 | 2024-01-01 02:27:31 | 1 | 0.5 | 1 | N | 141 | 229 | 1 | 4.4 | 3.5 | 0.5 | 1.85 | 0 | 1 | 11.25 | 2.5 | 0 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-01 03:45:11 | 2024-01-01 04:05:43 | 2 | 12.69 | 1 | N | 163 | 200 | 1 | 49.9 | 1 | 0.5 | 11.62 | 3.18 | 1 | 69.7 | 2.5 | 0 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-01 03:39:03 | 2024-01-01 03:52:34 | 5 | 3.82 | 1 | N | 261 | 246 | 1 | 19.1 | 1 | 0.5 | 4.82 | 0 | 1 | 28.92 | 2.5 | 0 | NULL | NULL | 2024 | 1 |

5 filas, 0.19 s

## 3.5 Muestra de registros green

```sql
SELECT * EXCLUDE (filename)
FROM green
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);
```

| VendorID | lpep_pickup_datetime | lpep_dropoff_datetime | store_and_fwd_flag | RatecodeID | PULocationID | DOLocationID | passenger_count | trip_distance | fare_amount | extra | mta_tax | tip_amount | tolls_amount | ehail_fee | improvement_surcharge | total_amount | payment_type | trip_type | congestion_surcharge | cbd_congestion_fee | request_source | anio_archivo | mes_archivo |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 2024-01-01 17:06:29 | 2024-01-01 17:46:39 | N | 1 | 129 | 197 | 1 | 10.06 | 53.4 | 0 | 0.5 | 1 | 0 | NULL | 1 | 55.9 | 1 | 1 | 0 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-02 12:50:13 | 2024-01-02 12:57:40 | N | 1 | 236 | 237 | 1 | 1.22 | 9.3 | 0 | 0.5 | 0 | 0 | NULL | 1 | 13.55 | 2 | 1 | 2.75 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-10 11:08:40 | 2024-01-10 11:16:24 | N | 1 | 75 | 236 | 1 | 1.08 | 8.6 | 0 | 0.5 | 0 | 0 | NULL | 1 | 12.85 | 2 | 1 | 2.75 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-11 17:28:44 | 2024-01-11 17:43:00 | N | 1 | 75 | 141 | 1 | 2 | 14.9 | 2.5 | 0.5 | 5.41 | 0 | NULL | 1 | 27.06 | 1 | 1 | 2.75 | NULL | NULL | 2024 | 1 |
| 2 | 2024-01-12 17:01:58 | 2024-01-12 17:15:18 | N | 1 | 95 | 28 | 1 | 1.56 | 14.2 | 2.5 | 0.5 | 3.64 | 0 | NULL | 1 | 21.84 | 1 | 1 | 0 | NULL | NULL | 2024 | 1 |

5 filas, 0.01 s

## 3.6 Perfil de columnas yellow

```sql
SUMMARIZE SELECT * EXCLUDE (filename) FROM yellow;
```

| column_name | column_type | min | max | approx_unique | avg | std | q25 | q50 | q75 | count | null_percentage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VendorID | INTEGER | 1 | 7 | 4 | 1.8151568420024107 | 0.5687845418931917 | 2 | 2 | 2 | 70873075 | 0.00 |
| tpep_pickup_datetime | TIMESTAMP | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 41962329 | 2025-04-10 09:08:07.177432 | NULL | 2024-06-07 21:36:25.57222 | 2024-11-14 13:37:11.17121 | 2026-04-08 02:37:11.697874 | 70873075 | 0.00 |
| tpep_dropoff_datetime | TIMESTAMP | 2001-01-01 16:09:38 | 2026-09-01 20:16:00 | 44326272 | 2025-04-10 09:25:39.691221 | NULL | 2024-06-08 00:48:13.466477 | 2024-11-15 11:47:56.917237 | 2026-04-08 23:18:41.313248 | 70873075 | 0.00 |
| passenger_count | BIGINT | 0 | 9 | 11 | 1.3024764431753375 | 0.7603765421670371 | 1 | 1 | 1 | 70873075 | 16.66 |
| trip_distance | DOUBLE | 0.0 | 398608.62 | 9128 | 5.217857819490747 | 478.7212052238778 | 1.0184008891578198 | 1.7941958767941129 | 3.532212114939198 | 70873075 | 0.00 |
| RatecodeID | BIGINT | 1 | 99 | 7 | 3.143068311595898 | 14.02583507992936 | 1 | 1 | 1 | 70873075 | 16.66 |
| store_and_fwd_flag | VARCHAR | N | Y | 2 | NULL | NULL | NULL | NULL | NULL | 70873075 | 16.66 |
| PULocationID | INTEGER | 1 | 265 | 298 | 163.12592827388963 | 65.37301320360997 | 127 | 161 | 233 | 70873075 | 0.00 |
| DOLocationID | INTEGER | 1 | 265 | 298 | 162.44324911823003 | 70.08392240165541 | 112 | 162 | 234 | 70873075 | 0.00 |
| payment_type | BIGINT | 0 | 5 | 6 | 1.0045423597043024 | 0.6605099300579668 | 1 | 1 | 1 | 70873075 | 0.00 |
| fare_amount | DOUBLE | -2555.2 | 335544.44 | 24784 | 20.10404811105255 | 59.75536143611364 | 9.337858199341438 | 14.513579043604302 | 24.171144021787835 | 70873075 | 0.00 |
| extra | DOUBLE | -9.25 | 244.35 | 464 | 1.2714311202103141 | 1.793920931854958 | 0.0 | 0.007246519141661546 | 2.5 | 70873075 | 0.00 |
| mta_tax | DOUBLE | -0.5 | 41.3 | 38 | 0.4833289049473307 | 0.11576779498489911 | 0.5 | 0.5 | 0.5 | 70873075 | 0.00 |
| tip_amount | DOUBLE | -300.0 | 999.99 | 7653 | 3.1080671078577646 | 4.04588404250285 | 0.0 | 2.437139571957512 | 4.111447965749402 | 70873075 | 0.00 |
| tolls_amount | DOUBLE | -140.63 | 1702.88 | 4565 | 0.5508590940890472 | 2.2349268150065273 | 0.0 | 0.0 | 0.0 | 70873075 | 0.00 |
| improvement_surcharge | DOUBLE | -1.0 | 4.0 | 10 | 0.9642495432854998 | 0.23644926315353543 | 1.0 | 1.0 | 1.0 | 70873075 | 0.00 |
| total_amount | DOUBLE | -2560.2 | 335550.94 | 50956 | 28.770309049186377 | 61.296097023728315 | 16.380288894771038 | 22.0276479878138 | 32.34087005954752 | 70873075 | 0.00 |
| congestion_surcharge | DOUBLE | -2.5 | 2.75 | 11 | 2.226476273024256 | 0.8606608247041211 | 2.5 | 2.5 | 2.5 | 70873075 | 16.66 |
| Airport_fee | DOUBLE | -2.0 | 27.0 | 16 | 0.15447461790289047 | 0.5317496060548358 | 0.0 | 0.0 | 0.0 | 70873075 | 16.66 |
| cbd_congestion_fee | DOUBLE | -0.75 | 0.75 | 3 | 0.5355387211309968 | 0.3447052699155588 | 0.0 | 0.75 | 0.75 | 70873075 | 58.09 |
| request_source | VARCHAR | A | HV0005 | 3 | NULL | NULL | NULL | NULL | NULL | 70873075 | 95.90 |
| anio_archivo | INTEGER | 2024 | 2026 | 2 | 2024.8382126780868 | 0.9868256564371884 | 2024 | 2024 | 2026 | 70873075 | 0.00 |
| mes_archivo | INTEGER | 1 | 12 | 13 | 5.73935035272563 | 3.1852879119292115 | 3 | 5 | 8 | 70873075 | 0.00 |

23 filas, 17.83 s

## 3.6 Perfil de columnas green

```sql
SUMMARIZE SELECT * EXCLUDE (filename) FROM green;
```

| column_name | column_type | min | max | approx_unique | avg | std | q25 | q50 | q75 | count | null_percentage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VendorID | INTEGER | 1 | 6 | 3 | 2.030322901501205 | 0.8170451025850336 | 2 | 2 | 2 | 997332 | 0.00 |
| lpep_pickup_datetime | TIMESTAMP | 2008-12-31 00:00:00 | 2026-08-31 23:58:28 | 1035093 | 2025-02-11 15:07:53.76982 | NULL | 2024-05-13 23:13:54.930324 | 2024-10-05 04:35:35.577581 | 2026-03-06 01:49:22.170071 | 997332 | 0.00 |
| lpep_dropoff_datetime | TIMESTAMP | 2008-12-31 00:00:00 | 2026-09-02 09:39:37 | 1290902 | 2025-02-11 15:27:55.083787 | NULL | 2024-05-14 00:03:38.946985 | 2024-10-05 18:21:51.0408 | 2026-03-06 21:46:47.192 | 997332 | 0.00 |
| store_and_fwd_flag | VARCHAR | N | Y | 2 | NULL | NULL | NULL | NULL | NULL | 997332 | 7.33 |
| RatecodeID | BIGINT | 1 | 99 | 7 | 1.2272694321428996 | 1.296012166670338 | 1 | 1 | 1 | 997332 | 7.33 |
| PULocationID | INTEGER | 1 | 265 | 266 | 96.70922822089334 | 57.02235512134103 | 74 | 75 | 103 | 997332 | 0.00 |
| DOLocationID | INTEGER | 1 | 265 | 266 | 141.82127415945743 | 76.84107286162042 | 74 | 140 | 227 | 997332 | 0.00 |
| passenger_count | BIGINT | 0 | 9 | 11 | 1.3118859070641584 | 0.9705271926655912 | 1 | 1 | 1 | 997332 | 7.33 |
| trip_distance | DOUBLE | 0.0 | 233972.43 | 3072 | 15.779716874621615 | 969.061751179461 | 1.1762251812059286 | 1.930665536828385 | 3.4195168065905057 | 997332 | 0.00 |
| fare_amount | DOUBLE | -500.0 | 1676.7 | 6569 | 17.902603646528906 | 17.54008860372054 | 9.300817192123946 | 13.556597244963267 | 20.39415853233546 | 997332 | 0.00 |
| extra | DOUBLE | -7.5 | 12.0 | 27 | 0.8929476743952866 | 1.3892603289634509 | 0.0 | 0.0 | 1.0612998309699886 | 997332 | 0.00 |
| mta_tax | DOUBLE | -0.5 | 5.0 | 9 | 0.5659712613252157 | 0.34729978984401444 | 0.5 | 0.5 | 0.5 | 997332 | 0.00 |
| tip_amount | DOUBLE | -65.0 | 495.0 | 2509 | 2.5899862332703116 | 4.20191990786538 | 0.0 | 2.0231298072192287 | 3.8384045608898845 | 997332 | 0.00 |
| tolls_amount | DOUBLE | -24.5 | 85.0 | 147 | 0.2531391251859833 | 1.414542256458781 | 0.0 | 0.0 | 0.0 | 997332 | 0.00 |
| ehail_fee | DOUBLE | NULL | NULL | 0 | NULL | NULL | NULL | NULL | NULL | 997332 | 100.00 |
| improvement_surcharge | DOUBLE | -1.0 | 1.0 | 5 | 0.958244496316275 | 0.1940417825793432 | 1.0 | 1.0 | 1.0 | 997332 | 0.00 |
| total_amount | DOUBLE | -501.5 | 1678.2 | 11049 | 24.67977087870416 | 19.855546883626037 | 14.177316890220649 | 19.722097876924458 | 28.771951868233913 | 997332 | 0.00 |
| payment_type | BIGINT | 1 | 5 | 5 | 1.2819203898600888 | 0.4810694925850272 | 1 | 1 | 2 | 997332 | 7.33 |
| trip_type | BIGINT | 1 | 2 | 2 | 1.0475466512289737 | 0.212805113164685 | 1 | 1 | 1 | 997332 | 7.34 |
| congestion_surcharge | DOUBLE | -2.75 | 2.75 | 6 | 0.8348482897636841 | 1.2637901318318423 | 0.0 | 0.0 | 2.75 | 997332 | 7.33 |
| cbd_congestion_fee | DOUBLE | -0.75 | 0.75 | 3 | 0.06234018759232782 | 0.20713685724463027 | 0.0 | 0.0 | 0.0 | 997332 | 66.20 |
| request_source | VARCHAR | A | HV0005 | 2 | NULL | NULL | NULL | NULL | NULL | 997332 | 98.07 |
| anio_archivo | INTEGER | 2024 | 2026 | 2 | 2024.6760316524487 | 0.9460683945816633 | 2024 | 2024 | 2026 | 997332 | 0.00 |
| mes_archivo | INTEGER | 1 | 12 | 13 | 5.790175187399983 | 3.2224047883520726 | 3 | 6 | 8 | 997332 | 0.00 |

24 filas, 0.26 s

## 3.6 Problemas de calidad por regla

```sql
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
```

| tipo | regla | registros | pct |
|---|---|---|---|
| yellow | total distinto a la suma | 22682958 | 32.005 |
| yellow | payment_type fuera del diccionario | 11807920 | 16.661 |
| yellow | RatecodeID nulo | 11807920 | 16.661 |
| yellow | pasajeros nulo | 11807920 | 16.661 |
| yellow | distancia = 0 | 1728536 | 2.439 |
| yellow | RatecodeID fuera del diccionario | 1236667 | 1.745 |
| yellow | tarifa negativa | 888388 | 1.253 |
| yellow | total negativo | 771179 | 1.088 |
| yellow | zona desconocida | 627146 | 0.885 |
| yellow | pasajeros = 0 | 492713 | 0.695 |
| yellow | duracion = 0 | 383608 | 0.541 |
| yellow | duracion > 6 horas | 29338 | 0.041 |
| yellow | total = 0 | 10320 | 0.015 |
| yellow | distancia > 100 millas | 2836 | 0.004 |
| yellow | tarifa > 500 USD | 1174 | 0.002 |
| yellow | dropoff antes del pickup | 1585 | 0.002 |
| yellow | pickup fuera del mes del archivo | 566 | 0.001 |
| yellow | pasajeros > 6 | 312 | 0 |
| green | total distinto a la suma | 152231 | 15.264 |
| green | RatecodeID nulo | 73103 | 7.33 |
| green | pasajeros nulo | 73103 | 7.33 |
| green | distancia = 0 | 46786 | 4.691 |
| green | zona desconocida | 14491 | 1.453 |
| green | pasajeros = 0 | 11320 | 1.135 |
| green | duracion > 6 horas | 3733 | 0.374 |
| green | total negativo | 3197 | 0.321 |
| green | tarifa negativa | 3143 | 0.315 |
| green | total = 0 | 943 | 0.095 |
| green | duracion = 0 | 889 | 0.089 |
| green | distancia > 100 millas | 307 | 0.031 |
| green | pickup fuera del mes del archivo | 262 | 0.026 |
| green | pasajeros > 6 | 247 | 0.025 |
| green | RatecodeID fuera del diccionario | 84 | 0.008 |
| green | tarifa > 500 USD | 55 | 0.006 |
| green | dropoff antes del pickup | 7 | 0.001 |
| green | payment_type fuera del diccionario | 0 | 0 |

36 filas, 1.96 s

## 3.6 Rango de fechas de pickup

```sql
SELECT tipo,
       min(pickup) AS pickup_min,
       max(pickup) AS pickup_max,
       min(make_date(anio_archivo, mes_archivo, 1)) AS esperado_desde,
       max(make_date(anio_archivo, mes_archivo, 1) + INTERVAL 1 MONTH) AS esperado_hasta
FROM viajes
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | pickup_min | pickup_max | esperado_desde | esperado_hasta |
|---|---|---|---|---|
| yellow | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 2024-01-01 | 2026-09-01 00:00:00 |
| green | 2008-12-31 00:00:00 | 2026-08-31 23:58:28 | 2024-01-01 | 2026-09-01 00:00:00 |

2 filas, 0.20 s

## 3.6 Pickups fuera del mes de su archivo

```sql
SELECT tipo, strftime(pickup, '%Y-%m') AS mes_pickup, count(*) AS registros
FROM viajes
WHERE year(pickup) <> anio_archivo OR month(pickup) <> mes_archivo
GROUP BY ALL
ORDER BY tipo DESC, mes_pickup;
```

| tipo | mes_pickup | registros |
|---|---|---|
| yellow | 2001-01 | 1 |
| yellow | 2002-12 | 11 |
| yellow | 2008-12 | 14 |
| yellow | 2009-01 | 24 |
| yellow | 2023-12 | 10 |
| yellow | 2024-01 | 11 |
| yellow | 2024-02 | 22 |
| yellow | 2024-03 | 6 |
| yellow | 2024-04 | 15 |
| yellow | 2024-05 | 43 |
| yellow | 2024-06 | 28 |
| yellow | 2024-07 | 20 |
| yellow | 2024-08 | 60 |
| yellow | 2024-09 | 44 |
| yellow | 2024-10 | 49 |
| yellow | 2024-11 | 53 |
| yellow | 2024-12 | 13 |
| yellow | 2025-01 | 2 |
| yellow | 2025-02 | 1 |
| yellow | 2025-03 | 2 |
| yellow | 2025-12 | 6 |
| yellow | 2026-01 | 12 |
| yellow | 2026-02 | 16 |
| yellow | 2026-03 | 11 |
| yellow | 2026-04 | 28 |
| yellow | 2026-05 | 2 |
| yellow | 2026-06 | 10 |
| yellow | 2026-07 | 14 |
| yellow | 2026-08 | 38 |
| green | 2008-12 | 9 |
| green | 2009-01 | 8 |
| green | 2023-12 | 2 |
| green | 2024-01 | 6 |
| green | 2024-02 | 7 |
| green | 2024-03 | 4 |
| green | 2024-04 | 6 |
| green | 2024-05 | 13 |
| green | 2024-06 | 3 |
| green | 2024-07 | 9 |
| green | 2024-08 | 55 |
| green | 2024-09 | 16 |
| green | 2024-10 | 13 |
| green | 2024-11 | 7 |
| green | 2024-12 | 5 |
| green | 2025-01 | 11 |
| green | 2025-12 | 4 |
| green | 2026-01 | 8 |
| green | 2026-02 | 26 |
| green | 2026-03 | 4 |
| green | 2026-04 | 8 |

54 filas, 0.19 s

## 3.6 Valores de columnas categoricas

```sql
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
```

| tipo | columna | valor | registros |
|---|---|---|---|
| yellow | RatecodeID | 1 | 54753099 |
| yellow | RatecodeID | 2 | 2101806 |
| yellow | RatecodeID | 3 | 220003 |
| yellow | RatecodeID | 4 | 168927 |
| yellow | RatecodeID | 5 | 584562 |
| yellow | RatecodeID | 6 | 91 |
| yellow | RatecodeID | 99 | 1236667 |
| yellow | VendorID | 1 | 15182989 |
| yellow | VendorID | 2 | 55261277 |
| yellow | VendorID | 6 | 61459 |
| yellow | VendorID | 7 | 367350 |
| yellow | payment_type | 0 | 11807920 |
| yellow | payment_type | 1 | 49393167 |
| yellow | payment_type | 2 | 8248119 |
| yellow | payment_type | 3 | 389881 |
| yellow | payment_type | 4 | 1033982 |
| yellow | payment_type | 5 | 6 |
| yellow | store_and_fwd_flag | N | 58855655 |
| yellow | store_and_fwd_flag | Y | 209500 |
| green | RatecodeID | 1 | 871065 |
| green | RatecodeID | 2 | 2728 |
| green | RatecodeID | 3 | 620 |
| green | RatecodeID | 4 | 1085 |
| green | RatecodeID | 5 | 48641 |
| green | RatecodeID | 6 | 6 |
| green | RatecodeID | 99 | 84 |
| green | VendorID | 1 | 109146 |
| green | VendorID | 2 | 853339 |
| green | VendorID | 6 | 34847 |
| green | payment_type | 1 | 674667 |
| green | payment_type | 2 | 240934 |
| green | payment_type | 3 | 6288 |
| green | payment_type | 4 | 2311 |
| green | payment_type | 5 | 29 |
| green | store_and_fwd_flag | N | 922065 |
| green | store_and_fwd_flag | Y | 2164 |
| green | trip_type | 1 | 880205 |
| green | trip_type | 2 | 43940 |

38 filas, 1.23 s

## 3.6 Viajes duplicados

```sql
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
```

| tipo | grupos_duplicados | registros_sobrantes |
|---|---|---|
| yellow | 32801 | 32801 |

1 filas, 1.89 s
