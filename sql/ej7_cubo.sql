-- Ej. 7 Cubo de agregados para los indicadores.
-- Lo ejecuta scripts/crear_indicadores.py. La base de origen (taxis.duckdb) se adjunta
-- como `t` en solo lectura; las tablas se crean en data/processed/indicadores.duckdb.

-- 7.0 Cubo de viajes por tipo, anio, mes, dia de la semana, hora y forma de pago
CREATE TABLE cubo_viajes AS
SELECT tipo,
       anio_archivo AS anio,
       mes_archivo AS mes,
       isodow(pickup) AS dia_semana,
       hour(pickup) AS hora,
       forma_pago,
       count(*) AS viajes,
       count(*) FILTER (total_amount < 1000) AS viajes_monto_valido,
       sum(total_amount) FILTER (total_amount < 1000) AS total_usd,
       sum(fare_amount) AS tarifa_usd,
       sum(tip_amount) AS propina_usd,
       sum(trip_distance) AS millas,
       sum(duracion_min) AS minutos,
       count(*) FILTER (cbd_congestion_fee > 0) AS viajes_con_cargo_cbd
FROM t.viajes_limpios
GROUP BY ALL;

-- 7.0 Viajes por zona de origen, tipo y anio
CREATE TABLE cubo_zonas AS
SELECT tipo,
       anio_archivo AS anio,
       PULocationID AS zona_origen,
       count(*) AS viajes
FROM t.viajes_limpios
GROUP BY ALL;
