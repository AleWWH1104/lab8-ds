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

0 filas, 0.04 s

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
| green | 2026 | 8 | 2026-01 | 2026-08 |
| yellow | 2026 | 8 | 2026-01 | 2026-08 |

2 filas, 0.00 s

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
| green | 8 | 337114 |
| yellow | 8 | 29703355 |

2 filas, 0.01 s

## 3.2 Registros por mes

```sql
SELECT tipo, anio_archivo AS anio, mes_archivo AS mes, count(*) AS registros
FROM viajes
GROUP BY ALL
ORDER BY tipo, anio, mes;
```

| tipo | anio | mes | registros |
|---|---|---|---|
| green | 2026 | 1 | 40272 |
| green | 2026 | 2 | 37373 |
| green | 2026 | 3 | 44208 |
| green | 2026 | 4 | 44238 |
| green | 2026 | 5 | 44921 |
| green | 2026 | 6 | 44163 |
| green | 2026 | 7 | 41252 |
| green | 2026 | 8 | 40687 |
| yellow | 2026 | 1 | 3724889 |
| yellow | 2026 | 2 | 3399866 |
| yellow | 2026 | 3 | 3952451 |
| yellow | 2026 | 4 | 3831240 |
| yellow | 2026 | 5 | 4090836 |
| yellow | 2026 | 6 | 3837248 |
| yellow | 2026 | 7 | 3530109 |
| yellow | 2026 | 8 | 3336716 |

16 filas, 0.04 s

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
| green | DOLocationID | 8 | 8 |
| green | PULocationID | 8 | 8 |
| green | RatecodeID | 8 | 8 |
| green | VendorID | 8 | 8 |
| green | cbd_congestion_fee | 8 | 8 |
| green | congestion_surcharge | 8 | 8 |
| green | ehail_fee | 8 | 8 |
| green | extra | 8 | 8 |
| green | fare_amount | 8 | 8 |
| green | improvement_surcharge | 8 | 8 |
| green | lpep_dropoff_datetime | 8 | 8 |
| green | lpep_pickup_datetime | 8 | 8 |
| green | mta_tax | 8 | 8 |
| green | passenger_count | 8 | 8 |
| green | payment_type | 8 | 8 |
| green | request_source | 3 | 8 |
| green | store_and_fwd_flag | 8 | 8 |
| green | tip_amount | 8 | 8 |
| green | tolls_amount | 8 | 8 |
| green | total_amount | 8 | 8 |
| green | trip_distance | 8 | 8 |
| green | trip_type | 8 | 8 |
| yellow | Airport_fee | 8 | 8 |
| yellow | DOLocationID | 8 | 8 |
| yellow | PULocationID | 8 | 8 |
| yellow | RatecodeID | 8 | 8 |
| yellow | VendorID | 8 | 8 |
| yellow | cbd_congestion_fee | 8 | 8 |
| yellow | congestion_surcharge | 8 | 8 |
| yellow | extra | 8 | 8 |
| yellow | fare_amount | 8 | 8 |
| yellow | improvement_surcharge | 8 | 8 |
| yellow | mta_tax | 8 | 8 |
| yellow | passenger_count | 8 | 8 |
| yellow | payment_type | 8 | 8 |
| yellow | request_source | 3 | 8 |
| yellow | store_and_fwd_flag | 8 | 8 |
| yellow | tip_amount | 8 | 8 |
| yellow | tolls_amount | 8 | 8 |
| yellow | total_amount | 8 | 8 |
| yellow | tpep_dropoff_datetime | 8 | 8 |
| yellow | tpep_pickup_datetime | 8 | 8 |
| yellow | trip_distance | 8 | 8 |

43 filas, 0.02 s

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

7 filas, 0.01 s

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
| 1 | 2026-01-01 00:34:45 | 2026-01-01 00:40:15 | 4 | 0.9 | 1 | N | 262 | 141 | 1 | 7.9 | 3.5 | 0.5 | 3.2 | 0 | 1 | 16.1 | 2.5 | 0 | 0 | NULL | 2026 | 1 |
| 1 | 2026-01-01 00:06:07 | 2026-01-01 00:20:20 | 2 | 1.9 | 1 | N | 231 | 90 | 1 | 14.2 | 4.25 | 0.5 | 3.95 | 0 | 1 | 23.9 | 2.5 | 0 | 0.75 | NULL | 2026 | 1 |
| 2 | 2026-01-01 03:15:42 | 2026-01-01 03:20:33 | 1 | 1.15 | 1 | N | 263 | 140 | 1 | 7.2 | 1 | 0.5 | 2.44 | 0 | 1 | 14.64 | 2.5 | 0 | 0 | NULL | 2026 | 1 |
| 2 | 2026-01-01 04:25:35 | 2026-01-01 04:38:18 | 1 | 3.69 | 1 | N | 107 | 143 | 1 | 17.7 | 1 | 0.5 | 4.69 | 0 | 1 | 28.14 | 2.5 | 0 | 0.75 | NULL | 2026 | 1 |
| 2 | 2026-01-01 06:33:56 | 2026-01-01 06:55:37 | 2 | 10.27 | 2 | N | 68 | 138 | 2 | 70 | 0 | 0.5 | 0 | 6.94 | 1 | 81.69 | 2.5 | 0 | 0.75 | NULL | 2026 | 1 |

5 filas, 0.14 s

## 3.5 Muestra de registros green

```sql
SELECT * EXCLUDE (filename)
FROM green
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);
```

| VendorID | lpep_pickup_datetime | lpep_dropoff_datetime | store_and_fwd_flag | RatecodeID | PULocationID | DOLocationID | passenger_count | trip_distance | fare_amount | extra | mta_tax | tip_amount | tolls_amount | ehail_fee | improvement_surcharge | total_amount | payment_type | trip_type | congestion_surcharge | cbd_congestion_fee | request_source | anio_archivo | mes_archivo |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 2026-01-02 05:43:34 | 2026-01-02 05:44:09 | N | 5 | 34 | 34 | 2 | 0.4 | 70 | 0 | 0 | 14.2 | 0 | NULL | 1 | 85.2 | 1 | 2 | 0 | 0 | NULL | 2026 | 1 |
| 2 | 2026-01-02 21:02:00 | 2026-01-02 21:07:42 | N | 1 | 74 | 41 | 1 | 1.17 | 7.9 | 1 | 0.5 | 2.08 | 0 | NULL | 1 | 12.48 | 1 | 1 | 0 | 0 | NULL | 2026 | 1 |
| 1 | 2026-01-14 21:03:03 | 2026-01-14 21:06:16 | N | 1 | 181 | 65 | 1 | 0.6 | 5.8 | 1 | 1.5 | 0 | 0 | NULL | 1 | 8.3 | 2 | 1 | 0 | 0 | NULL | 2026 | 1 |
| 2 | 2026-01-16 19:11:20 | 2026-01-16 19:29:44 | N | 1 | 74 | 151 | 1 | 2.33 | 17.7 | 2.5 | 0.5 | 4.34 | 0 | NULL | 1 | 26.04 | 1 | 1 | 0 | 0 | NULL | 2026 | 1 |
| 2 | 2026-01-19 02:15:45 | 2026-01-19 02:20:57 | N | 1 | 95 | 102 | 1 | 1.35 | 8.6 | 1 | 0.5 | 1 | 0 | NULL | 1 | 12.1 | 1 | 1 | 0 | 0 | NULL | 2026 | 1 |

5 filas, 0.02 s

## 3.6 Perfil de columnas yellow

```sql
SUMMARIZE SELECT * EXCLUDE (filename) FROM yellow;
```

| column_name | column_type | min | max | approx_unique | avg | std | q25 | q50 | q75 | count | null_percentage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VendorID | INTEGER | 1 | 7 | 4 | 1.885739809526567 | 0.7155277514022323 | 2 | 2 | 2 | 29703355 | 0.00 |
| tpep_pickup_datetime | TIMESTAMP | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 16867928 | 2026-04-30 15:29:29.519432 | NULL | 2026-03-02 23:52:06.53433 | 2026-04-30 11:05:41.574534 | 2026-06-25 21:53:48.24398 | 29703355 | 0.00 |
| tpep_dropoff_datetime | TIMESTAMP | 2001-01-01 16:09:38 | 2026-09-01 20:16:00 | 16587125 | 2026-04-30 15:47:08.186216 | NULL | 2026-03-03 19:17:40.409927 | 2026-04-30 13:35:53.974384 | 2026-06-25 23:25:52.691194 | 29703355 | 0.00 |
| passenger_count | BIGINT | 0 | 9 | 11 | 1.2494318488564 | 0.6529195072996691 | 1 | 1 | 1 | 29703355 | 25.98 |
| trip_distance | DOUBLE | 0.0 | 328522.2 | 7217 | 5.552940149690995 | 550.6497893230968 | 1.0219672973102896 | 1.8578425268156686 | 3.8070706746075635 | 29703355 | 0.00 |
| RatecodeID | BIGINT | 1 | 99 | 7 | 4.527471444398553 | 18.000926540066708 | 1 | 1 | 1 | 29703355 | 25.98 |
| store_and_fwd_flag | VARCHAR | N | Y | 2 | NULL | NULL | NULL | NULL | NULL | 29703355 | 25.98 |
| PULocationID | INTEGER | 1 | 265 | 290 | 161.57793013617484 | 66.74656703251738 | 117 | 161 | 233 | 29703355 | 0.00 |
| DOLocationID | INTEGER | 1 | 265 | 298 | 161.05139342003622 | 70.72548569211408 | 109 | 162 | 234 | 29703355 | 0.00 |
| payment_type | BIGINT | 0 | 5 | 6 | 0.8621735154160195 | 0.6463324345961723 | 0 | 1 | 1 | 29703355 | 0.00 |
| fare_amount | DOUBLE | -2555.2 | 7045.0 | 18028 | 21.262128779063765 | 18.958296845957587 | 10.006273905911891 | 15.814262631289584 | 26.42674169852624 | 29703355 | 0.00 |
| extra | DOUBLE | -7.5 | 244.35 | 360 | 1.1127003451293647 | 1.7506914816701429 | 0.0 | 0.0 | 2.4998812156926635 | 29703355 | 0.00 |
| mta_tax | DOUBLE | -0.5 | 11.5 | 21 | 0.4882513830508372 | 0.09190423736483591 | 0.5 | 0.5 | 0.5 | 29703355 | 0.00 |
| tip_amount | DOUBLE | -222.0 | 766.0 | 6049 | 2.8311150171408612 | 3.966576420508174 | 0.0 | 2.0460440675455365 | 3.9637856849029856 | 29703355 | 0.00 |
| tolls_amount | DOUBLE | -129.48 | 1400.0 | 3451 | 0.5360736017852468 | 2.227031674085069 | 0.0 | 0.0 | 0.0 | 29703355 | 0.00 |
| improvement_surcharge | DOUBLE | -1.0 | 4.0 | 6 | 0.9659906263113022 | 0.2079128726687101 | 1.0 | 1.0 | 1.0 | 29703355 | 0.00 |
| total_amount | DOUBLE | -2560.2 | 7053.5 | 38649 | 30.069705772318255 | 22.75340804573234 | 17.39316334731522 | 23.605555121370784 | 34.60129118617536 | 29703355 | 0.00 |
| congestion_surcharge | DOUBLE | -2.5 | 2.75 | 7 | 2.216917730186208 | 0.8364476657907182 | 2.5 | 2.5 | 2.5 | 29703355 | 25.98 |
| Airport_fee | DOUBLE | -2.0 | 27.0 | 15 | 0.16706982008687357 | 0.5781861746411181 | 0.0 | 0.0 | 0.0 | 29703355 | 25.98 |
| cbd_congestion_fee | DOUBLE | -0.75 | 0.75 | 3 | 0.5355387211309968 | 0.3447052699155586 | 0.0 | 0.75 | 0.75 | 29703355 | 0.00 |
| request_source | VARCHAR | A | HV0005 | 3 | NULL | NULL | NULL | NULL | NULL | 29703355 | 90.23 |
| anio_archivo | INTEGER | 2026 | 2026 | 1 | 2026.0 | 0.0 | 2026 | 2026 | 2026 | 29703355 | 0.00 |
| mes_archivo | INTEGER | 1 | 8 | 9 | 4.463774984340994 | 2.24184651888366 | 3 | 4 | 6 | 29703355 | 0.00 |

23 filas, 18.82 s

## 3.6 Perfil de columnas green

```sql
SUMMARIZE SELECT * EXCLUDE (filename) FROM green;
```

| column_name | column_type | min | max | approx_unique | avg | std | q25 | q50 | q75 | count | null_percentage |
|---|---|---|---|---|---|---|---|---|---|---|---|
| VendorID | INTEGER | 1 | 6 | 3 | 2.328351833504393 | 1.2771882973738604 | 2 | 2 | 2 | 337114 | 0.00 |
| lpep_pickup_datetime | TIMESTAMP | 2008-12-31 17:35:31 | 2026-08-31 23:58:28 | 332702 | 2026-05-02 13:25:51.096427 | NULL | 2026-03-06 18:14:40.672812 | 2026-05-04 21:46:57.056986 | 2026-06-27 00:02:55.214728 | 337114 | 0.00 |
| lpep_dropoff_datetime | TIMESTAMP | 2008-12-31 23:16:26 | 2026-09-02 09:39:37 | 396286 | 2026-05-02 13:46:38.833759 | NULL | 2026-03-06 09:53:02.492197 | 2026-05-04 14:41:27.152196 | 2026-06-26 16:52:21.245521 | 337114 | 0.00 |
| store_and_fwd_flag | VARCHAR | N | Y | 2 | NULL | NULL | NULL | NULL | NULL | 337114 | 14.47 |
| RatecodeID | BIGINT | 1 | 99 | 7 | 1.2549672434183374 | 1.0015327424296085 | 1 | 1 | 1 | 337114 | 14.47 |
| PULocationID | INTEGER | 1 | 265 | 263 | 97.32761024460568 | 56.57830275002366 | 74 | 75 | 103 | 337114 | 0.00 |
| DOLocationID | INTEGER | 1 | 265 | 266 | 142.8768458147689 | 77.24476821098119 | 75 | 140 | 229 | 337114 | 0.00 |
| passenger_count | BIGINT | 0 | 9 | 11 | 1.3006461144694266 | 0.9481007387491747 | 1 | 1 | 1 | 337114 | 14.47 |
| trip_distance | DOUBLE | 0.0 | 179830.92 | 2472 | 13.349507644298376 | 880.4035093234568 | 1.2540250813216913 | 2.0663619081693927 | 3.6904232077127057 | 337114 | 0.00 |
| fare_amount | DOUBLE | -500.0 | 1676.7 | 4808 | 17.014101995170655 | 17.958627635270645 | 8.602759985705033 | 13.191192068389661 | 19.656607512964232 | 337114 | 0.00 |
| extra | DOUBLE | -7.5 | 10.0 | 21 | 0.8195284087875319 | 1.3603053200356505 | 0.0 | 0.0 | 1.0 | 337114 | 0.00 |
| mta_tax | DOUBLE | -0.5 | 5.0 | 7 | 0.5467816524973748 | 0.30968692134078063 | 0.5 | 0.5 | 0.5 | 337114 | 0.00 |
| tip_amount | DOUBLE | -14.0 | 495.0 | 2212 | 2.6208176165926957 | 5.399358172149611 | 0.0 | 2.0135278361674764 | 3.856168090417648 | 337114 | 0.00 |
| tolls_amount | DOUBLE | -24.5 | 85.0 | 75 | 0.29419875769026715 | 1.5552168995551903 | 0.0 | 0.0 | 0.0 | 337114 | 0.00 |
| ehail_fee | DOUBLE | NULL | NULL | 0 | NULL | NULL | NULL | NULL | NULL | 337114 | 100.00 |
| improvement_surcharge | DOUBLE | -1.0 | 1.0 | 5 | 0.915274654864791 | 0.25186030830555645 | 1.0 | 1.0 | 1.0 | 337114 | 0.00 |
| total_amount | DOUBLE | -501.5 | 1678.2 | 8186 | 25.492562070990623 | 20.552777231768655 | 14.943033419757974 | 20.446049944250927 | 29.640460036774154 | 337114 | 0.00 |
| payment_type | BIGINT | 1 | 4 | 4 | 1.2481350077512927 | 0.46247144512198074 | 1 | 1 | 1 | 337114 | 14.47 |
| trip_type | BIGINT | 1 | 2 | 2 | 1.0518525197945459 | 0.22172957965580276 | 1 | 1 | 1 | 337114 | 14.47 |
| congestion_surcharge | DOUBLE | -2.75 | 2.75 | 5 | 0.8831271524143456 | 1.2846843025235135 | 0.0 | 0.0 | 2.75 | 337114 | 14.47 |
| cbd_congestion_fee | DOUBLE | -0.75 | 0.75 | 3 | 0.06234018759232782 | 0.20713685724463027 | 0.0 | 0.0 | 0.0 | 337114 | 0.00 |
| request_source | VARCHAR | A | HV0005 | 2 | NULL | NULL | NULL | NULL | NULL | 337114 | 94.30 |
| anio_archivo | INTEGER | 2026 | 2026 | 1 | 2026.0 | 0.0 | 2026 | 2026 | 2026 | 337114 | 0.00 |
| mes_archivo | INTEGER | 1 | 8 | 9 | 4.53388764631549 | 2.248190980346276 | 3 | 5 | 6 | 337114 | 0.00 |

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
| yellow | total distinto a la suma | 10895756 | 36.682 |
| yellow | payment_type fuera del diccionario | 7716688 | 25.979 |
| yellow | RatecodeID nulo | 7716688 | 25.979 |
| yellow | pasajeros nulo | 7716688 | 25.979 |
| yellow | distancia = 0 | 952231 | 3.206 |
| yellow | RatecodeID fuera del diccionario | 769693 | 2.591 |
| yellow | duracion = 0 | 371673 | 1.251 |
| yellow | zona desconocida | 201486 | 0.678 |
| yellow | total negativo | 161835 | 0.545 |
| yellow | tarifa negativa | 157364 | 0.53 |
| yellow | pasajeros = 0 | 91359 | 0.308 |
| yellow | duracion > 6 horas | 7315 | 0.025 |
| yellow | total = 0 | 5258 | 0.018 |
| yellow | distancia > 100 millas | 1223 | 0.004 |
| yellow | tarifa > 500 USD | 574 | 0.002 |
| yellow | pasajeros > 6 | 28 | 0 |
| yellow | pickup fuera del mes del archivo | 146 | 0 |
| yellow | dropoff antes del pickup | 10 | 0 |
| green | total distinto a la suma | 66970 | 19.866 |
| green | RatecodeID nulo | 48775 | 14.468 |
| green | pasajeros nulo | 48775 | 14.468 |
| green | distancia = 0 | 12212 | 3.623 |
| green | zona desconocida | 5886 | 1.746 |
| green | pasajeros = 0 | 4527 | 1.343 |
| green | duracion > 6 horas | 1104 | 0.327 |
| green | total negativo | 1023 | 0.303 |
| green | tarifa negativa | 999 | 0.296 |
| green | total = 0 | 543 | 0.161 |
| green | duracion = 0 | 229 | 0.068 |
| green | pasajeros > 6 | 99 | 0.029 |
| green | pickup fuera del mes del archivo | 98 | 0.029 |
| green | distancia > 100 millas | 72 | 0.021 |
| green | tarifa > 500 USD | 19 | 0.006 |
| green | RatecodeID fuera del diccionario | 2 | 0.001 |
| green | dropoff antes del pickup | 5 | 0.001 |
| green | payment_type fuera del diccionario | 0 | 0 |

36 filas, 2.37 s

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
| yellow | 2001-01-01 09:23:58 | 2026-08-31 23:59:59 | 2026-01-01 | 2026-09-01 00:00:00 |
| green | 2008-12-31 17:35:31 | 2026-08-31 23:58:28 | 2026-01-01 | 2026-09-01 00:00:00 |

2 filas, 0.53 s

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
| yellow | 2008-12 | 4 |
| yellow | 2009-01 | 6 |
| yellow | 2025-12 | 6 |
| yellow | 2026-01 | 12 |
| yellow | 2026-02 | 16 |
| yellow | 2026-03 | 11 |
| yellow | 2026-04 | 28 |
| yellow | 2026-05 | 2 |
| yellow | 2026-06 | 8 |
| yellow | 2026-07 | 14 |
| yellow | 2026-08 | 38 |
| green | 2008-12 | 5 |
| green | 2009-01 | 5 |
| green | 2025-12 | 4 |
| green | 2026-01 | 8 |
| green | 2026-02 | 26 |
| green | 2026-03 | 4 |
| green | 2026-04 | 8 |
| green | 2026-05 | 14 |
| green | 2026-06 | 6 |
| green | 2026-07 | 13 |
| green | 2026-08 | 5 |

23 filas, 0.25 s

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
| yellow | RatecodeID | 1 | 20102072 |
| yellow | RatecodeID | 2 | 694936 |
| yellow | RatecodeID | 3 | 90052 |
| yellow | RatecodeID | 4 | 67285 |
| yellow | RatecodeID | 5 | 262614 |
| yellow | RatecodeID | 6 | 15 |
| yellow | RatecodeID | 99 | 769693 |
| yellow | VendorID | 1 | 5467071 |
| yellow | VendorID | 2 | 23809774 |
| yellow | VendorID | 6 | 59390 |
| yellow | VendorID | 7 | 367120 |
| yellow | payment_type | 0 | 7716688 |
| yellow | payment_type | 1 | 18941008 |
| yellow | payment_type | 2 | 2708031 |
| yellow | payment_type | 3 | 98138 |
| yellow | payment_type | 4 | 239488 |
| yellow | payment_type | 5 | 2 |
| yellow | store_and_fwd_flag | N | 21952339 |
| yellow | store_and_fwd_flag | Y | 34328 |
| green | RatecodeID | 1 | 269152 |
| green | RatecodeID | 2 | 887 |
| green | RatecodeID | 3 | 203 |
| green | RatecodeID | 4 | 354 |
| green | RatecodeID | 5 | 17739 |
| green | RatecodeID | 6 | 2 |
| green | RatecodeID | 99 | 2 |
| green | VendorID | 1 | 28696 |
| green | VendorID | 2 | 273571 |
| green | VendorID | 6 | 34847 |
| green | payment_type | 1 | 219980 |
| green | payment_type | 2 | 65921 |
| green | payment_type | 3 | 1688 |
| green | payment_type | 4 | 750 |
| green | store_and_fwd_flag | N | 287873 |
| green | store_and_fwd_flag | Y | 466 |
| green | trip_type | 1 | 273386 |
| green | trip_type | 2 | 14951 |

37 filas, 0.86 s

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
| yellow | 32794 | 32794 |

1 filas, 1.79 s
