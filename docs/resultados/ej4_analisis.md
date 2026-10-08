# Resultados de ej4_analisis.sql

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

0 filas, 0.01 s

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
| yellow | 29703355 | 28204688 | 94.95 |
| green | 337114 | 323098 | 95.84 |

2 filas, 0.75 s

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
| yellow | 2026 | 1 | 3516861 | 113447 | 104.33 | 29.67 |
| yellow | 2026 | 2 | 3210632 | 114665 | 97.75 | 30.45 |
| yellow | 2026 | 3 | 3763431 | 121401 | 113.88 | 30.26 |
| yellow | 2026 | 4 | 3674849 | 122495 | 110.59 | 30.09 |
| yellow | 2026 | 5 | 3912702 | 126216 | 119.5 | 30.54 |
| yellow | 2026 | 6 | 3646975 | 121566 | 111.58 | 30.6 |
| yellow | 2026 | 7 | 3333682 | 107538 | 100.5 | 30.15 |
| yellow | 2026 | 8 | 3145556 | 101470 | 94.9 | 30.17 |
| green | 2026 | 1 | 38771 | 1251 | 0.94 | 24.26 |
| green | 2026 | 2 | 35788 | 1278 | 0.87 | 24.35 |
| green | 2026 | 3 | 42506 | 1371 | 1.06 | 24.88 |
| green | 2026 | 4 | 42370 | 1412 | 1.07 | 25.33 |
| green | 2026 | 5 | 43103 | 1390 | 1.11 | 25.78 |
| green | 2026 | 6 | 42447 | 1415 | 1.11 | 26.08 |
| green | 2026 | 7 | 39397 | 1271 | 1.03 | 26.17 |
| green | 2026 | 8 | 38716 | 1249 | 1.02 | 26.43 |

16 filas, 1.29 s

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
| 0 | 3.22 | 1.48 | 11.8 |
| 1 | 2.14 | 0.91 | 12.3 |
| 2 | 1.42 | 0.66 | 12.9 |
| 3 | 1.02 | 0.54 | 13.8 |
| 4 | 0.84 | 0.55 | 15.4 |
| 5 | 0.93 | 0.76 | 16 |
| 6 | 1.74 | 2.04 | 13.8 |
| 7 | 3.03 | 4.3 | 11.1 |
| 8 | 4.07 | 5.42 | 9.3 |
| 9 | 4.27 | 5.68 | 8.9 |
| 10 | 4.32 | 5.49 | 8.6 |
| 11 | 4.66 | 5.43 | 8.2 |
| 12 | 5.04 | 5.87 | 8.1 |
| 13 | 5.28 | 5.78 | 8.1 |
| 14 | 5.72 | 6.45 | 8 |
| 15 | 5.91 | 6.99 | 7.9 |
| 16 | 5.67 | 7.53 | 8 |
| 17 | 6.26 | 7.79 | 8 |
| 18 | 6.49 | 7.34 | 8.3 |
| 19 | 5.9 | 5.5 | 8.9 |
| 20 | 5.86 | 4.22 | 9.8 |
| 21 | 6.08 | 3.74 | 10.1 |
| 22 | 5.64 | 3.22 | 10.5 |
| 23 | 4.48 | 2.3 | 11.2 |

24 filas, 1.39 s

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
| 1 | Monday | 11.88 | 14.28 | 3.77 |
| 2 | Tuesday | 13.62 | 15.13 | 3.41 |
| 3 | Wednesday | 14.52 | 15.7 | 3.36 |
| 4 | Thursday | 15.79 | 16.54 | 3.39 |
| 5 | Friday | 14.96 | 14.99 | 3.46 |
| 6 | Saturday | 15.95 | 12 | 3.41 |
| 7 | Sunday | 13.27 | 11.36 | 3.93 |

7 filas, 0.94 s

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
| yellow | 1.1 | 1.93 | 3.95 | 14.1 | 9.3 | 1.25 | 82.3 |
| green | 1.33 | 2.14 | 3.77 | 13.3 | 10.1 | 1.3 | 82.8 |

2 filas, 3.93 s

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
| yellow | 237 | 1251254 | 4.44 |
| yellow | 161 | 1170444 | 4.15 |
| yellow | 132 | 1124952 | 3.99 |
| yellow | 236 | 1111438 | 3.94 |
| yellow | 186 | 867889 | 3.08 |
| yellow | 162 | 863648 | 3.06 |
| yellow | 230 | 816898 | 2.9 |
| yellow | 142 | 810669 | 2.87 |
| green | 74 | 87076 | 26.95 |
| green | 75 | 41923 | 12.98 |
| green | 95 | 15698 | 4.86 |
| green | 43 | 13002 | 4.02 |
| green | 166 | 12490 | 3.87 |
| green | 82 | 11178 | 3.46 |
| green | 41 | 11081 | 3.43 |
| green | 65 | 10544 | 3.26 |

16 filas, 0.75 s

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
| yellow | 8.16 | 2.34 | 0.55 | 0 | 72.39 |
| green | 3.34 | 0.2 | 3.78 | 3.21 | 8.48 |

2 filas, 1.61 s

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
| yellow | Tarjeta | 18429370 | 65.34 | 30.03 |
| yellow | Flex Fare | 7040110 | 24.96 | 32.43 |
| yellow | Efectivo | 2559284 | 9.07 | 25.98 |
| yellow | Disputa | 119038 | 0.42 | 28.59 |
| yellow | Sin cargo | 56885 | 0.2 | 24.13 |
| yellow | Desconocido | 1 | 0 | 0 |
| green | Tarjeta | 211692 | 65.52 | 25.66 |
| green | Efectivo | 62628 | 19.38 | 20.83 |
| green | Nulo | 47675 | 14.76 | 30.64 |
| green | Sin cargo | 774 | 0.24 | 16.53 |
| green | Disputa | 329 | 0.1 | 16.25 |

11 filas, 0.99 s

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
| yellow | 18441115 | 91.1 | 26.4 | 4.26 |
| green | 211692 | 91.4 | 23.5 | 3.8 |

2 filas, 2.08 s

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
| yellow | 2559285 | 172 |
| green | 62628 | 0 |

2 filas, 1.72 s

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
| 0 | 24.63 | 90.1 |
| 1 | 24.48 | 88.1 |
| 2 | 24.54 | 86.5 |
| 3 | 24.26 | 84.3 |
| 4 | 22.4 | 78.1 |
| 5 | 20.95 | 73.4 |
| 6 | 21.25 | 78.4 |
| 7 | 22.66 | 85.8 |
| 8 | 23.23 | 88.2 |
| 9 | 23.63 | 89.1 |
| 10 | 25.2 | 90.1 |
| 11 | 24.06 | 90.6 |
| 12 | 24.08 | 90.7 |
| 13 | 24.18 | 91.1 |
| 14 | 25.16 | 91.4 |
| 15 | 23.98 | 91.7 |
| 16 | 26.02 | 91.7 |
| 17 | 26.47 | 92.6 |
| 18 | 27.01 | 93.4 |
| 19 | 26.94 | 93.4 |
| 20 | 26.41 | 93.6 |
| 21 | 25.82 | 94 |
| 22 | 25.39 | 93.3 |
| 23 | 24.92 | 91.6 |

24 filas, 1.76 s

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
| 2026 | 1 | 28.3 | 31.51 | 28.94 |
| 2026 | 2 | 28.94 | 33.6 | 29.16 |
| 2026 | 3 | 22.86 | 34 | 29.15 |
| 2026 | 4 | 20.15 | 32.39 | 29.51 |
| 2026 | 5 | 22.47 | 32.55 | 29.96 |
| 2026 | 6 | 25.3 | 32.5 | 29.95 |
| 2026 | 7 | 26.34 | 31.27 | 29.74 |
| 2026 | 8 | 26.21 | 31.77 | 29.6 |

8 filas, 1.72 s

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
| yellow | 1. < 10 | 329559 | 1.17 |
| yellow | 2. 10-20 | 9908431 | 35.13 |
| yellow | 3. 20-30 | 8774524 | 31.11 |
| yellow | 4. 30-50 | 5893846 | 20.9 |
| yellow | 5. 50-80 | 1993253 | 7.07 |
| yellow | 6. 80-120 | 1177902 | 4.18 |
| yellow | 7. >= 120 | 127173 | 0.45 |
| green | 1. < 10 | 17106 | 5.29 |
| green | 2. 10-20 | 137326 | 42.5 |
| green | 3. 20-30 | 89558 | 27.72 |
| green | 4. 30-50 | 55310 | 17.12 |
| green | 5. 50-80 | 17918 | 5.55 |
| green | 6. 80-120 | 4569 | 1.41 |
| green | 7. >= 120 | 1311 | 0.41 |

14 filas, 0.83 s

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
| yellow | [0.18, 1.1, 1.93, 3.95, 19.56] | [2.1, 8.6, 14.1, 22.3, 71.3] | [4.4, 10.0, 15.6, 26.18, 79.3] | [9.81, 17.5, 23.58, 34.5, 105.0] | 1065.72 |
| green | [0.12, 1.33, 2.14, 3.77, 17.75] | [0.9, 8.7, 13.3, 20.6, 75.0] | [0.0, 8.6, 13.5, 19.8, 79.69] | [6.6, 15.12, 20.52, 29.7, 95.2] | 668.8 |

2 filas, 6.83 s

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
| yellow | 60 | 2402096 | 8.52 | 72.6 |
| green | 51.57 | 21394 | 6.62 | 15.8 |

2 filas, 1.85 s

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
| yellow | 7177 | 4734 | 38115 | 10272 | 28723 | 28204688 |
| green | 1087 | 36 | 565 | 4578 | 573 | 323098 |

2 filas, 2.42 s
