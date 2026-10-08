# Division del trabajo

El trabajo es secuencial: cada persona empieza cuando la anterior termina, porque cada ejercicio usa lo que deja el anterior.

| Persona | Ejercicios | Puntos aprox. | Estado |
|---|---|---|---|
| 1 | 1, 2, 3 | 30 | Terminado |
| 2 | 4, 5, 6 | 35 | Terminado |
| 3 | 7, 8, 9 y cierre | 35 | Pendiente |

## Antes de empezar

```bash
git pull
docker compose up -d --build
docker compose exec lab python scripts/download_data.py
```

- JupyterLab: http://localhost:8888
- Metabase: http://localhost:3000
- Los datos quedan en `data/raw/<tipo>/<anio>/` y no se suben a Git.
- Las consultas van en `sql/` y se ejecutan con:

```bash
docker compose exec lab python scripts/run_sql.py sql/<archivo>.sql --md docs/resultados/<archivo>.md
```

- En los `.sql`, cada consulta lleva una sola linea de comentario con el inciso y el titulo, por ejemplo `-- 4.2 Viajes por hora del dia`.
- Hacer commits frecuentes, cada quien con su usuario. El historial cuenta para la nota.

## Persona 1: Ambiente, descarga y exploracion (Ej. 1, 2, 3)

Terminado.

- Ej. 1: ambiente con Docker documentado en el README y en [ej1_ambiente.md](ej1_ambiente.md).
- Ej. 2: `scripts/download_data.py` acepta `--anios` y `--verificar`, no vuelve a descargar archivos existentes y valida cada archivo. Ver [ej2_descarga.md](ej2_descarga.md).
- Ej. 3: exploracion y calidad de datos en `sql/ej3_exploracion.sql`. Ver [ej3_exploracion.md](ej3_exploracion.md).

Lo que queda listo para los demas:

- Vista `viajes` (bloque `-- 0` de `sql/ej3_exploracion.sql`): junta yellow y green con columnas comunes (`tipo`, `pickup`, `dropoff`, `anio_archivo`, `mes_archivo`, montos, etc.). Se puede copiar al inicio de cualquier `.sql` nuevo.
- Lista de problemas de calidad y filtro base propuesto, al final de [ej3_exploracion.md](ej3_exploracion.md).
- `payment_type = 0` es "Flex Fare" (26% de yellow) y no trae pasajeros, RatecodeID ni recargos.
- Usar `total_amount` tal como viene, sin recalcularlo.

## Persona 2: Analisis, datos de 2024 y benchmark (Ej. 4, 5, 6)

### Ej. 4 Analisis exploratorio

- 4.1 Plantear preguntas sobre: comportamiento temporal, caracteristicas de los viajes, diferencias entre yellow y green, variables de pago, distribuciones y valores atipicos.
- 4.2 a 4.4 Escribir las consultas en `sql/ej4_analisis.sql`, documentarlas y explicar los resultados.
- 4.5 Presentar al menos 3 hallazgos.
- Aplicar el filtro base del Ej. 3. Como yellow tiene 88 veces mas viajes que green, comparar con porcentajes o promedios, no con totales.

### Ej. 5 Incorporar 2024

```bash
docker compose exec lab python scripts/download_data.py --anios 2024 2026
docker compose exec lab python scripts/download_data.py --anios 2024 2026 --verificar
```

- 5.2 y 5.3 Comprobar que 2026 se conserva y no se vuelve a descargar.
- 5.6 Con DuckDB, comprobar que 2024 y 2026 se pueden consultar juntos (archivos, registros y columnas por anio).
- 5.7 Volver a correr los `.sql` de los Ej. 3 y 4. Las vistas usan `data/raw/<tipo>/*/*.parquet`, asi que deberian incluir 2024 sin cambios. Revisar si hay columnas que no existen en 2024 (por ejemplo `cbd_congestion_fee`) y documentarlo.
- 5.8 y 5.9 Documentar las consultas de validacion y explicar por que el diseno permite agregar anios sin cambiar el flujo.

### Ej. 6 Parquet vs tabla DuckDB

- 6.2 Crear la tabla materializada en `data/processed/taxis.duckdb` con un script (por ejemplo `scripts/crear_tabla.py`).
- 6.3 y 6.4 Elegir de 4 a 6 consultas del Ej. 4 y ejecutarlas sobre los Parquet y sobre la tabla.
- 6.5 y 6.6 Medir los tiempos con distintos volumenes: 1 mes, 2026 completo, 2024 + 2026. Repetir cada medicion varias veces.
- 6.7 a 6.10 Poner los resultados en una tabla, guardar el script en `scripts/benchmark.py`, analizar las diferencias y explicar cuando conviene cada estrategia.
- `run_sql.py` acepta `--db data/processed/taxis.duckdb` para ejecutar un `.sql` sobre la base.

### Entregar a la Persona 3

- Datos de 2024 y 2026 descargados.
- `data/processed/taxis.duckdb` creado y el comando para regenerarlo.
- Consultas del Ej. 4 que se puedan reutilizar como indicadores.

### Estado: terminado

- Ej. 4: `sql/ej4_analisis.sql`, 12 preguntas y 5 hallazgos. Ver [ej4_analisis.md](ej4_analisis.md).
- Ej. 5: 2024 descargado; `download_data.py` ahora baja 2024 y 2026 por defecto. Ver [ej5_incorporacion.md](ej5_incorporacion.md).
- Ej. 6: `scripts/crear_tabla.py` y `scripts/benchmark.py`. Ver [ej6_benchmark.md](ej6_benchmark.md).

Lo que queda listo para la Persona 3:

- `data/processed/taxis.duckdb` (no esta en Git, se regenera con `docker compose exec lab python scripts/crear_tabla.py`). Tiene la tabla `viajes` (todos los anios descargados) y la vista `viajes_limpios` con el filtro base, mas `duracion_min`, `velocidad_mph` y `forma_pago`. Al agregar 2025 basta con volver a correr el script.
- Las consultas de `sql/ej4_analisis.sql` sirven como indicadores: en Metabase se usan las mismas consultas pero sobre `viajes_limpios`, sin el bloque `-- 0`.
- No correr `run_sql.py --db data/processed/taxis.duckdb` con los `.sql` de los Ej. 3 a 5: su bloque `-- 0` crea vistas dentro de la base. Esos archivos se corren sin `--db`.
- Cuidados para los indicadores (ver 5.7 en [ej5_incorporacion.md](ej5_incorporacion.md)):
  - agrupar o filtrar por `anio_archivo`, porque si se mezclan anios cambian los porcentajes (`cbd_congestion_fee` no existe antes de 2025);
  - comparar anios con los mismos meses, porque 2026 solo tiene enero a agosto;
  - en indicadores de ingresos agregar `total_amount < 1000`, porque hay un viaje de 335 mil USD en 2024;
  - las propinas solo se pueden medir con `payment_type = 1` (tarjeta).
- Si una consulta se queda sin memoria, usar `SET memory_limit = '4GB'` y `SET temp_directory`, y evitar `row_number()` sobre todas las columnas (ver 5.7).

## Persona 3: Tablero, datos de 2025 y cierre (Ej. 7, 8, 9)

### Ej. 7 Indicadores y tablero

- 7.1 Definir al menos 10 preguntas.
- 7.2 a 7.4 Disenar al menos 6 indicadores, cada uno con su consulta SQL en `sql/ej7_indicadores.sql` y su visualizacion en Metabase.
- Conectar Metabase a DuckDB: en Admin > Databases agregar DuckDB con la ruta `/workspace/data/processed/taxis.duckdb` en modo solo lectura (`read_only`).
- 7.5 Armar el tablero y guardar capturas en `docs/`.
- 7.6 a 7.8 Justificar cada indicador e interpretar los resultados.

### Ej. 8 Incorporar 2025

```bash
docker compose exec lab python scripts/download_data.py --anios 2024 2025 2026
docker compose exec lab python scripts/download_data.py --anios 2024 2025 2026 --verificar
```

- 8.2 Comprobar que no se vuelve a descargar nada de 2024 ni de 2026.
- 8.3 Volver a correr los `.sql` y regenerar la tabla DuckDB.
- 8.4 y 8.5 Actualizar el tablero con los tres anios y analizar como cambian los indicadores.
- 8.6 Identificar al menos 3 cambios o patrones entre 2024, 2025 y 2026.
- 8.7 Documentar las consultas.

### Ej. 9 Discusion

Responder 9.1 a 9.8 en `docs/ej9_discusion.md`, usando lo que hicimos los tres.

### Cierre

- Completar el README: levantar el ambiente, descargar los datos, ejecutar el analisis, reproducir los benchmarks y generar los resultados.
- Revisar que no haya datos en Git (`git status` no debe mostrar `.parquet` ni `.duckdb`).
- Prueba final: clonar el repo en otra carpeta y seguir el README desde cero.
