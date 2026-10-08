-- Q1 Conteo de viajes por tipo y anio
SELECT tipo, anio_archivo, count(*) AS viajes
FROM viajes
GROUP BY ALL
ORDER BY tipo, anio_archivo;

-- Q2 Viajes e ingresos por mes (P1)
SELECT tipo, anio_archivo, mes_archivo,
       count(*) AS viajes,
       round(sum(total_amount), 2) AS ingresos,
       round(avg(total_amount), 2) AS total_promedio
FROM viajes
WHERE year(pickup) = anio_archivo AND month(pickup) = mes_archivo
  AND dropoff > pickup AND trip_distance > 0 AND trip_distance <= 100 AND total_amount >= 0
GROUP BY ALL
ORDER BY tipo, anio_archivo, mes_archivo;

-- Q3 Viajes y velocidad mediana por hora del dia (P2)
SELECT tipo, hour(pickup) AS hora,
       count(*) AS viajes,
       median(trip_distance / (date_diff('second', pickup, dropoff) / 3600.0)) AS mph_mediana
FROM viajes
WHERE dropoff > pickup AND dropoff - pickup < INTERVAL 6 HOUR
  AND trip_distance > 0 AND trip_distance <= 100
GROUP BY ALL
ORDER BY tipo, hora;

-- Q4 Formas de pago por tipo (P7)
SELECT tipo, payment_type,
       count(*) AS viajes,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo), 2) AS pct,
       round(avg(total_amount), 2) AS total_promedio
FROM viajes
GROUP BY tipo, payment_type
ORDER BY tipo, viajes DESC;

-- Q5 Propinas con tarjeta (P8)
SELECT tipo,
       count(*) AS viajes_tarjeta,
       round(100.0 * count(*) FILTER (tip_amount > 0) / count(*), 1) AS pct_con_propina,
       round(median(100.0 * tip_amount / fare_amount), 1) AS propina_mediana_pct
FROM viajes
WHERE payment_type = 1 AND fare_amount > 0
GROUP BY tipo
ORDER BY tipo;

-- Q6 Zonas de origen mas frecuentes en una semana (filtro selectivo por fecha)
SELECT tipo, PULocationID, count(*) AS viajes
FROM viajes
WHERE pickup >= TIMESTAMP '2026-01-05' AND pickup < TIMESTAMP '2026-01-12'
GROUP BY ALL
ORDER BY viajes DESC
LIMIT 10;
