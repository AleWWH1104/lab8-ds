-- Ej. 7 Indicadores del tablero. Se ejecutan sobre el cubo de sql/ej7_cubo.sql:
--   python scripts/run_sql.py sql/ej7_indicadores.sql --db data/processed/indicadores.duckdb
-- scripts/crear_tablero.py usa estas mismas consultas como tarjetas de Metabase.
-- Cada consulta lleva una sola linea de comentario con el numero y el titulo.

-- 7.0 Viajes analizados
SELECT sum(viajes) AS viajes
FROM cubo_viajes;

-- 7.1 Viajes por mes y anio
SELECT mes, anio::VARCHAR AS anio, sum(viajes) AS viajes
FROM cubo_viajes
GROUP BY ALL
ORDER BY mes, anio;

-- 7.2 Distribucion de los viajes por hora del dia segun el tipo de taxi
SELECT hora, tipo,
       round(100.0 * sum(viajes) / sum(sum(viajes)) OVER (PARTITION BY tipo), 2) AS pct_viajes
FROM cubo_viajes
GROUP BY hora, tipo
ORDER BY hora, tipo;

-- 7.3 Formas de pago en yellow por anio (enero a agosto)
SELECT anio::VARCHAR AS anio, forma_pago,
       round(100.0 * sum(viajes) / sum(sum(viajes)) OVER (PARTITION BY anio), 2) AS pct_viajes
FROM cubo_viajes
WHERE tipo = 'yellow' AND mes <= 8
GROUP BY anio, forma_pago
ORDER BY anio, pct_viajes DESC;

-- 7.4 Ingreso mensual en millones de USD por anio
SELECT mes, anio::VARCHAR AS anio, round(sum(total_usd) / 1e6, 2) AS millones_usd
FROM cubo_viajes
GROUP BY ALL
ORDER BY mes, anio;

-- 7.5 Propina con tarjeta como porcentaje de la tarifa por hora (yellow)
SELECT hora, anio::VARCHAR AS anio,
       round(100.0 * sum(propina_usd) / sum(tarifa_usd), 2) AS propina_pct
FROM cubo_viajes
WHERE tipo = 'yellow' AND forma_pago = 'Tarjeta'
GROUP BY ALL
ORDER BY hora, anio;

-- 7.6 Duracion promedio del viaje en minutos por mes y anio (yellow)
SELECT mes, anio::VARCHAR AS anio, round(sum(minutos) / sum(viajes), 2) AS minutos_promedio
FROM cubo_viajes
WHERE tipo = 'yellow'
GROUP BY ALL
ORDER BY mes, anio;

-- 7.7 Viajes yellow con cargo de congestion por mes (2025 y 2026)
SELECT mes, anio::VARCHAR AS anio,
       round(100.0 * sum(viajes_con_cargo_cbd) / sum(viajes), 2) AS pct_con_cargo
FROM cubo_viajes
WHERE tipo = 'yellow' AND anio >= 2025
GROUP BY ALL
ORDER BY mes, anio;

-- 7.8 Participacion de green en el total de viajes por mes y anio
SELECT mes, anio::VARCHAR AS anio,
       round(100.0 * sum(viajes) FILTER (tipo = 'green') / sum(viajes), 2) AS pct_green
FROM cubo_viajes
GROUP BY ALL
ORDER BY mes, anio;

-- 7.9 Diez zonas de origen con mas viajes en yellow
SELECT 'Zona ' || zona_origen AS zona, sum(viajes) AS viajes
FROM cubo_zonas
WHERE tipo = 'yellow'
GROUP BY zona_origen
ORDER BY viajes DESC
LIMIT 10;
