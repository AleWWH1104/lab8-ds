# Resultados de ej4_analisis.sql

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

## 4.0 Registros que conserva el filtro base

```sql
SELECT b.tipo, b.registros AS originales, l.registros AS limpios,
       round(100.0 * l.registros / b.registros, 2) AS pct_conservado
FROM (SELECT tipo, count(*) AS registros FROM viajes GROUP BY tipo) b
JOIN (SELECT tipo, count(*) AS registros FROM viajes_limpios GROUP BY tipo) l USING (tipo)
ORDER BY b.tipo DESC;
```

| tipo | originales | limpios | pct_conservado |
|---|---|---|---|
| yellow | 70873075 | 68013481 | 95.97 |
| green | 997332 | 944382 | 94.69 |

2 filas, 3.79 s

## 4.2 P1 Viajes e ingresos por mes

```sql
SELECT tipo, anio_archivo AS anio, mes_archivo AS mes,
       count(*) AS viajes,
       round(count(*) / max(day(last_day(pickup))), 0) AS viajes_por_dia,
       round(sum(total_amount) / 1e6, 2) AS ingresos_musd,
       round(avg(total_amount), 2) AS total_promedio
FROM viajes_limpios
GROUP BY ALL
ORDER BY tipo DESC, anio, mes;
```

| tipo | anio | mes | viajes | viajes_por_dia | ingresos_musd | total_promedio |
|---|---|---|---|---|---|---|
| yellow | 2024 | 1 | 2870221 | 92588 | 78.41 | 27.32 |
| yellow | 2024 | 2 | 2904619 | 100159 | 78.98 | 27.19 |
| yellow | 2024 | 3 | 3452735 | 111379 | 95.81 | 27.75 |
| yellow | 2024 | 4 | 3426585 | 114220 | 96.21 | 28.08 |
| yellow | 2024 | 5 | 3627241 | 117008 | 104.85 | 28.91 |
| yellow | 2024 | 6 | 3439523 | 114651 | 98.31 | 28.58 |
| yellow | 2024 | 7 | 2980638 | 96150 | 86.13 | 28.9 |
| yellow | 2024 | 8 | 2871005 | 92613 | 83.73 | 29.16 |
| yellow | 2024 | 9 | 3498458 | 116615 | 102.7 | 29.36 |
| yellow | 2024 | 10 | 3693503 | 119145 | 108.16 | 29.28 |
| yellow | 2024 | 11 | 3518897 | 117297 | 100.28 | 28.5 |
| yellow | 2024 | 12 | 3525368 | 113722 | 103.33 | 29.31 |
| yellow | 2026 | 1 | 3516861 | 113447 | 104.33 | 29.67 |
| yellow | 2026 | 2 | 3210632 | 114665 | 97.75 | 30.45 |
| yellow | 2026 | 3 | 3763431 | 121401 | 113.88 | 30.26 |
| yellow | 2026 | 4 | 3674849 | 122495 | 110.59 | 30.09 |
| yellow | 2026 | 5 | 3912702 | 126216 | 119.5 | 30.54 |
| yellow | 2026 | 6 | 3646975 | 121566 | 111.58 | 30.6 |
| yellow | 2026 | 7 | 3333682 | 107538 | 100.5 | 30.15 |
| yellow | 2026 | 8 | 3145556 | 101470 | 94.9 | 30.17 |
| green | 2024 | 1 | 53319 | 1720 | 1.18 | 22.19 |
| green | 2024 | 2 | 50398 | 1738 | 1.13 | 22.48 |
| green | 2024 | 3 | 54102 | 1745 | 1.23 | 22.76 |
| green | 2024 | 4 | 52944 | 1765 | 1.23 | 23.29 |
| green | 2024 | 5 | 57478 | 1854 | 1.41 | 24.5 |
| green | 2024 | 6 | 51686 | 1723 | 1.28 | 24.79 |
| green | 2024 | 7 | 48501 | 1565 | 1.19 | 24.49 |
| green | 2024 | 8 | 48693 | 1571 | 1.26 | 25.9 |
| green | 2024 | 9 | 51299 | 1710 | 1.36 | 26.54 |
| green | 2024 | 10 | 53182 | 1716 | 1.33 | 25 |
| green | 2024 | 11 | 49078 | 1636 | 1.18 | 24 |
| green | 2024 | 12 | 50604 | 1632 | 1.21 | 23.82 |
| green | 2026 | 1 | 38771 | 1251 | 0.94 | 24.26 |
| green | 2026 | 2 | 35788 | 1278 | 0.87 | 24.35 |
| green | 2026 | 3 | 42506 | 1371 | 1.06 | 24.88 |
| green | 2026 | 4 | 42370 | 1412 | 1.07 | 25.33 |
| green | 2026 | 5 | 43103 | 1390 | 1.11 | 25.78 |
| green | 2026 | 6 | 42447 | 1415 | 1.11 | 26.08 |
| green | 2026 | 7 | 39397 | 1271 | 1.03 | 26.17 |
| green | 2026 | 8 | 38716 | 1249 | 1.02 | 26.43 |

40 filas, 7.34 s

## 4.2 P2 Distribucion de viajes por hora del dia

```sql
SELECT hour(pickup) AS hora,
       round(100.0 * count(*) FILTER (tipo = 'yellow') / sum(count(*) FILTER (tipo = 'yellow')) OVER (), 2) AS pct_yellow,
       round(100.0 * count(*) FILTER (tipo = 'green') / sum(count(*) FILTER (tipo = 'green')) OVER (), 2) AS pct_green,
       round(median(velocidad_mph) FILTER (tipo = 'yellow'), 1) AS mph_mediana_yellow
FROM viajes_limpios
GROUP BY hora
ORDER BY hora;
```

| hora | pct_yellow | pct_green | mph_mediana_yellow |
|---|---|---|---|
| 0 | 3.02 | 1.69 | 11.8 |
| 1 | 1.98 | 1.12 | 12.2 |
| 2 | 1.3 | 0.8 | 12.7 |
| 3 | 0.88 | 0.62 | 13.7 |
| 4 | 0.68 | 0.54 | 15.4 |
| 5 | 0.75 | 0.61 | 16.2 |
| 6 | 1.55 | 1.69 | 13.9 |
| 7 | 2.88 | 3.82 | 11.1 |
| 8 | 3.93 | 4.89 | 9.3 |
| 9 | 4.22 | 5.32 | 8.9 |
| 10 | 4.41 | 5.24 | 8.7 |
| 11 | 4.78 | 5.24 | 8.2 |
| 12 | 5.2 | 5.55 | 8.1 |
| 13 | 5.42 | 5.58 | 8.2 |
| 14 | 5.84 | 6.4 | 8.1 |
| 15 | 6.04 | 6.98 | 7.9 |
| 16 | 5.97 | 7.55 | 8.1 |
| 17 | 6.56 | 8.09 | 8.1 |
| 18 | 6.85 | 7.71 | 8.4 |
| 19 | 6.12 | 6 | 9.1 |
| 20 | 5.8 | 4.6 | 9.8 |
| 21 | 5.96 | 4.03 | 10.2 |
| 22 | 5.52 | 3.37 | 10.6 |
| 23 | 4.32 | 2.57 | 11.3 |

24 filas, 9.28 s

## 4.2 P3 Distribucion de viajes por dia de la semana

```sql
SELECT isodow(pickup) AS num_dia, any_value(dayname(pickup)) AS dia,
       round(100.0 * count(*) FILTER (tipo = 'yellow') / sum(count(*) FILTER (tipo = 'yellow')) OVER (), 2) AS pct_yellow,
       round(100.0 * count(*) FILTER (tipo = 'green') / sum(count(*) FILTER (tipo = 'green')) OVER (), 2) AS pct_green,
       round(avg(trip_distance) FILTER (tipo = 'yellow'), 2) AS millas_prom_yellow
FROM viajes_limpios
GROUP BY num_dia
ORDER BY num_dia;
```

| num_dia | dia | pct_yellow | pct_green | millas_prom_yellow |
|---|---|---|---|---|
| 1 | Monday | 12.19 | 14.24 | 3.76 |
| 2 | Tuesday | 14.05 | 15.04 | 3.35 |
| 3 | Wednesday | 14.73 | 15.53 | 3.3 |
| 4 | Thursday | 15.69 | 16.13 | 3.35 |
| 5 | Friday | 14.85 | 15.08 | 3.4 |
| 6 | Saturday | 15.48 | 12.54 | 3.29 |
| 7 | Sunday | 12.99 | 11.46 | 3.88 |

7 filas, 6.18 s

## 4.2 P4 Caracteristicas de los viajes por tipo

```sql
SELECT tipo,
       round(quantile_cont(trip_distance, 0.25), 2) AS millas_p25,
       round(median(trip_distance), 2) AS millas_mediana,
       round(quantile_cont(trip_distance, 0.75), 2) AS millas_p75,
       round(median(duracion_min), 1) AS minutos_mediana,
       round(median(velocidad_mph), 1) AS mph_mediana,
       round(avg(passenger_count), 2) AS pasajeros_prom,
       round(100.0 * count(*) FILTER (passenger_count = 1) / count(passenger_count), 1) AS pct_un_pasajero
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | millas_p25 | millas_mediana | millas_p75 | minutos_mediana | mph_mediana | pasajeros_prom | pct_un_pasajero |
|---|---|---|---|---|---|---|---|
| yellow | 1.08 | 1.85 | 3.62 | 13.5 | 9.3 | 1.3 | 79.1 |
| green | 1.28 | 2.02 | 3.54 | 12.4 | 10.2 | 1.32 | 82.9 |

2 filas, 22.74 s

## 4.2 P5 Zonas de origen mas frecuentes por tipo

```sql
SELECT tipo, PULocationID AS zona, viajes, pct
FROM (
    SELECT tipo, PULocationID, count(*) AS viajes,
           round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2) AS pct,
           row_number() OVER (PARTITION BY tipo ORDER BY count(*) DESC) AS rk
    FROM viajes_limpios
    GROUP BY tipo, PULocationID
)
WHERE rk <= 8
ORDER BY tipo DESC, rk;
```

| tipo | zona | viajes | pct |
|---|---|---|---|
| yellow | 237 | 3126048 | 4.6 |
| yellow | 161 | 3035505 | 4.46 |
| yellow | 132 | 2995003 | 4.4 |
| yellow | 236 | 2806968 | 4.13 |
| yellow | 162 | 2247043 | 3.3 |
| yellow | 186 | 2193112 | 3.22 |
| yellow | 230 | 2157630 | 3.17 |
| yellow | 142 | 2095055 | 3.08 |
| green | 74 | 234116 | 24.79 |
| green | 75 | 130907 | 13.86 |
| green | 95 | 46867 | 4.96 |
| green | 166 | 45189 | 4.79 |
| green | 43 | 45058 | 4.77 |
| green | 82 | 40513 | 4.29 |
| green | 41 | 39111 | 4.14 |
| green | 97 | 29494 | 3.12 |

16 filas, 4.48 s

## 4.2 P6 Viajes de aeropuerto, tarifa y tipo de servicio

```sql
SELECT tipo,
       round(100.0 * count(*) FILTER (PULocationID IN (1, 132, 138) OR DOLocationID IN (1, 132, 138)) / count(*), 2) AS pct_aeropuerto,
       round(100.0 * count(*) FILTER (RatecodeID = 2) / count(*), 2) AS pct_tarifa_jfk,
       round(100.0 * count(*) FILTER (RatecodeID = 5) / count(*), 2) AS pct_tarifa_negociada,
       round(100.0 * count(*) FILTER (trip_type = 2) / count(*), 2) AS pct_despacho,
       round(100.0 * count(*) FILTER (cbd_congestion_fee > 0) / count(*), 2) AS pct_zona_congestion
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | pct_aeropuerto | pct_tarifa_jfk | pct_tarifa_negociada | pct_despacho | pct_zona_congestion |
|---|---|---|---|---|---|
| yellow | 9.29 | 2.93 | 0.47 | 0 | 30.02 |
| green | 3.9 | 0.22 | 3.55 | 3.19 | 2.9 |

2 filas, 12.50 s

## 4.2 P7 Formas de pago por tipo

```sql
SELECT tipo, forma_pago, count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2) AS pct,
       round(avg(total_amount), 2) AS total_promedio
FROM viajes_limpios
GROUP BY tipo, forma_pago
ORDER BY tipo DESC, viajes DESC;
```

| tipo | forma_pago | viajes | pct | total_promedio |
|---|---|---|---|---|
| yellow | Tarjeta | 48616619 | 71.48 | 29.84 |
| yellow | Flex Fare | 10838259 | 15.94 | 29.69 |
| yellow | Efectivo | 7838375 | 11.52 | 25.24 |
| yellow | Disputa | 506297 | 0.74 | 27.96 |
| yellow | Sin cargo | 213930 | 0.31 | 26.2 |
| yellow | Desconocido | 1 | 0 | 0 |
| green | Tarjeta | 638687 | 67.63 | 25.29 |
| green | Efectivo | 230654 | 24.42 | 20.76 |
| green | Nulo | 71130 | 7.53 | 31.08 |
| green | Sin cargo | 2862 | 0.3 | 15.19 |
| green | Disputa | 1027 | 0.11 | 14.81 |
| green | Desconocido | 22 | 0 | 18.51 |

12 filas, 6.82 s

## 4.2 P8 Propinas con tarjeta

```sql
SELECT tipo,
       count(*) AS viajes_tarjeta,
       round(100.0 * count(*) FILTER (tip_amount > 0) / count(*), 1) AS pct_con_propina,
       round(median(100.0 * tip_amount / fare_amount) FILTER (fare_amount > 0), 1) AS propina_mediana_pct,
       round(avg(tip_amount), 2) AS propina_prom_usd
FROM viajes_limpios
WHERE payment_type = 1
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | viajes_tarjeta | pct_con_propina | propina_mediana_pct | propina_prom_usd |
|---|---|---|---|---|
| yellow | 48626883 | 93.2 | 26 | 4.32 |
| green | 638687 | 91.3 | 23.5 | 3.7 |

2 filas, 7.44 s

## 4.2 P8 Propinas en efectivo

```sql
SELECT tipo, count(*) AS viajes_efectivo,
       count(*) FILTER (tip_amount > 0) AS con_propina_registrada
FROM viajes_limpios
WHERE payment_type = 2
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | viajes_efectivo | con_propina_registrada |
|---|---|---|
| yellow | 7838378 | 442 |
| green | 230654 | 2 |

2 filas, 1.43 s

## 4.2 P9 Propina segun hora del dia (yellow, tarjeta)

```sql
SELECT hour(pickup) AS hora,
       round(avg(100.0 * tip_amount / fare_amount), 2) AS propina_prom_pct,
       round(100.0 * count(*) FILTER (tip_amount > 0) / count(*), 1) AS pct_con_propina
FROM viajes_limpios
WHERE tipo = 'yellow' AND payment_type = 1 AND fare_amount > 0
GROUP BY hora
ORDER BY hora;
```

| hora | propina_prom_pct | pct_con_propina |
|---|---|---|
| 0 | 24.76 | 92.1 |
| 1 | 24.48 | 90.5 |
| 2 | 25.05 | 89 |
| 3 | 25.55 | 87.5 |
| 4 | 30.89 | 82.8 |
| 5 | 22.23 | 79.7 |
| 6 | 21.88 | 84 |
| 7 | 23.54 | 89.7 |
| 8 | 24.18 | 91.4 |
| 9 | 23.96 | 91.8 |
| 10 | 24.54 | 92.4 |
| 11 | 24.46 | 92.6 |
| 12 | 24.07 | 92.7 |
| 13 | 24.07 | 93 |
| 14 | 24.48 | 93.3 |
| 15 | 23.92 | 93.5 |
| 16 | 25.9 | 93.6 |
| 17 | 26.37 | 94.3 |
| 18 | 27.02 | 94.9 |
| 19 | 27.32 | 94.8 |
| 20 | 25.86 | 95 |
| 21 | 25.59 | 95.3 |
| 22 | 25.3 | 94.8 |
| 23 | 24.72 | 93.4 |

24 filas, 5.07 s

## 4.2 P10 Participacion de Flex Fare por mes (yellow)

```sql
SELECT anio_archivo AS anio, mes_archivo AS mes,
       round(100.0 * count(*) FILTER (payment_type = 0) / count(*), 2) AS pct_flex_fare,
       round(avg(total_amount) FILTER (payment_type = 0), 2) AS total_prom_flex,
       round(avg(total_amount) FILTER (payment_type <> 0), 2) AS total_prom_resto
FROM viajes_limpios
WHERE tipo = 'yellow'
GROUP BY ALL
ORDER BY anio, mes;
```

| anio | mes | pct_flex_fare | total_prom_flex | total_prom_resto |
|---|---|---|---|---|
| 2024 | 1 | 4.09 | 26.09 | 27.37 |
| 2024 | 2 | 5.29 | 24.52 | 27.34 |
| 2024 | 3 | 10.99 | 23.36 | 28.29 |
| 2024 | 4 | 11.75 | 23.62 | 28.67 |
| 2024 | 5 | 10.98 | 25.66 | 29.31 |
| 2024 | 6 | 11.64 | 25.09 | 29.04 |
| 2024 | 7 | 9.1 | 23.96 | 29.39 |
| 2024 | 8 | 8.49 | 24.4 | 29.61 |
| 2024 | 9 | 12.76 | 23.95 | 30.15 |
| 2024 | 10 | 9.7 | 23.89 | 29.86 |
| 2024 | 11 | 9.84 | 24.71 | 28.91 |
| 2024 | 12 | 8.43 | 27.53 | 29.48 |
| 2026 | 1 | 28.3 | 31.51 | 28.94 |
| 2026 | 2 | 28.94 | 33.6 | 29.16 |
| 2026 | 3 | 22.86 | 34 | 29.15 |
| 2026 | 4 | 20.15 | 32.39 | 29.51 |
| 2026 | 5 | 22.47 | 32.55 | 29.96 |
| 2026 | 6 | 25.3 | 32.5 | 29.95 |
| 2026 | 7 | 26.09 | 31.32 | 29.73 |
| 2026 | 8 | 26.42 | 31.73 | 29.61 |

20 filas, 9.99 s

## 4.2 P11 Distribucion del monto total

```sql
SELECT tipo,
       CASE WHEN total_amount < 10 THEN '1. < 10'
            WHEN total_amount < 20 THEN '2. 10-20'
            WHEN total_amount < 30 THEN '3. 20-30'
            WHEN total_amount < 50 THEN '4. 30-50'
            WHEN total_amount < 80 THEN '5. 50-80'
            WHEN total_amount < 120 THEN '6. 80-120'
            ELSE '7. >= 120' END AS rango_usd,
       count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2) AS pct
FROM viajes_limpios
GROUP BY tipo, rango_usd
ORDER BY tipo DESC, rango_usd;
```

| tipo | rango_usd | viajes | pct |
|---|---|---|---|
| yellow | 1. < 10 | 1192708 | 1.75 |
| yellow | 2. 10-20 | 26866151 | 39.5 |
| yellow | 3. 20-30 | 20363306 | 29.94 |
| yellow | 4. 30-50 | 11722828 | 17.24 |
| yellow | 5. 50-80 | 4375988 | 6.43 |
| yellow | 6. 80-120 | 3179961 | 4.68 |
| yellow | 7. >= 120 | 312539 | 0.46 |
| green | 1. < 10 | 61203 | 6.48 |
| green | 2. 10-20 | 420234 | 44.5 |
| green | 3. 20-30 | 249461 | 26.42 |
| green | 4. 30-50 | 148686 | 15.74 |
| green | 5. 50-80 | 47485 | 5.03 |
| green | 6. 80-120 | 13691 | 1.45 |
| green | 7. >= 120 | 3622 | 0.38 |

14 filas, 4.89 s

## 4.2 P11 Percentiles de distancia, duracion, tarifa y total (p01, p25, p50, p75, p99)

```sql
SELECT tipo,
       list_transform(quantile_cont(trip_distance, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 2)) AS millas,
       list_transform(quantile_cont(duracion_min, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 1)) AS minutos,
       list_transform(quantile_cont(fare_amount, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 2)) AS tarifa,
       list_transform(quantile_cont(total_amount, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 2)) AS total,
       round(max(total_amount), 2) AS total_max
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | millas | minutos | tarifa | total | total_max |
|---|---|---|---|---|---|
| yellow | [0.24, 1.08, 1.85, 3.62, 19.88] | [2.1, 8.2, 13.5, 21.7, 70.6] | [4.4, 9.58, 14.9, 24.0, 77.9] | [9.1, 16.51, 22.15, 32.34, 104.88] | 335550.94 |
| green | [0.12, 1.28, 2.02, 3.54, 17.03] | [0.9, 8.1, 12.4, 18.9, 65.2] | [3.0, 9.3, 13.5, 20.0, 80.0] | [6.6, 14.28, 19.68, 28.6, 94.75] | 800 |

2 filas, 25.68 s

## 4.2 P12 Valores atipicos por regla IQR del monto total

```sql
WITH lim AS (
    SELECT tipo,
           quantile_cont(total_amount, 0.25) AS q1,
           quantile_cont(total_amount, 0.75) AS q3
    FROM viajes_limpios
    GROUP BY tipo
)
SELECT v.tipo,
       round(l.q3 + 1.5 * (l.q3 - l.q1), 2) AS limite_superior,
       count(*) FILTER (v.total_amount > l.q3 + 1.5 * (l.q3 - l.q1)) AS atipicos,
       round(100.0 * count(*) FILTER (v.total_amount > l.q3 + 1.5 * (l.q3 - l.q1)) / count(*), 2) AS pct_atipicos,
       round(100.0 * count(*) FILTER (v.total_amount > l.q3 + 1.5 * (l.q3 - l.q1)
             AND (v.PULocationID IN (1, 132, 138) OR v.DOLocationID IN (1, 132, 138))) /
             nullif(count(*) FILTER (v.total_amount > l.q3 + 1.5 * (l.q3 - l.q1)), 0), 1) AS pct_atipicos_aeropuerto
FROM viajes_limpios v JOIN lim l USING (tipo)
GROUP BY v.tipo, l.q1, l.q3
ORDER BY v.tipo DESC;
```

| tipo | limite_superior | atipicos | pct_atipicos | pct_atipicos_aeropuerto |
|---|---|---|---|---|
| yellow | 56.09 | 6737776 | 9.91 | 76.8 |
| green | 50.08 | 64334 | 6.81 | 19.1 |

2 filas, 5.90 s

## 4.2 P12 Inconsistencias que sobreviven al filtro base

```sql
SELECT tipo,
       count(*) FILTER (velocidad_mph > 80) AS "velocidad > 80 mph",
       count(*) FILTER (fare_amount / trip_distance > 50 AND trip_distance >= 1) AS "tarifa > 50 USD por milla",
       count(*) FILTER (duracion_min < 1 AND fare_amount > 50) AS "menos de 1 min y tarifa > 50",
       count(*) FILTER (fare_amount = 0 AND trip_distance > 1) AS "tarifa 0 con distancia > 1",
       count(*) FILTER (tip_amount > fare_amount AND fare_amount > 0) AS "propina mayor a la tarifa",
       count(*) AS total
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo DESC;
```

| tipo | velocidad > 80 mph | tarifa > 50 USD por milla | menos de 1 min y tarifa > 50 | tarifa 0 con distancia > 1 | propina mayor a la tarifa | total |
|---|---|---|---|---|---|---|
| yellow | 19175 | 8291 | 81747 | 15816 | 70093 | 68013481 |
| green | 2997 | 114 | 1365 | 4691 | 1447 | 944382 |

2 filas, 19.66 s
