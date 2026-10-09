# Resultados de ej8_evolucion.sql

## 0 Vistas sobre los Parquet y filtro base

```sql
SET memory_limit = '4GB';
SET preserve_insertion_order = false;
SET temp_directory = 'data/processed/tmp';

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
SELECT DISTINCT ON (tipo, VendorID, pickup, dropoff, PULocationID, DOLocationID, total_amount)
       *,
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
  AND total_amount >= 0;
```

0 filas, 0.02 s

## 8.5 Indicadores por tipo y anio (enero a agosto)

```sql
SELECT tipo, anio_archivo AS anio,
       count(*) AS viajes,
       round(avg(trip_distance), 2) AS millas_promedio,
       round(avg(duracion_min), 1) AS minutos_promedio,
       round(avg(total_amount) FILTER (total_amount < 1000), 2) AS total_promedio_usd,
       round(100.0 * count(*) FILTER (forma_pago = 'Tarjeta') / count(*), 1) AS pct_tarjeta,
       round(100.0 * count(*) FILTER (forma_pago = 'Flex Fare') / count(*), 1) AS pct_flex_fare,
       round(100.0 * sum(tip_amount) FILTER (payment_type = 1)
             / sum(fare_amount) FILTER (payment_type = 1), 1) AS propina_pct_tarifa_tarjeta
FROM viajes_limpios
WHERE mes_archivo <= 8
GROUP BY ALL
ORDER BY tipo DESC, anio;
```

| tipo | anio | viajes | millas_promedio | minutos_promedio | total_promedio_usd | pct_tarjeta | pct_flex_fare | propina_pct_tarifa_tarjeta |
|---|---|---|---|---|---|---|---|---|
| yellow | 2024 | 25572567 | 3.42 | 16.4 | 28.25 | 75.7 | 9.3 | 22.1 |
| yellow | 2025 | 29796774 | 3.46 | 16.5 | 27.44 | 66.2 | 22.6 | 22.3 |
| yellow | 2026 | 28204688 | 3.52 | 17.7 | 30.24 | 65.4 | 24.9 | 21.6 |
| green | 2024 | 417121 | 2.92 | 14.5 | 23.78 | 67.8 | 0 | 20.6 |
| green | 2025 | 375427 | 3.11 | 15.4 | 24.82 | 69.5 | 0 | 20.4 |
| green | 2026 | 323098 | 3.35 | 17.2 | 25.43 | 65.5 | 0 | 20.9 |

6 filas, 22.53 s

## 8.5 Viajes por mes y anio, solo yellow

```sql
SELECT mes_archivo AS mes,
       count(*) FILTER (anio_archivo = 2024) AS viajes_2024,
       count(*) FILTER (anio_archivo = 2025) AS viajes_2025,
       count(*) FILTER (anio_archivo = 2026) AS viajes_2026,
       round(100.0 * (count(*) FILTER (anio_archivo = 2025)
             / nullif(count(*) FILTER (anio_archivo = 2024), 0) - 1), 1) AS var_2025_vs_2024_pct,
       round(100.0 * (count(*) FILTER (anio_archivo = 2026)
             / nullif(count(*) FILTER (anio_archivo = 2025), 0) - 1), 1) AS var_2026_vs_2025_pct
FROM viajes_limpios
WHERE tipo = 'yellow'
GROUP BY mes_archivo
ORDER BY mes;
```

| mes | viajes_2024 | viajes_2025 | viajes_2026 | var_2025_vs_2024_pct | var_2026_vs_2025_pct |
|---|---|---|---|---|---|
| 1 | 2870221 | 3323112 | 3516861 | 15.8 | 5.8 |
| 2 | 2904619 | 3420720 | 3210632 | 17.8 | -6.1 |
| 3 | 3452735 | 3954714 | 3763431 | 14.5 | -4.8 |
| 4 | 3426585 | 3775871 | 3674849 | 10.2 | -2.7 |
| 5 | 3627241 | 4284016 | 3912702 | 18.1 | -8.7 |
| 6 | 3439523 | 4051069 | 3646975 | 17.8 | -10 |
| 7 | 2980638 | 3647990 | 3333682 | 22.4 | -8.6 |
| 8 | 2871005 | 3339282 | 3145556 | 16.3 | -5.8 |
| 9 | 3498458 | 3996127 | 0 | 14.2 | -100 |
| 10 | 3693503 | 4135886 | 0 | 12 | -100 |
| 11 | 3518897 | 3892678 | 0 | 10.6 | -100 |
| 12 | 3525368 | 4049596 | 0 | 14.9 | -100 |

12 filas, 10.32 s

## 8.6 Cobro del cargo de congestion (cbd_congestion_fee) en yellow por anio

```sql
SELECT anio_archivo AS anio,
       count(*) AS viajes,
       round(100.0 * count(*) FILTER (cbd_congestion_fee > 0) / count(*), 1) AS pct_con_cargo,
       round(avg(cbd_congestion_fee) FILTER (cbd_congestion_fee > 0), 2) AS cargo_promedio_usd
FROM viajes_limpios
WHERE tipo = 'yellow' AND mes_archivo <= 8
GROUP BY anio_archivo
ORDER BY anio;
```

| anio | viajes | pct_con_cargo | cargo_promedio_usd |
|---|---|---|---|
| 2024 | 25572567 | 0 | NULL |
| 2025 | 29796774 | 73 | 0.75 |
| 2026 | 28204688 | 72.4 | 0.75 |

3 filas, 8.00 s

## 8.6 Distribucion de la forma de pago en yellow por anio

```sql
SELECT forma_pago,
       round(100.0 * count(*) FILTER (anio_archivo = 2024) / sum(count(*) FILTER (anio_archivo = 2024)) OVER (), 1) AS pct_2024,
       round(100.0 * count(*) FILTER (anio_archivo = 2025) / sum(count(*) FILTER (anio_archivo = 2025)) OVER (), 1) AS pct_2025,
       round(100.0 * count(*) FILTER (anio_archivo = 2026) / sum(count(*) FILTER (anio_archivo = 2026)) OVER (), 1) AS pct_2026
FROM viajes_limpios
WHERE tipo = 'yellow' AND mes_archivo <= 8
GROUP BY forma_pago
ORDER BY pct_2026 DESC;
```

| forma_pago | pct_2024 | pct_2025 | pct_2026 |
|---|---|---|---|
| Tarjeta | 75.7 | 66.2 | 65.4 |
| Flex Fare | 9.3 | 22.6 | 24.9 |
| Efectivo | 13.7 | 9.6 | 9.1 |
| Disputa | 0.9 | 1.2 | 0.4 |
| Sin cargo | 0.4 | 0.4 | 0.2 |
| Desconocido | 0 | 0 | 0 |

6 filas, 7.91 s

## 8.6 Participacion de green sobre el total de viajes por anio

```sql
SELECT anio_archivo AS anio,
       count(*) FILTER (tipo = 'green') AS viajes_green,
       count(*) AS viajes_total,
       round(100.0 * count(*) FILTER (tipo = 'green') / count(*), 2) AS pct_green
FROM viajes_limpios
WHERE mes_archivo <= 8
GROUP BY anio_archivo
ORDER BY anio;
```

| anio | viajes_green | viajes_total | pct_green |
|---|---|---|---|
| 2024 | 417121 | 25989688 | 1.6 |
| 2025 | 375427 | 30172201 | 1.24 |
| 2026 | 323098 | 28527786 | 1.13 |

3 filas, 5.99 s
