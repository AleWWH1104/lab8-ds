# Lab 8 - DuckDB

Repositorio base del laboratorio 8 del curso **CC3084 - Data Science**
(Universidad del Valle de Guatemala, Ciclo 2, 2026).

Este es el repositorio **proporcionado por el docente**. Contiene la estructura
del proyecto, el ambiente de ejecucion basado en Docker y un script que descarga
los datos de **2026**. Todo lo demas debe ser construido por cada equipo.

## Trabajo con fork

El laboratorio se desarrolla y se entrega sobre un **fork** de este repositorio.
No se trabaja directamente sobre el repositorio del docente.

1. Realice un fork de este repositorio:
   <https://github.com/menene/duckdb>

2. Clone **su propio fork** (no el del docente):

   ```bash
   git clone https://github.com/<su-usuario>/duckdb.git
   cd duckdb
   ```

3. Opcional, para recibir correcciones publicadas por el docente:

   ```bash
   git remote add upstream https://github.com/menene/duckdb.git
   git fetch upstream
   ```

Realice commits frecuentes y descriptivos: el historial del repositorio es parte
de la evaluacion. **La entrega del laboratorio es la URL de su fork.**

## Estructura

```text
duckdb/
|
+-- data/
|   +-- raw/
|   +-- processed/
|
+-- notebooks/
|
+-- scripts/
|
+-- sql/
|
+-- docs/
|
+-- Dockerfile
+-- metabase.Dockerfile
+-- docker-compose.yml
+-- README.md
```

## Requisitos

- Docker, con Docker Compose
- Git

La primera construccion del ambiente descarga varios cientos de MB y puede
tardar algunos minutos.

Considere el espacio en disco: las imagenes de Docker ocupan unos 3 GB y los
datos de los tres anios del laboratorio superan 1.5 GB, a los que se suma la
base materializada del Ejercicio 6. Se recomienda tener al menos 10 GB libres.

## Datos

El repositorio incluye `scripts/download_data.py`, que descarga los archivos de
2026 publicados por la TLC (`--help` muestra las opciones disponibles). Los
archivos se guardan en `data/raw/<tipo>/<anio>/`.

La TLC publica cada mes con varias semanas de atraso, por lo que los ultimos
meses de 2026 todavia no existen. El script consulta al servidor que meses estan
publicados, de modo que vuelve a ejecutarse sin problema conforme aparezcan
nuevos archivos.

Los datos descargados **no deben incluirse en el repositorio Git**. El archivo
`.gitignore` ya esta configurado para evitarlo.

Fuente de datos: NYC TLC Trip Record Data
<https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page>

Dentro de los contenedores, la carpeta `data/` del proyecto esta montada en
`/workspace/data`. Esa es la ruta que deben usar las herramientas que corren
dentro del ambiente, no la ruta de su computadora.

> **Nota sobre DuckDB:** un archivo `.duckdb` admite un solo proceso con permiso
> de escritura a la vez. Si conecta una herramienta externa a su base de datos,
> use el modo de solo lectura (`read_only`) en esa conexion; de lo contrario los
> demas procesos no podran abrir el archivo.

## Material a entregar

Al finalizar, su fork debe contener:

- el codigo fuente modificado y los scripts de descarga;
- las consultas SQL desarrolladas;
- el notebook o notebooks utilizados;
- la documentacion de las consultas;
- los scripts utilizados para los benchmarks;
- el codigo de los indicadores y visualizaciones;
- el tablero o la evidencia del tablero desarrollado;
- este `README.md`, completado segun la siguiente seccion.

Los archivos de datos descargados **no** deben incluirse.

---

# Documentacion del equipo

Las siguientes secciones deben ser completadas por cada equipo. El README final
debe permitir que una persona que no participo en el desarrollo pueda levantar el
ambiente, descargar los datos, ejecutar el analisis, reproducir los benchmarks y
generar los resultados principales.

## Como levantar el ambiente

Probado con Docker 28.5.1 y Docker Compose v2.40.3.

1. Clonar el fork y entrar al proyecto:

   ```bash
   git clone https://github.com/<su-usuario>/duckdb.git
   cd duckdb
   ```

2. Construir las imagenes y levantar los servicios en segundo plano (la primera
   vez tarda varios minutos):

   ```bash
   docker compose up -d --build
   ```

3. Verificar que ambos contenedores esten en estado `Up`:

   ```bash
   docker compose ps
   ```

4. Abrir los servicios:

   | Servicio   | URL                     | Verificacion                                         |
   |------------|-------------------------|------------------------------------------------------|
   | JupyterLab | <http://localhost:8888> | responde HTTP 200, sin token                         |
   | Metabase   | <http://localhost:3000> | `curl http://localhost:3000/api/health` -> `{"status":"ok"}` (tarda ~1-2 min en iniciar) |

5. Verificar DuckDB dentro del contenedor de analisis:

   ```bash
   docker compose exec lab python -c "import duckdb; print(duckdb.sql('select version()').fetchall())"
   ```

   Debe imprimir `[('v1.5.5',)]`.

6. Para ejecutar scripts dentro del ambiente se usa `docker compose exec lab <comando>`.
   Dentro del contenedor el proyecto vive en `/workspace`.

7. Para detener el ambiente: `docker compose down` (los datos en `data/` y la
   configuracion de Metabase en el volumen `metabase-data` se conservan).

La descripcion de las herramientas disponibles, el proposito de cada directorio y
la justificacion del ambiente reproducible estan en
[docs/ej1_ambiente.md](docs/ej1_ambiente.md).

## Como descargar los datos

Con el ambiente levantado:

```bash
# 2024 y 2026, taxis amarillos y verdes (por defecto)
docker compose exec lab python scripts/download_data.py

# Verificar que lo descargado este completo, sin descargar nada
docker compose exec lab python scripts/download_data.py --verificar
```

Opciones:

| Opcion | Descripcion |
|---|---|
| `--anios 2024 2026` | Uno o varios anios (por defecto `2024 2026`) |
| `--taxi yellow\|green\|all` | Tipo de taxi (por defecto `all`) |
| `--verificar` | Compara los archivos locales con los publicados por la TLC (firma Parquet y tamanio exacto); sale con codigo 1 si falta algo |

Los archivos se guardan en `data/raw/<tipo>/<anio>/`. Volver a ejecutar el
script es seguro: omite los archivos validos que ya existen, vuelve a descargar
los corruptos y solo baja los meses nuevos.

Detalle de los cambios al script y de la verificacion de completitud:
[docs/ej2_descarga.md](docs/ej2_descarga.md). Incorporacion de 2024:
[docs/ej5_incorporacion.md](docs/ej5_incorporacion.md).

## Como ejecutar el analisis

Cada archivo de `sql/` se ejecuta con `scripts/run_sql.py`, que muestra los resultados y los puede guardar en markdown:

```bash
docker compose exec lab python scripts/run_sql.py sql/ej3_exploracion.sql --md docs/resultados/ej3_exploracion.md
docker compose exec lab python scripts/run_sql.py sql/ej4_analisis.sql --md docs/resultados/ej4_analisis.md
docker compose exec lab python scripts/run_sql.py sql/ej5_validacion.sql --md docs/resultados/ej5_validacion.md
```

Documentacion: [Ej. 3 exploracion](docs/ej3_exploracion.md), [Ej. 4 analisis](docs/ej4_analisis.md), [Ej. 5 incorporacion de 2024](docs/ej5_incorporacion.md).

## Como reproducir los benchmarks

<!-- TODO (Ejercicio 6) -->

## Como generar los resultados principales

<!-- TODO -->
