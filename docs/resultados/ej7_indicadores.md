# Resultados de ej7_indicadores.sql

## Ej. 7 Indicadores del tablero. Se ejecutan sobre el cubo de sql/ej7_cubo.sql:

```sql

```

0 filas, 0.00 s

## python scripts/run_sql.py sql/ej7_indicadores.sql --db data/processed/indicadores.duckdb

```sql

```

0 filas, 0.00 s

## scripts/crear_tablero.py usa estas mismas consultas como tarjetas de Metabase.

```sql

```

0 filas, 0.00 s

## Cada consulta lleva una sola linea de comentario con el numero y el titulo.

```sql

```

0 filas, 0.00 s

## 7.0 Viajes analizados

```sql
SELECT sum(viajes) AS viajes
FROM cubo_viajes;
```

| viajes |
|---|
| 115390500 |

1 filas, 0.00 s

## 7.1 Viajes por mes y anio

```sql
SELECT mes, anio::VARCHAR AS anio, sum(viajes) AS viajes
FROM cubo_viajes
GROUP BY ALL
ORDER BY mes, anio;
```

| mes | anio | viajes |
|---|---|---|
| 1 | 2024 | 2923540 |
| 1 | 2025 | 3368372 |
| 1 | 2026 | 3555632 |
| 2 | 2024 | 2955017 |
| 2 | 2025 | 3464370 |
| 2 | 2026 | 3246420 |
| 3 | 2024 | 3506837 |
| 3 | 2025 | 4002807 |
| 3 | 2026 | 3805937 |
| 4 | 2024 | 3479529 |
| 4 | 2025 | 3824398 |
| 4 | 2026 | 3717219 |
| 5 | 2024 | 3684719 |
| 5 | 2025 | 4335957 |
| 5 | 2026 | 3955805 |
| 6 | 2024 | 3491209 |
| 6 | 2025 | 4098098 |
| 6 | 2026 | 3689422 |
| 7 | 2024 | 3029139 |
| 7 | 2025 | 3694387 |
| 7 | 2026 | 3373079 |
| 8 | 2024 | 2919698 |
| 8 | 2025 | 3383812 |
| 8 | 2026 | 3184272 |
| 9 | 2024 | 3549757 |
| 9 | 2025 | 4043327 |
| 10 | 2024 | 3746685 |
| 10 | 2025 | 4183410 |
| 11 | 2024 | 3567975 |
| 11 | 2025 | 3937792 |
| 12 | 2024 | 3575972 |
| 12 | 2025 | 4095907 |

32 filas, 0.00 s

## 7.2 Distribucion de los viajes por hora del dia segun el tipo de taxi

```sql
SELECT hora, tipo,
       round(100.0 * sum(viajes) / sum(sum(viajes)) OVER (PARTITION BY tipo), 2) AS pct_viajes
FROM cubo_viajes
GROUP BY hora, tipo
ORDER BY hora, tipo;
```

| hora | tipo | pct_viajes |
|---|---|---|
| 0 | green | 1.64 |
| 0 | yellow | 3.09 |
| 1 | green | 1.09 |
| 1 | yellow | 2.02 |
| 2 | green | 0.77 |
| 2 | yellow | 1.33 |
| 3 | green | 0.59 |
| 3 | yellow | 0.91 |
| 4 | green | 0.53 |
| 4 | yellow | 0.71 |
| 5 | green | 0.63 |
| 5 | yellow | 0.77 |
| 6 | green | 1.74 |
| 6 | yellow | 1.57 |
| 7 | green | 3.85 |
| 7 | yellow | 2.89 |
| 8 | green | 4.97 |
| 8 | yellow | 3.93 |
| 9 | green | 5.33 |
| 9 | yellow | 4.21 |
| 10 | green | 5.27 |
| 10 | yellow | 4.4 |
| 11 | green | 5.26 |
| 11 | yellow | 4.74 |
| 12 | green | 5.59 |
| 12 | yellow | 5.16 |
| 13 | green | 5.63 |
| 13 | yellow | 5.39 |
| 14 | green | 6.37 |
| 14 | yellow | 5.79 |
| 15 | green | 6.95 |
| 15 | yellow | 6 |
| 16 | green | 7.55 |
| 16 | yellow | 5.89 |
| 17 | green | 8.08 |
| 17 | yellow | 6.49 |
| 18 | green | 7.67 |
| 18 | yellow | 6.78 |
| 19 | green | 5.98 |
| 19 | yellow | 6.09 |
| 20 | green | 4.59 |
| 20 | yellow | 5.84 |
| 21 | green | 3.99 |
| 21 | yellow | 6 |
| 22 | green | 3.36 |
| 22 | yellow | 5.6 |
| 23 | green | 2.56 |
| 23 | yellow | 4.39 |

48 filas, 0.00 s

## 7.3 Formas de pago en yellow por anio (enero a agosto)

```sql
SELECT anio::VARCHAR AS anio, forma_pago,
       round(100.0 * sum(viajes) / sum(sum(viajes)) OVER (PARTITION BY anio), 2) AS pct_viajes
FROM cubo_viajes
WHERE tipo = 'yellow' AND mes <= 8
GROUP BY anio, forma_pago
ORDER BY anio, pct_viajes DESC;
```

| anio | forma_pago | pct_viajes |
|---|---|---|
| 2024 | Tarjeta | 75.71 |
| 2024 | Efectivo | 13.75 |
| 2024 | Flex Fare | 9.25 |
| 2024 | Disputa | 0.91 |
| 2024 | Sin cargo | 0.39 |
| 2025 | Tarjeta | 66.16 |
| 2025 | Flex Fare | 22.6 |
| 2025 | Efectivo | 9.63 |
| 2025 | Disputa | 1.23 |
| 2025 | Sin cargo | 0.37 |
| 2025 | Desconocido | 0 |
| 2026 | Tarjeta | 65.38 |
| 2026 | Flex Fare | 24.93 |
| 2026 | Efectivo | 9.07 |
| 2026 | Disputa | 0.42 |
| 2026 | Sin cargo | 0.2 |
| 2026 | Desconocido | 0 |

17 filas, 0.00 s

## 7.4 Ingreso mensual en millones de USD por anio

```sql
SELECT mes, anio::VARCHAR AS anio, round(sum(total_usd) / 1e6, 2) AS millones_usd
FROM cubo_viajes
GROUP BY ALL
ORDER BY mes, anio;
```

| mes | anio | millones_usd |
|---|---|---|
| 1 | 2024 | 79.6 |
| 1 | 2025 | 88.48 |
| 1 | 2026 | 105.27 |
| 2 | 2024 | 80.11 |
| 2 | 2025 | 89.39 |
| 2 | 2026 | 98.62 |
| 3 | 2024 | 97.04 |
| 3 | 2025 | 108.57 |
| 3 | 2026 | 114.94 |
| 4 | 2024 | 97.44 |
| 4 | 2025 | 105.42 |
| 4 | 2026 | 111.66 |
| 5 | 2024 | 106.25 |
| 5 | 2025 | 121.96 |
| 5 | 2026 | 120.61 |
| 6 | 2024 | 99.59 |
| 6 | 2025 | 116.02 |
| 6 | 2026 | 112.69 |
| 7 | 2024 | 87.32 |
| 7 | 2025 | 103.29 |
| 7 | 2026 | 101.53 |
| 8 | 2024 | 84.99 |
| 8 | 2025 | 93.95 |
| 8 | 2026 | 95.93 |
| 9 | 2024 | 104.06 |
| 9 | 2025 | 116.16 |
| 10 | 2024 | 109.49 |
| 10 | 2025 | 117.88 |
| 11 | 2024 | 101.12 |
| 11 | 2025 | 105.77 |
| 12 | 2024 | 104.54 |
| 12 | 2025 | 128.27 |

32 filas, 0.00 s

## 7.5 Propina con tarjeta como porcentaje de la tarifa por hora (yellow)

```sql
SELECT hora, anio::VARCHAR AS anio,
       round(100.0 * sum(propina_usd) / sum(tarifa_usd), 2) AS propina_pct
FROM cubo_viajes
WHERE tipo = 'yellow' AND forma_pago = 'Tarjeta'
GROUP BY ALL
ORDER BY hora, anio;
```

| hora | anio | propina_pct |
|---|---|---|
| 0 | 2024 | 21.52 |
| 0 | 2025 | 21.69 |
| 0 | 2026 | 21.51 |
| 1 | 2024 | 21.52 |
| 1 | 2025 | 21.62 |
| 1 | 2026 | 21.34 |
| 2 | 2024 | 21.68 |
| 2 | 2025 | 21.68 |
| 2 | 2026 | 21.24 |
| 3 | 2024 | 21.28 |
| 3 | 2025 | 21.09 |
| 3 | 2026 | 20.42 |
| 4 | 2024 | 19.71 |
| 4 | 2025 | 18.98 |
| 4 | 2026 | 17.95 |
| 5 | 2024 | 18.6 |
| 5 | 2025 | 17.01 |
| 5 | 2026 | 15.82 |
| 6 | 2024 | 18.72 |
| 6 | 2025 | 17.43 |
| 6 | 2026 | 16.19 |
| 7 | 2024 | 20.33 |
| 7 | 2025 | 19.6 |
| 7 | 2026 | 18.66 |
| 8 | 2024 | 20.92 |
| 8 | 2025 | 20.48 |
| 8 | 2026 | 19.69 |
| 9 | 2024 | 21.37 |
| 9 | 2025 | 20.99 |
| 9 | 2026 | 20.29 |
| 10 | 2024 | 21.64 |
| 10 | 2025 | 21.25 |
| 10 | 2026 | 20.79 |
| 11 | 2024 | 21.6 |
| 11 | 2025 | 21.35 |
| 11 | 2026 | 20.93 |
| 12 | 2024 | 21.54 |
| 12 | 2025 | 21.33 |
| 12 | 2026 | 20.97 |
| 13 | 2024 | 21.61 |
| 13 | 2025 | 21.45 |
| 13 | 2026 | 21.17 |
| 14 | 2024 | 21.58 |
| 14 | 2025 | 21.4 |
| 14 | 2026 | 21.17 |
| 15 | 2024 | 21.52 |
| 15 | 2025 | 21.28 |
| 15 | 2026 | 21.03 |
| 16 | 2024 | 22.78 |
| 16 | 2025 | 22.53 |

72 filas, 0.00 s

## 7.6 Duracion promedio del viaje en minutos por mes y anio (yellow)

```sql
SELECT mes, anio::VARCHAR AS anio, round(sum(minutos) / sum(viajes), 2) AS minutos_promedio
FROM cubo_viajes
WHERE tipo = 'yellow'
GROUP BY ALL
ORDER BY mes, anio;
```

| mes | anio | minutos_promedio |
|---|---|---|
| 1 | 2024 | 14.97 |
| 1 | 2025 | 14.69 |
| 1 | 2026 | 17.14 |
| 2 | 2024 | 15.36 |
| 2 | 2025 | 15.1 |
| 2 | 2026 | 17.82 |
| 3 | 2024 | 16.11 |
| 3 | 2025 | 15.74 |
| 3 | 2026 | 17.37 |
| 4 | 2024 | 16.45 |
| 4 | 2025 | 16.4 |
| 4 | 2026 | 18.08 |
| 5 | 2024 | 17.49 |
| 5 | 2025 | 17.83 |
| 5 | 2026 | 18.83 |
| 6 | 2024 | 17.01 |
| 6 | 2025 | 17.42 |
| 6 | 2026 | 17.59 |
| 7 | 2024 | 16.65 |
| 7 | 2025 | 17.14 |
| 7 | 2026 | 17.26 |
| 8 | 2024 | 16.78 |
| 8 | 2025 | 17.25 |
| 8 | 2026 | 17.23 |
| 9 | 2024 | 18.19 |
| 9 | 2025 | 18.61 |
| 10 | 2024 | 17.81 |
| 10 | 2025 | 18.71 |
| 11 | 2024 | 17.28 |
| 11 | 2025 | 18.33 |
| 12 | 2024 | 18.18 |
| 12 | 2025 | 18.95 |

32 filas, 0.00 s

## 7.7 Viajes yellow con cargo de congestion por mes (2025 y 2026)

```sql
SELECT mes, anio::VARCHAR AS anio,
       round(100.0 * sum(viajes_con_cargo_cbd) / sum(viajes), 2) AS pct_con_cargo
FROM cubo_viajes
WHERE tipo = 'yellow' AND anio >= 2025
GROUP BY ALL
ORDER BY mes, anio;
```

| mes | anio | pct_con_cargo |
|---|---|---|
| 1 | 2025 | 65.97 |
| 1 | 2026 | 70.89 |
| 2 | 2025 | 74.08 |
| 2 | 2026 | 70.93 |
| 3 | 2025 | 74.24 |
| 3 | 2026 | 71.53 |
| 4 | 2025 | 73.94 |
| 4 | 2026 | 71.73 |
| 5 | 2025 | 73.21 |
| 5 | 2026 | 66.73 |
| 6 | 2025 | 73.73 |
| 6 | 2026 | 74.23 |
| 7 | 2025 | 74.38 |
| 7 | 2026 | 77.19 |
| 8 | 2025 | 73.79 |
| 8 | 2026 | 77.13 |
| 9 | 2025 | 74 |
| 10 | 2025 | 73.81 |
| 11 | 2025 | 73.2 |
| 12 | 2025 | 72.07 |

20 filas, 0.00 s

## 7.8 Participacion de green en el total de viajes por mes y anio

```sql
SELECT mes, anio::VARCHAR AS anio,
       round(100.0 * sum(viajes) FILTER (tipo = 'green') / sum(viajes), 2) AS pct_green
FROM cubo_viajes
GROUP BY ALL
ORDER BY mes, anio;
```

| mes | anio | pct_green |
|---|---|---|
| 1 | 2024 | 1.82 |
| 1 | 2025 | 1.34 |
| 1 | 2026 | 1.09 |
| 2 | 2024 | 1.71 |
| 2 | 2025 | 1.26 |
| 2 | 2026 | 1.1 |
| 3 | 2024 | 1.54 |
| 3 | 2025 | 1.2 |
| 3 | 2026 | 1.12 |
| 4 | 2024 | 1.52 |
| 4 | 2025 | 1.27 |
| 4 | 2026 | 1.14 |
| 5 | 2024 | 1.56 |
| 5 | 2025 | 1.2 |
| 5 | 2026 | 1.09 |
| 6 | 2024 | 1.48 |
| 6 | 2025 | 1.15 |
| 6 | 2026 | 1.15 |
| 7 | 2024 | 1.6 |
| 7 | 2025 | 1.26 |
| 7 | 2026 | 1.17 |
| 8 | 2024 | 1.67 |
| 8 | 2025 | 1.32 |
| 8 | 2026 | 1.22 |
| 9 | 2024 | 1.45 |
| 9 | 2025 | 1.17 |
| 10 | 2024 | 1.42 |
| 10 | 2025 | 1.14 |
| 11 | 2024 | 1.38 |
| 11 | 2025 | 1.15 |
| 12 | 2024 | 1.42 |
| 12 | 2025 | 1.13 |

32 filas, 0.00 s

## 7.9 Diez zonas de origen con mas viajes en yellow

```sql
SELECT 'Zona ' || zona_origen AS zona, sum(viajes) AS viajes
FROM cubo_zonas
WHERE tipo = 'yellow'
GROUP BY zona_origen
ORDER BY viajes DESC
LIMIT 10;
```

| zona | viajes |
|---|---|
| Zona 237 | 5152173 |
| Zona 161 | 5019579 |
| Zona 132 | 4874198 |
| Zona 236 | 4591224 |
| Zona 162 | 3680861 |
| Zona 186 | 3657918 |
| Zona 230 | 3588341 |
| Zona 142 | 3416219 |
| Zona 138 | 3200576 |
| Zona 170 | 3100848 |

10 filas, 0.00 s
