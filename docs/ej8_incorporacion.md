# Ejercicio 8 - Incorporacion de los datos de 2025

Script de descarga: [`scripts/download_data.py`](../scripts/download_data.py)
Consultas de evolucion: [sql/ej8_evolucion.sql](../sql/ej8_evolucion.sql)
SQL y resultados completos: [resultados/ej8_evolucion.md](resultados/ej8_evolucion.md)

Los `.sql` de los Ej. 3 a 5 se volvieron a ejecutar con los tres anios:
[ej3](resultados/ej3_exploracion_2024_2025_2026.md),
[ej4](resultados/ej4_analisis_2024_2025_2026.md),
[ej5](resultados/ej5_validacion_2024_2025_2026.md).

Ejecutar:

```bash
docker compose exec lab python scripts/download_data.py
docker compose exec lab python scripts/download_data.py --verificar
docker compose exec lab python scripts/crear_tabla.py
docker compose exec lab python scripts/run_sql.py sql/ej8_evolucion.sql --md docs/resultados/ej8_evolucion.md
```

## 8.1 Cambios al sistema de descarga

Igual que con 2024, el script ya recibia los anios como parametro, asi que no hubo que cambiar la logica. El unico cambio en el codigo fue el valor por defecto:

```python
ANIOS_POR_DEFECTO = (2024, 2025, 2026)   # antes (2024, 2026)
```

Ejecutar el script sin argumentos reproduce el conjunto completo del laboratorio. Tambien se actualizaron el docstring del script y la tabla de opciones del README.

## 8.2 Los archivos previos no se descargan de nuevo

Este ambiente se levanto desde cero (`data/raw/` vacio), asi que la primera corrida bajo los tres anios. La prueba de que no se repite nada es la segunda corrida (2026-10-08):

| Corrida | descargados | ya existian | no publicados | fallidos |
|---|---:|---:|---:|---:|
| 1. `download_data.py` | 64 | 0 | 8 | 0 |
| 2. `download_data.py` | 0 | 64 | 8 | 0 |
| `--verificar` | - | 64 completos | 8 | 0 faltantes |

Los 8 no publicados son yellow y green de 2026-09 a 2026-12. Archivos por tipo y anio:

| tipo | 2024 | 2025 | 2026 |
|---|---:|---:|---:|
| yellow | 12 (667 MB) | 12 (870 MB) | 8 (505 MB) |
| green | 12 (15 MB) | 12 (14 MB) | 8 (7.9 MB) |

El conteo de registros segun los metadatos de cada Parquet coincide con el conteo leyendo los datos en los seis grupos (ver `ej5_validacion_2024_2025_2026.md`). En total hay **121,184,384 registros**.

## 8.3 Las consultas siguen funcionando

Se ejecutaron `sql/ej3_exploracion.sql`, `sql/ej4_analisis.sql` y `sql/ej5_validacion.sql` sin cambiar ni una linea. Las vistas leen `data/raw/<tipo>/*/*.parquet`, asi que 2025 se incluye solo.

| Revision | Resultado |
|---|---|
| Columnas con tipo distinto entre anios | 0 |
| Columnas que no estan en todos los archivos | `cbd_congestion_fee` (desde 2025-01) y `request_source` (desde 2026-06) |
| Registros que conserva el filtro base | entre 94.1 % y 96.7 % en los seis grupos |
| Proveedores nuevos | green incorpora el `VendorID` 6 en 2025 |

`union_by_name = true` rellena con NULL las columnas que no existen en los archivos viejos, por eso nada se rompe al sumar un anio.

## 8.4 Tablero

El tablero del Ej. 7 se construyo despues de incorporar 2025, asi que ya muestra los tres anios: el cubo (`cubo_viajes`) contiene 2024, 2025 y 2026 y cada indicador separa una linea por anio. Ver [ej7_indicadores.md](ej7_indicadores.md) y la captura [img/tablero.png](img/tablero.png). Al agregar otro anio basta con regenerar `taxis.duckdb`, correr `scripts/crear_indicadores.py` y recargar el tablero.

## 8.5 Evolucion de los indicadores

Se comparan solo enero a agosto, porque 2026 no tiene mas meses publicados. Si se mezclan meses distintos, 2026 parece caer 100 % en septiembre a diciembre, y eso no es real.

| tipo | anio | viajes | millas | minutos | total USD | % tarjeta | % Flex Fare | propina % (tarjeta) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| yellow | 2024 | 25,572,567 | 3.42 | 16.4 | 28.25 | 75.7 | 9.3 | 22.1 |
| yellow | 2025 | 29,796,774 | 3.46 | 16.5 | 27.44 | 66.2 | 22.6 | 22.3 |
| yellow | 2026 | 28,204,688 | 3.52 | 17.7 | 30.24 | 65.4 | 24.9 | 21.6 |
| green | 2024 | 417,121 | 2.92 | 14.5 | 23.78 | 67.8 | 0 | 20.6 |
| green | 2025 | 375,427 | 3.11 | 15.4 | 24.82 | 69.5 | 0 | 20.4 |
| green | 2026 | 323,098 | 3.35 | 17.2 | 25.43 | 65.5 | 0 | 20.9 |

- Los viajes yellow suben 16.5 % de 2024 a 2025 y bajan 5.3 % de 2025 a 2026.
- La duracion promedio sube en ambos tipos, sobre todo en 2026, mientras la distancia casi no cambia.
- El porcentaje de propina sobre la tarifa se mantiene alrededor de 20 a 22 %.

## 8.6 Cambios y patrones entre 2024, 2025 y 2026

1. **Los viajes yellow crecen en 2025 y retroceden en 2026.** 2025 supera a 2024 en todos los meses (entre +10 % y +22 %). 2026 solo supera a 2025 en enero (+5.8 %) y queda entre 2.7 % y 10 % por debajo el resto de los meses comparables. Esta consulta no explica la causa, solo muestra el patron.
2. **El cargo de congestion aparece en 2025.** En 2024 ningun viaje lo tiene. En 2025 lo cobra el 73.0 % de los viajes yellow y en 2026 el 72.4 %, con un promedio de 0.75 USD en ambos anios. Coincide con el inicio del cobro en la zona de Manhattan en enero de 2025.
3. **Flex Fare pasa de 9.3 % a 24.9 % de los viajes yellow.** La tarjeta baja de 75.7 % a 65.4 % y el efectivo de 13.7 % a 9.1 %. Estos viajes no traen pasajeros, RatecodeID ni recargos (ver Ej. 3), asi que ese crecimiento afecta cualquier indicador que dependa de esos campos. No se puede afirmar con estos datos si es un cambio de comportamiento de los pasajeros o de como se registra el pago.
4. **Green pierde participacion cada anio.** Pasa de 1.60 % del total de viajes en 2024 a 1.24 % en 2025 y 1.13 % en 2026. Sus viajes bajan 10.0 % en 2025 y 13.9 % en 2026.
5. **Los viajes duran mas en 2026.** En yellow sube de 16.5 a 17.7 minutos, y en green de 15.4 a 17.2, sin que la distancia cambie en la misma proporcion.

## 8.7 Documentacion de las consultas

Todas estan en `sql/ej8_evolucion.sql`; el bloque `-- 0` es el mismo de los Ej. 4 y 5. Todas usan `viajes_limpios` (filtro base del Ej. 3), asi que excluyen los viajes con fechas fuera del mes del archivo, duraciones de mas de 6 horas y distancias de mas de 100 millas.

| Consulta | Objetivo | Fuente |
|---|---|---|
| 8.5 Indicadores por tipo y anio | Comparar volumen, distancia, duracion, monto y forma de pago de enero a agosto | `viajes_limpios`, `mes_archivo <= 8` |
| 8.5 Viajes por mes y anio | Ver la variacion mensual de yellow entre anios | `viajes_limpios`, `tipo = 'yellow'` |
| 8.6 Cargo de congestion | Medir desde cuando y a cuantos viajes se les cobra | `viajes_limpios`, `cbd_congestion_fee` |
| 8.6 Forma de pago | Ver como cambia la mezcla de pagos | `viajes_limpios`, `forma_pago` |
| 8.6 Participacion de green | Ver si green gana o pierde peso | `viajes_limpios` |

Decisiones tomadas a partir de los resultados:

- Todas las comparaciones entre anios usan los mismos meses (enero a agosto).
- El monto promedio excluye `total_amount >= 1000`, por el viaje de 335 mil USD de 2024 documentado en el Ej. 5.
- La propina solo se mide con `payment_type = 1`, porque con otras formas de pago no se registra.
