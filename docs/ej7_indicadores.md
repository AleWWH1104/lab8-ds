# Ejercicio 7 - Indicadores y tablero

Cubo de agregados: [sql/ej7_cubo.sql](../sql/ej7_cubo.sql) y [scripts/crear_indicadores.py](../scripts/crear_indicadores.py)
Consultas de los indicadores: [sql/ej7_indicadores.sql](../sql/ej7_indicadores.sql)
Tablero en Metabase: [scripts/crear_tablero.py](../scripts/crear_tablero.py)
Resultados completos: [resultados/ej7_indicadores.md](resultados/ej7_indicadores.md)

Ejecutar (con el ambiente levantado y `taxis.duckdb` creado, ver Ej. 6):

```bash
docker compose exec lab python scripts/crear_indicadores.py
docker compose exec lab python scripts/run_sql.py sql/ej7_indicadores.sql --db data/processed/indicadores.duckdb --md docs/resultados/ej7_indicadores.md
docker compose exec lab python scripts/crear_tablero.py
```

El tablero queda en <http://localhost:3000/dashboard/2> (usuario `admin@lab8.local`, clave `Lab8-duckdb-2026`, solo para el ambiente local).

## Como esta armado

Metabase no consulta `viajes_limpios` directamente. Esa vista usa `DISTINCT ON` sobre 121 millones de filas y cada consulta tarda entre 6 y 22 segundos (ver Ej. 8); un tablero lanza todas sus tarjetas a la vez dentro de una VM de 6 GB. En cambio:

1. `crear_indicadores.py` recorre `viajes_limpios` una sola vez (42 s) y guarda dos tablas de agregados en `data/processed/indicadores.duckdb`: `cubo_viajes` (46,828 filas, por tipo, anio, mes, dia de la semana, hora y forma de pago) y `cubo_zonas` (1,538 filas).
2. Cada indicador es una consulta sobre el cubo y responde en milisegundos. El archivo pesa 2.8 MiB.
3. `crear_tablero.py` lee `sql/ej7_indicadores.sql` y convierte cada consulta en una pregunta nativa de Metabase. El SQL que se documenta aqui es exactamente el SQL de las tarjetas.

Es la misma conclusion del Ej. 6: cuando la misma consulta se repite, conviene materializar. Al agregar un anio, se regenera `taxis.duckdb`, se corre `crear_indicadores.py` y el tablero se actualiza solo (las consultas no mencionan anios concretos, salvo 7.7 que filtra desde 2025 porque antes el cargo no existia).

Metabase abre `indicadores.duckdb` con `read_only = true`. Esto evita el problema de un solo escritor: el archivo se puede regenerar solo con Metabase detenido o despues de reconectar.

## 7.1 Preguntas de analisis

1. Cuantos viajes hay por mes y como cambia el volumen de un anio a otro?
2. A que horas del dia se concentran los viajes de cada tipo de taxi?
3. Que parte de los viajes ocurre en horas pico y cambia entre yellow y green?
4. Como se reparten las formas de pago y como cambia esa mezcla con los anios?
5. Cuanto dinero generan los viajes por mes y crece al ritmo de los viajes?
6. Los pasajeros dejan mas propina segun la hora del dia?
7. Se mantiene el porcentaje de propina de un anio a otro?
8. Cuanto dura en promedio un viaje y esa duracion cambia con el tiempo?
9. A cuantos viajes se les cobra el cargo de congestion desde que existe?
10. Que peso tiene green dentro del total de viajes y esta ganando o perdiendo participacion?
11. Que zonas de origen concentran la mayor parte de la demanda?
12. Cuantos viajes se estan analizando en total?

## 7.2 - 7.4 Indicadores, consultas y visualizaciones

Todas las consultas leen el cubo (`cubo_viajes` o `cubo_zonas`), que ya trae aplicado el filtro base del Ej. 3. Por eso excluyen los viajes con fechas fuera del mes, duraciones de mas de 6 horas y distancias de mas de 100 millas.

| Id | Indicador | Pregunta | Visualizacion | Fuente |
|---|---|---|---|---|
| 7.0 | Viajes analizados | 12 | Numero | `cubo_viajes` |
| 7.1 | Viajes por mes y anio | 1 | Lineas, una por anio | `cubo_viajes` |
| 7.2 | Distribucion por hora segun el tipo de taxi | 2, 3 | Lineas, una por tipo | `cubo_viajes` |
| 7.3 | Formas de pago en yellow por anio | 4 | Barras apiladas | `cubo_viajes`, enero a agosto |
| 7.4 | Ingreso mensual en millones de USD | 5 | Lineas, una por anio | `cubo_viajes` |
| 7.5 | Propina con tarjeta como % de la tarifa por hora | 6, 7 | Lineas, una por anio | `cubo_viajes`, yellow con tarjeta |
| 7.6 | Duracion promedio del viaje | 8 | Lineas, una por anio | `cubo_viajes`, yellow |
| 7.7 | Viajes con cargo de congestion | 9 | Lineas, una por anio | `cubo_viajes`, yellow desde 2025 |
| 7.8 | Participacion de green | 10 | Lineas, una por anio | `cubo_viajes` |
| 7.9 | Diez zonas de origen con mas viajes | 11 | Barras | `cubo_zonas`, yellow |

El SQL de cada uno esta en `sql/ej7_indicadores.sql` y su resultado en `resultados/ej7_indicadores.md`. Las medidas del cubo se suman y luego se dividen (por ejemplo `sum(minutos) / sum(viajes)`), de modo que los promedios son exactos y no un promedio de promedios.

## 7.5 Tablero

Las diez tarjetas estan en un solo tablero, "Taxis NYC 2024-2026", organizado en cinco filas: volumen (7.0, 7.1), patron horario e ingresos (7.2, 7.4), pagos, duracion y green (7.3, 7.6, 7.8), propinas y cargo de congestion (7.5, 7.7) y zonas (7.9). Cada tarjeta se verifico ejecutandola por la API de Metabase: las diez devuelven el numero de filas esperado y ninguna da error.

Las capturas del tablero se guardan en `docs/img/`.

## 7.6 Justificacion de los indicadores

| Id | Por que se eligio |
|---|---|
| 7.0 | Da la escala del analisis: 115 millones de viajes validos de los 121 millones registrados. |
| 7.1 | La tendencia mensual separada por anio es la forma mas directa de ver crecimiento y estacionalidad a la vez. |
| 7.2 | La demanda por hora es la base de cualquier decision de oferta. Se normaliza a porcentaje porque yellow tiene decenas de veces mas viajes que green. |
| 7.3 | La forma de pago cambio mucho entre anios (Flex Fare) y condiciona que otros indicadores son confiables. Solo enero a agosto, para comparar meses iguales. |
| 7.4 | Muestra si los ingresos siguen al volumen o se mueven distinto. |
| 7.5 | La propina es el componente variable del pago. Se mide solo con tarjeta porque en efectivo no se registra. |
| 7.6 | La duracion resume la congestion del trafico y afecta el ingreso por hora del conductor. |
| 7.7 | Es el efecto directo de la nueva politica de 2025 sobre cada viaje. |
| 7.8 | Resume en un solo numero la perdida de peso de green. |
| 7.9 | Muestra la concentracion geografica de la demanda. |

## 7.7 Documentacion de las consultas

| Id | Objetivo | Resultado clave | Decision |
|---|---|---|---|
| 7.0 | Contar viajes validos | 115,390,500 | Es el denominador de referencia. |
| 7.1 | Volumen por mes y anio | 2025 supera a 2024 en los 12 meses; 2026 supera a 2025 solo en enero | Comparar anios solo con los mismos meses. |
| 7.2 | % de viajes por hora y tipo | Pico de green a las 17 h (8.08 %) y de yellow a las 18 h (6.78 %) | Normalizar por tipo. |
| 7.3 | Mezcla de pago en yellow | Tarjeta 75.7 -> 66.2 -> 65.4 %; Flex Fare 9.3 -> 22.6 -> 24.9 % | Analizar propinas solo con `Tarjeta`. |
| 7.4 | Ingreso mensual | De enero a agosto: 732 M USD (2024), 827 M (2025), 861 M (2026) | Excluir montos de 1000 USD o mas, por el viaje de 335 mil USD de 2024. |
| 7.5 | Propina sobre tarifa por hora | Entre 17.3 % (5 h) y 23.6 % (18 h) segun la hora | Sin diferencias fuertes entre anios. |
| 7.6 | Minutos promedio por mes | Enero a agosto: 16.4 (2024), 16.5 (2025), 17.7 (2026) | Revisar si es trafico o cambio de zonas. |
| 7.7 | % con cargo de congestion | De enero a agosto: 66 % a 74 % en 2025 y 67 % a 77 % en 2026 | Empezar la serie en 2025. |
| 7.8 | % de viajes green | Baja cada anio en cada mes | Usar el porcentaje, no el total. |
| 7.9 | Top 10 de zonas | 10 de 263 zonas concentran el 35.4 % de los viajes yellow | Falta la tabla de nombres de zonas (ver limitaciones). |

## 7.8 Interpretacion y hallazgos

1. **El ingreso crece mas que los viajes.** De 2025 a 2026 (enero a agosto) los viajes bajan 5.4 % pero los ingresos suben 4.1 %: cada viaje deja mas dinero (el total promedio de yellow pasa de 27.44 a 30.24 USD, ver Ej. 8). Mirar solo el volumen daria una lectura mas pesimista que la real.
2. **Green depende de las horas pico, yellow esta mas repartido.** El 43.4 % de los viajes green ocurre entre 7 y 9 h o entre 16 y 19 h, contra 36.3 % de yellow. Yellow mantiene entre 5 % y 6.8 % de sus viajes por hora de 12 a 22 h y tiene el doble de peso de madrugada (3.09 % a las 0 h contra 1.64 % de green).
3. **La forma de pago cambio de manera visible.** Flex Fare pasa de 9.3 % a 24.9 % de los viajes yellow mientras la tarjeta y el efectivo bajan. Esto debe tenerse presente en cualquier indicador por pasajero o por propina, porque Flex Fare no trae esos datos.
4. **La propina es estable entre anios y cambia con la hora.** Ronda el 21 % de la tarifa de 0 a 3 h y de 9 a 15 h, sube a 22.5 - 23.6 % entre las 16 y las 22 h (maximo a las 18 h) y baja a 17.3 - 17.6 % a las 5 y 6 h.
5. **Los viajes duran mas en 2026.** La duracion promedio sube de 16.5 a 17.7 minutos. Los meses de 2026 van de 17.1 a 18.8 minutos, contra 15.0 a 17.5 en 2024 y 14.7 a 17.8 en 2025. Con estos datos no se puede decir por que; la distancia casi no cambia (3.46 a 3.52 millas).
6. **El cargo de congestion llega a cerca de 7 de cada 10 viajes.** Se cobra al 73 % de los viajes yellow en 2025 y al 72.4 % en 2026, con un promedio de 0.75 USD.
7. **La demanda esta concentrada.** Solo 10 de las 263 zonas de origen generan el 35.4 % de los viajes yellow.

## Limitaciones

- Las zonas se muestran como `Zona <numero>`: el repositorio no incluye la tabla oficial de zonas de la TLC (`taxi_zone_lookup`), asi que no se pueden mostrar nombres de barrios sin descargarla. Con esa tabla bastaria un `JOIN` en la consulta 7.9.
- 2026 solo llega a agosto. Los indicadores mensuales dejan sus lineas cortadas en ese mes; los que comparan totales usan enero a agosto.
- El cubo no se actualiza solo: hay que volver a correr `crear_indicadores.py` despues de regenerar `taxis.duckdb`.
