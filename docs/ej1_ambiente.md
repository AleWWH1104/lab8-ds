# Ejercicio 1 - Preparacion del ambiente

## Estructura del proyecto

| Directorio / archivo   | Proposito |
|------------------------|-----------|
| `data/raw/`            | Archivos Parquet tal como se descargan de la TLC, organizados como `<tipo>/<anio>/`. Nunca se modifican: son la fuente original. |
| `data/processed/`      | Resultados derivados: la base `.duckdb` materializada (Ej. 6) y cualquier dato transformado. Se puede regenerar a partir de `raw/`. |
| `notebooks/`           | Notebooks de Jupyter para exploracion, analisis y graficas. |
| `scripts/`             | Codigo Python reproducible: descarga de datos (`download_data.py`), benchmarks, generacion de la base. |
| `sql/`                 | Consultas SQL versionadas, separadas del codigo para poder reutilizarlas desde notebooks, scripts y Metabase. |
| `docs/`                | Documentacion de cada ejercicio: consultas, resultados, decisiones e interpretaciones. |
| `Dockerfile`           | Imagen del ambiente de analisis (Python + DuckDB + JupyterLab). |
| `metabase.Dockerfile`  | Imagen de Metabase con el driver de DuckDB, para el tablero. |
| `docker-compose.yml`   | Levanta ambos servicios y monta las carpetas del proyecto dentro de los contenedores. |
| `.gitignore`           | Evita que los datos (`data/raw/**`, `data/processed/**`) se suban a Git. |

La separacion `raw` / `processed` hace que todo lo que esta en `processed` sea
reconstruible, y la separacion `sql` / `scripts` / `notebooks` permite versionar
las consultas de forma independiente a la herramienta que las ejecuta.

## Verificacion de los servicios (1.3)

Despues de `docker compose up -d`:

| Verificacion | Comando | Resultado |
|---|---|---|
| Contenedores | `docker compose ps` | `lab8-lab` y `lab8-metabase` en estado `Up` |
| JupyterLab | `curl -o /dev/null -w "%{http_code}" http://localhost:8888/lab` | `200` |
| Metabase | `curl http://localhost:3000/api/health` | `{"status":"ok"}` |
| Driver DuckDB en Metabase | `docker compose logs metabase \| grep duckdb` | `Registered driver :duckdb` |
| DuckDB en Python | `docker compose exec lab python -c "import duckdb; print(duckdb.sql('select 42').fetchall())"` | `[(42,)]` |

## Herramientas disponibles (1.4)

**Contenedor `lab` (`lab8-lab`, puerto 8888)** - imagen `python:3.11.14-slim`

| Herramienta | Version | Uso en el lab |
|---|---|---|
| Python | 3.11.14 | Lenguaje base |
| DuckDB | 1.5.5 | Motor SQL analitico, consulta Parquet directamente |
| JupyterLab | 4.6.4 | Notebooks (sin token, solo en `127.0.0.1`) |
| pandas | 3.0.6 | Manipulacion de resultados pequenos |
| pyarrow | 25.0.1 | Lectura/escritura de Parquet y Arrow |
| matplotlib | 3.11.2 | Graficas |
| requests | 2.34.2 | Descarga de archivos desde la TLC |
| curl | sistema | Pruebas HTTP |

**Contenedor `metabase` (`lab8-metabase`, puerto 3000)** - imagen `eclipse-temurin:21-jre-jammy`

| Herramienta | Version | Uso en el lab |
|---|---|---|
| Metabase | v0.63.19 | Tablero de indicadores (Ej. 7 y 8) |
| Driver DuckDB para Metabase | 1.5.5.0 | Conecta Metabase a la base `.duckdb` |
| Java (OpenJDK) | 21 | Runtime de Metabase |

Ambos contenedores montan `./data` en `/workspace/data`, asi que Metabase puede
leer la base DuckDB generada desde el contenedor `lab`. Las versiones de `duckdb`
(requirements) y del driver de Metabase estan alineadas (1.5.5): un archivo
`.duckdb` escrito con una version debe poder abrirse con la otra.

## Por que un ambiente reproducible (1.6)

- **Mismos resultados en cualquier maquina:** las versiones estan fijadas
  (`duckdb==1.5.5`, Metabase `v0.63.19`, Python 3.11.14). Si cada integrante
  tuviera versiones distintas, el formato de archivo de DuckDB, las funciones SQL
  o el comportamiento de pandas podrian cambiar y los resultados no coincidirian.
- **Compatibilidad entre componentes:** el driver de DuckDB en Metabase debe
  coincidir con la version de DuckDB que crea la base; Docker garantiza esa
  combinacion sin configuracion manual.
- **Sin "en mi maquina funciona":** el equipo trabaja de forma secuencial, y quien
  recibe el trabajo solo necesita Docker y `docker compose up` para continuar.
- **Aislamiento:** no se instala nada en el sistema operativo del usuario ni se
  generan conflictos con otros proyectos.
- **Evaluacion y auditoria:** un tercero (el docente) puede reconstruir el
  ambiente exacto, volver a descargar los datos con los scripts y obtener los
  mismos numeros; eso es lo que hace verificable el analisis.
- **Codigo y datos separados:** el codigo vive en Git y los datos se regeneran
  desde la fuente original, por lo que el repositorio es liviano y el proceso es
  repetible cuando llegan datos nuevos.
