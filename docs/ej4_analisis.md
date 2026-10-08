# Ejercicio 4 - Analisis exploratorio con DuckDB

Consultas: [sql/ej4_analisis.sql](../sql/ej4_analisis.sql)
SQL y resultados completos: [resultados/ej4_analisis.md](resultados/ej4_analisis.md)

Ejecutar:

```bash
docker compose exec lab python scripts/run_sql.py sql/ej4_analisis.sql --md docs/resultados/ej4_analisis.md
```

Los resultados de este documento corresponden a los datos de **2026 (enero a agosto)**. En el Ejercicio 5 se vuelve a ejecutar el mismo archivo con 2024 incluido.

## Filtro base (bloque `-- 0`)

Se reutilizan las vistas `yellow`, `green` y `viajes` del Ejercicio 3 y se agrega la vista `viajes_limpios`, que aplica el filtro base propuesto en [ej3_exploracion.md](ej3_exploracion.md):

- pickup dentro del mes del archivo;
- `dropoff > pickup` y duracion menor a 6 horas;
- `trip_distance` mayor a 0 y menor o igual a 100 millas;
- `total_amount >= 0`;
- sin duplicados (`QUALIFY row_number() ... = 1` sobre proveedor, horarios, zonas y total).

Tambien agrega tres columnas calculadas: `duracion_min`, `velocidad_mph` y `forma_pago` (el `payment_type` traducido con el diccionario de la TLC).

Los datos originales no se modifican: el filtro vive en una vista y se aplica al consultar. Tambien se fija `memory_limit = '4GB'`, porque sin limite el proceso de Python se quedaba sin memoria en el contenedor (7.6 GB) al calcular percentiles sobre 28 millones de filas.

**4.0 Registros que conserva el filtro.** Se conserva el 94.95% de yellow (28,204,688 viajes) y el 95.84% de green (323,098 viajes). La mayor parte de lo que se descarta son viajes con distancia 0 y duracion 0.

Como yellow tiene 88 veces mas viajes que green, todas las comparaciones entre los dos tipos usan porcentajes, medianas o promedios, no totales.

## 4.1 Preguntas planteadas

Las preguntas salen de lo que se vio en el Ejercicio 3: hay dos servicios muy distintos en volumen, columnas de fecha, distancia, zonas y montos, una forma de pago nueva (Flex Fare) que ocupa una cuarta parte de yellow y bastantes valores extremos.

| # | Tema | Pregunta | Por que |
|---|---|---|---|
| P1 | Temporal | Como cambian los viajes y los ingresos de un mes a otro? | Ver si hay estacionalidad y si algun mes se sale de lo normal. |
| P2 | Temporal | A que hora del dia se concentran los viajes y como cambia la velocidad? | La fecha de pickup es la variable temporal mas fina disponible. |
| P3 | Temporal | Que dias de la semana tienen mas viajes en cada tipo? | Separar uso laboral de uso de fin de semana. |
| P4 | Caracteristicas | Que tan largos, rapidos y con cuantos pasajeros son los viajes? | Describir el viaje tipico de cada servicio. |
| P5 | Yellow vs green | De que zonas salen los viajes de cada tipo? | Los taxis verdes solo pueden recoger fuera del centro de Manhattan. |
| P6 | Yellow vs green | Que tanto pesan los aeropuertos, las tarifas especiales y la zona de congestion? | Explica diferencias de precio entre los dos tipos. |
| P7 | Pago | Como se paga en cada tipo de taxi? | `payment_type` tiene categorias nuevas (Flex Fare) y nulos en green. |
| P8 | Pago | Cuanto se deja de propina y con que forma de pago se registra? | La propina es el componente variable del total. |
| P9 | Pago | Cambia la propina segun la hora? | Combinar comportamiento temporal y pago. |
| P10 | Pago | Como evoluciona Flex Fare en el anio? | Es 25% de yellow y no esta en datos anteriores. |
| P11 | Distribuciones | Como se distribuyen el total, la tarifa, la distancia y la duracion? | Conocer el rango normal antes de buscar atipicos. |
| P12 | Atipicos | Cuantos valores atipicos e inconsistencias quedan despues del filtro base? | Medir que tan confiable es el conjunto limpio. |

## 4.2 - 4.4 Consultas y resultados

Cada consulta esta en `sql/ej4_analisis.sql` con el comentario `-- 4.2 P<n> <titulo>`. Las tablas completas estan en [resultados/ej4_analisis.md](resultados/ej4_analisis.md); aqui se resume lo importante.

### P1 Viajes e ingresos por mes

- Consulta: viajes, viajes por dia, ingresos (millones de USD) y total promedio por tipo y mes. Se usa viajes por dia para no castigar a febrero, que tiene 28 dias.
- Resultado: yellow va de 101 mil viajes diarios (agosto) a 126 mil (mayo), con unos 100 a 120 millones de USD al mes. Green va de 1,249 a 1,415 viajes diarios. Los dos tipos tienen el maximo en primavera (marzo a junio) y bajan en julio y agosto.
- El total promedio sube en los dos tipos: yellow de 29.67 USD en enero a 30.17 en agosto, y green de 24.26 a 26.43 USD (+9%).

### P2 Viajes por hora del dia

- Consulta: porcentaje de viajes de cada tipo por hora de pickup, y velocidad mediana de yellow.
- Resultado: yellow tiene el pico entre las 17 y las 18 h (6.3% y 6.5%) y conserva mucha actividad hasta las 22 h (5.6%). Green tiene un pico parecido en la tarde (7.8% a las 17 h), pero empieza mas temprano (4.3% a las 7 h contra 3.0% de yellow) y cae mucho mas rapido en la noche (3.2% a las 22 h).
- La velocidad mediana de yellow baja de 16 mph a las 5 h a 7.9 mph a las 15 h. Entre las 11 y las 18 h los taxis van a la mitad de velocidad que de madrugada.

### P3 Viajes por dia de la semana

- Consulta: porcentaje de viajes por dia de la semana y distancia promedio de yellow.
- Resultado: yellow tiene mas viajes el sabado (15.95%) y el jueves (15.79%). Green tiene su maximo el jueves (16.54%) y el minimo el domingo (11.36%). El fin de semana pesa 29% en yellow y 23% en green.
- En yellow los viajes del domingo y del lunes son los mas largos (3.93 y 3.77 millas en promedio, contra 3.36 a 3.46 entre semana).

### P4 Caracteristicas de los viajes

- Consulta: cuartiles de distancia, mediana de duracion y velocidad, pasajeros promedio.

| tipo | millas p25 | mediana | p75 | minutos mediana | mph mediana | pasajeros prom | % un pasajero |
|---|---:|---:|---:|---:|---:|---:|---:|
| yellow | 1.10 | 1.93 | 3.95 | 14.1 | 9.3 | 1.25 | 82.3 |
| green | 1.33 | 2.14 | 3.77 | 13.3 | 10.1 | 1.30 | 82.8 |

- Resultado: el viaje tipico es corto (unas 2 millas, 14 minutos) y de una sola persona en los dos tipos. Green es un poco mas rapido porque circula fuera del centro de Manhattan. Yellow tiene una cola mas larga (p75 de 3.95 millas) por los viajes al aeropuerto.

### P5 Zonas de origen

- Consulta: las 8 zonas de pickup (`PULocationID`) con mas viajes por tipo. Los nombres salen de la tabla de zonas de la TLC (`taxi_zone_lookup.csv`).
- Resultado:
  - yellow esta repartido: la zona principal (237, Upper East Side South) solo tiene 4.4%. Las demas son Midtown Center (161), JFK (132), Upper East Side North (236), Penn Station (186), Midtown East (162), Times Square (230) y Lincoln Square East (142).
  - green esta muy concentrado: East Harlem North (74) tiene 27% y East Harlem South (75) 13%. Siguen Forest Hills (95), Central Park (43), Morningside Heights (166), Elmhurst (82), Central Harlem (41) y Downtown Brooklyn (65).
- Las zonas de green coinciden con la regla de la TLC: los taxis verdes no pueden recoger en el sur de Manhattan ni en los aeropuertos.

### P6 Aeropuertos, tarifas especiales y zona de congestion

| tipo | % aeropuerto | % tarifa JFK | % tarifa negociada | % despacho | % zona congestion |
|---|---:|---:|---:|---:|---:|
| yellow | 8.16 | 2.34 | 0.55 | - | 72.39 |
| green | 3.34 | 0.20 | 3.78 | 3.21 | 8.48 |

- Aeropuerto = pickup o dropoff en Newark (1), JFK (132) o LaGuardia (138).
- Resultado: 8% de los viajes de yellow tocan un aeropuerto, contra 3% de green. El 72% de los viajes de yellow paga el cargo de la zona de congestion de Manhattan (`cbd_congestion_fee`), contra 8.5% de green. Green usa 7 veces mas la tarifa negociada (`RatecodeID = 5`), que en green va ligada a viajes por despacho: 85% de los viajes con tarifa negociada tienen `trip_type = 2`.

### P7 Formas de pago

| tipo | Tarjeta | Flex Fare | Efectivo | Nulo | Disputa | Sin cargo |
|---|---:|---:|---:|---:|---:|---:|
| yellow | 65.39% | 24.91% | 9.07% | 0% | 0.42% | 0.20% |
| green | 65.52% | 0% | 19.38% | 14.76% | 0.10% | 0.24% |

- Resultado: la tarjeta domina en los dos tipos con el mismo porcentaje (65%). En green el efectivo pesa el doble que en yellow (19% contra 9%). Flex Fare solo existe en yellow. En green, el 14.8% sin forma de pago tiene el total promedio mas alto (30.64 USD). Una consulta de control mostro que esos viajes tampoco traen `RatecodeID` ni `trip_type` y que 73% son del proveedor 6, el mismo que en yellow solo reporta viajes Flex Fare. Probablemente son el equivalente de Flex Fare en green, reportado con `payment_type` nulo en lugar de 0.

### P8 Propinas

- Consulta: solo viajes pagados con tarjeta, porque la propina en efectivo no se registra.
- Resultado:
  - con tarjeta, 91% de los viajes deja propina en los dos tipos. La mediana es 26.4% de la tarifa en yellow y 23.5% en green (4.26 y 3.80 USD en promedio).
  - en efectivo, solo 172 de 2.56 millones de viajes de yellow tienen propina registrada, y ninguno de green.
- Decision: cualquier analisis de propinas debe limitarse a pagos con tarjeta. Calcular la propina promedio sobre todos los viajes la subestima.

### P9 Propina segun la hora (yellow, tarjeta)

- Resultado: la propina y la probabilidad de dejarla son mas bajas de madrugada (5 h: 20.95% de la tarifa, 73% de los viajes con propina) y mas altas en la tarde y noche (18 h: 27.0%, 93%).

### P10 Flex Fare por mes (yellow)

- Resultado: Flex Fare paso de 28-29% en enero y febrero a 20% en abril y volvio a subir a 26% en julio y agosto. Su total promedio (31 a 34 USD) es 2 a 4 USD mas alto que el del resto de los viajes.

### P11 Distribuciones

Rango del total (USD):

| rango | yellow | green |
|---|---:|---:|
| < 10 | 1.17% | 5.29% |
| 10-20 | 35.13% | 42.50% |
| 20-30 | 31.11% | 27.72% |
| 30-50 | 20.90% | 17.12% |
| 50-80 | 7.07% | 5.55% |
| 80-120 | 4.18% | 1.41% |
| >= 120 | 0.45% | 0.41% |

Percentiles (p01, p25, p50, p75, p99):

| tipo | millas | minutos | tarifa USD | total USD |
|---|---|---|---|---|
| yellow | 0.18, 1.10, 1.93, 3.95, 19.56 | 2.1, 8.6, 14.1, 22.3, 71.3 | 4.4, 10.0, 15.6, 26.2, 79.3 | 9.8, 17.5, 23.6, 34.5, 105.0 |
| green | 0.12, 1.33, 2.14, 3.77, 17.75 | 0.9, 8.7, 13.3, 20.6, 75.0 | 0.0, 8.6, 13.5, 19.8, 79.7 | 6.6, 15.1, 20.5, 29.7, 95.2 |

- Resultado: todas las variables tienen sesgo a la derecha: la media queda por encima de la mediana y el p99 esta 4 a 10 veces por encima de la mediana. Por eso se usan medianas y percentiles para describirlas. Yellow tiene un segundo grupo de viajes entre 80 y 120 USD (4.2%) que corresponde a los aeropuertos: 86% de esos viajes tocan Newark, JFK o LaGuardia.

### P12 Atipicos e inconsistencias

Regla IQR sobre `total_amount` (atipico si supera Q3 + 1.5 * IQR):

| tipo | limite superior | atipicos | % | % de atipicos que tocan un aeropuerto |
|---|---:|---:|---:|---:|
| yellow | 60.00 | 2,402,096 | 8.52 | 72.6 |
| green | 51.57 | 21,394 | 6.62 | 15.8 |

Inconsistencias que el filtro base no elimina:

| regla | yellow | green |
|---|---:|---:|
| velocidad > 80 mph | 7,177 | 1,087 |
| tarifa > 50 USD por milla (viajes de 1 milla o mas) | 4,734 | 36 |
| menos de 1 minuto y tarifa > 50 USD | 38,115 | 565 |
| tarifa 0 con distancia > 1 milla | 10,272 | 4,578 |
| propina mayor a la tarifa | 28,723 | 573 |

- Resultado: en yellow, 73% de los "atipicos" por IQR son viajes de aeropuerto. No son errores, son otro tipo de viaje. La regla IQR sirve para marcar valores, pero no para borrarlos. Las inconsistencias reales (velocidades imposibles, viajes de segundos con tarifas altas) son menos de 0.2% de los registros.
- Decision: no se agregan estas reglas al filtro base porque afectan muy pocos registros y no cambian promedios ni medianas. Si se agregaran, conviene quitar los viajes con velocidad > 80 mph y con menos de 1 minuto y tarifa > 50 USD.

## 4.5 Hallazgos

1. **Yellow y green atienden mercados distintos, no son el mismo servicio en dos colores.** Green esta concentrado en East Harlem (40% de sus pickups salen de dos zonas), casi no va a aeropuertos (3% contra 8%) ni a la zona de congestion (8% contra 72%), tiene mas viajes entre semana y por la manana, y usa el doble de efectivo. Yellow esta repartido en Manhattan y los aeropuertos y tiene mas actividad de noche y el sabado.
2. **La congestion de la tarde reduce la velocidad a la mitad.** La velocidad mediana de yellow baja de 16 mph a las 5 h a menos de 8 mph entre las 14 y las 17 h, justo cuando hay mas viajes. Un viaje de la misma distancia tarda casi el doble a media tarde.
3. **La propina solo se puede medir con tarjeta, y ahi es alta y estable.** 91% de los viajes con tarjeta deja propina, con mediana de 23 a 26% de la tarifa. En efectivo la propina practicamente no se registra (172 de 2.5 millones). Ademas, la propina sube en la tarde y noche y es mas baja de madrugada.
4. **Flex Fare es una cuarta parte de yellow y varia en el anio.** Va de 20% en abril a 29% en febrero, con un total promedio mas alto que el resto. Cualquier analisis de pasajeros o tarifas por `RatecodeID` deja fuera esos viajes, porque no traen esas columnas.
5. **La mayoria de los "atipicos" de precio no son errores.** En yellow, 73% de los viajes que la regla IQR marca como atipicos son de aeropuerto. Las inconsistencias reales que quedan despues del filtro base son menos de 0.2%.
