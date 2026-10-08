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

-- 4.0 Registros que conserva el filtro base
SELECT b.tipo, b.registros AS originales, l.registros AS limpios,
       round(100.0 * l.registros / b.registros, 2) AS pct_conservado
FROM (SELECT tipo, count(*) AS registros FROM viajes GROUP BY tipo) b
JOIN (SELECT tipo, count(*) AS registros FROM viajes_limpios GROUP BY tipo) l USING (tipo)
ORDER BY b.tipo DESC;

-- 4.2 P1 Viajes e ingresos por mes
SELECT tipo, anio_archivo AS anio, mes_archivo AS mes,
       count(*) AS viajes,
       round(count(*) / max(day(last_day(pickup))), 0) AS viajes_por_dia,
       round(sum(total_amount) / 1e6, 2) AS ingresos_musd,
       round(avg(total_amount), 2) AS total_promedio
FROM viajes_limpios
GROUP BY ALL
ORDER BY tipo DESC, anio, mes;

-- 4.2 P2 Distribucion de viajes por hora del dia
SELECT hour(pickup) AS hora,
       round(100.0 * count(*) FILTER (tipo = 'yellow') / sum(count(*) FILTER (tipo = 'yellow')) OVER (), 2) AS pct_yellow,
       round(100.0 * count(*) FILTER (tipo = 'green') / sum(count(*) FILTER (tipo = 'green')) OVER (), 2) AS pct_green,
       round(median(velocidad_mph) FILTER (tipo = 'yellow'), 1) AS mph_mediana_yellow
FROM viajes_limpios
GROUP BY hora
ORDER BY hora;

-- 4.2 P3 Distribucion de viajes por dia de la semana
SELECT isodow(pickup) AS num_dia, any_value(dayname(pickup)) AS dia,
       round(100.0 * count(*) FILTER (tipo = 'yellow') / sum(count(*) FILTER (tipo = 'yellow')) OVER (), 2) AS pct_yellow,
       round(100.0 * count(*) FILTER (tipo = 'green') / sum(count(*) FILTER (tipo = 'green')) OVER (), 2) AS pct_green,
       round(avg(trip_distance) FILTER (tipo = 'yellow'), 2) AS millas_prom_yellow
FROM viajes_limpios
GROUP BY num_dia
ORDER BY num_dia;

-- 4.2 P4 Caracteristicas de los viajes por tipo
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

-- 4.2 P5 Zonas de origen mas frecuentes por tipo
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

-- 4.2 P6 Viajes de aeropuerto, tarifa y tipo de servicio
SELECT tipo,
       round(100.0 * count(*) FILTER (PULocationID IN (1, 132, 138) OR DOLocationID IN (1, 132, 138)) / count(*), 2) AS pct_aeropuerto,
       round(100.0 * count(*) FILTER (RatecodeID = 2) / count(*), 2) AS pct_tarifa_jfk,
       round(100.0 * count(*) FILTER (RatecodeID = 5) / count(*), 2) AS pct_tarifa_negociada,
       round(100.0 * count(*) FILTER (trip_type = 2) / count(*), 2) AS pct_despacho,
       round(100.0 * count(*) FILTER (cbd_congestion_fee > 0) / count(*), 2) AS pct_zona_congestion
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo DESC;

-- 4.2 P7 Formas de pago por tipo
SELECT tipo, forma_pago, count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2) AS pct,
       round(avg(total_amount), 2) AS total_promedio
FROM viajes_limpios
GROUP BY tipo, forma_pago
ORDER BY tipo DESC, viajes DESC;

-- 4.2 P8 Propinas con tarjeta
SELECT tipo,
       count(*) AS viajes_tarjeta,
       round(100.0 * count(*) FILTER (tip_amount > 0) / count(*), 1) AS pct_con_propina,
       round(median(100.0 * tip_amount / fare_amount) FILTER (fare_amount > 0), 1) AS propina_mediana_pct,
       round(avg(tip_amount), 2) AS propina_prom_usd
FROM viajes_limpios
WHERE payment_type = 1
GROUP BY tipo
ORDER BY tipo DESC;

-- 4.2 P8 Propinas en efectivo
SELECT tipo, count(*) AS viajes_efectivo,
       count(*) FILTER (tip_amount > 0) AS con_propina_registrada
FROM viajes_limpios
WHERE payment_type = 2
GROUP BY tipo
ORDER BY tipo DESC;

-- 4.2 P9 Propina segun hora del dia (yellow, tarjeta)
SELECT hour(pickup) AS hora,
       round(avg(100.0 * tip_amount / fare_amount), 2) AS propina_prom_pct,
       round(100.0 * count(*) FILTER (tip_amount > 0) / count(*), 1) AS pct_con_propina
FROM viajes_limpios
WHERE tipo = 'yellow' AND payment_type = 1 AND fare_amount > 0
GROUP BY hora
ORDER BY hora;

-- 4.2 P10 Participacion de Flex Fare por mes (yellow)
SELECT anio_archivo AS anio, mes_archivo AS mes,
       round(100.0 * count(*) FILTER (payment_type = 0) / count(*), 2) AS pct_flex_fare,
       round(avg(total_amount) FILTER (payment_type = 0), 2) AS total_prom_flex,
       round(avg(total_amount) FILTER (payment_type <> 0), 2) AS total_prom_resto
FROM viajes_limpios
WHERE tipo = 'yellow'
GROUP BY ALL
ORDER BY anio, mes;

-- 4.2 P11 Distribucion del monto total
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

-- 4.2 P11 Percentiles de distancia, duracion, tarifa y total (p01, p25, p50, p75, p99)
SELECT tipo,
       list_transform(quantile_cont(trip_distance, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 2)) AS millas,
       list_transform(quantile_cont(duracion_min, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 1)) AS minutos,
       list_transform(quantile_cont(fare_amount, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 2)) AS tarifa,
       list_transform(quantile_cont(total_amount, [0.01, 0.25, 0.5, 0.75, 0.99]), x -> round(x, 2)) AS total,
       round(max(total_amount), 2) AS total_max
FROM viajes_limpios
GROUP BY tipo
ORDER BY tipo DESC;

-- 4.2 P12 Valores atipicos por regla IQR del monto total
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

-- 4.2 P12 Inconsistencias que sobreviven al filtro base
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
