# Ejercicio 2 - Sistema de descarga

Script: [`scripts/download_data.py`](../scripts/download_data.py)

## 2.1 Analisis del script original

El script entregado ya descargaba de forma correcta un mes cualquiera (archivo
temporal `.part`, reintentos, omitir archivos existentes). Sin embargo tenia
estas limitaciones:

| # | Problema | Consecuencia |
|---|----------|--------------|
| 1 | El anio estaba fijo (`ANIO = 2026`) en constantes y funciones. | Para agregar 2024 y 2025 (Ej. 5 y 8) habria que editar el codigo. |
| 2 | Un archivo existente se omitia solo con revisar `st_size > 0`. | Un archivo truncado o corrupto se quedaba asi para siempre. |
| 3 | No se comparaba lo descargado con el tamanio anunciado por el servidor. | Una descarga cortada podia darse por buena. |
| 4 | `esta_publicado()` devolvia `False` ante cualquier error, incluido un timeout. | Un error de red se reportaba como "aun no publicado" y el mes faltante pasaba inadvertido. |
| 5 | `DIR_DESTINO = Path("data/raw")` era relativo al directorio actual. | Ejecutarlo desde otra carpeta guardaba los archivos en el lugar equivocado. |
| 6 | No habia forma de verificar el conjunto sin volver a descargar. | No se podia demostrar que la descarga estaba completa (2.7). |

## 2.2 - 2.4 / 2.6 Cambios realizados

1. **Anios parametrizables:** nuevo argumento `--anios` (uno o varios, por
   defecto `2026`). Todas las funciones (`construir_nombre`, `construir_url`,
   `ruta_destino`) reciben el anio como parametro. Agregar un anio es solo
   cambiar el comando, no el codigo.
2. **Descubrimiento de meses publicados:** para cada mes 1-12 se hace un `HEAD`
   al servidor. El CloudFront de la TLC responde `200` + `Content-Length` si el
   archivo existe y `403` si no (verificado manualmente). `403`/`404` se tratan
   como "no publicado"; cualquier otro error se reporta como **fallido**.
3. **Validacion de archivos (`es_parquet_valido`):** un archivo se considera
   valido si empieza y termina con la firma `PAR1` del formato Parquet y, cuando
   se conoce, su tamanio coincide con el `Content-Length` del servidor.
4. **Evitar descargas repetidas (2.4):** si el archivo local es un Parquet valido
   se omite **sin consultar el servidor**. Si existe pero es invalido, se
   descarga de nuevo.
5. **Validacion despues de descargar:** el `.part` solo se renombra a `.parquet`
   si pasa la validacion; si no, se reintenta (hasta 3 veces).
6. **Ruta absoluta:** `DIR_DESTINO` se calcula a partir de la ubicacion del
   script, asi que funciona desde cualquier directorio.
7. **Modo `--verificar`:** no descarga nada; compara cada archivo local con el
   publicado (existencia, firma y tamanio exacto) y termina con codigo 1 si falta
   algo.

Estructura resultante (2.3):

```text
data/raw/
+-- yellow/2026/yellow_tripdata_2026-01.parquet ... 2026-08.parquet
+-- green/2026/green_tripdata_2026-01.parquet  ... 2026-08.parquet
```

## Uso

```bash
# Descargar 2026 (amarillos y verdes)
docker compose exec lab python scripts/download_data.py

# Verificar sin descargar
docker compose exec lab python scripts/download_data.py --verificar

# Otros anios (Ej. 5 y 8)
docker compose exec lab python scripts/download_data.py --anios 2024 2025 2026
```

## 2.5 Ejecucion

Primera corrida (2026-10-08):

```text
descargados   : 16
ya existian   : 0
no publicados : 8   (yellow y green 2026-09 a 2026-12)
fallidos      : 0
```

Segunda corrida: `descargados: 0`, `ya existian: 16`. No se volvio a bajar nada
y no se consulto la red para los archivos existentes.

Prueba de corrupcion: se trunco `green_tripdata_2026-03.parquet` a 500 KB. El
script respondio `existe pero es invalido, se descarga de nuevo`, y el archivo
restaurado quedo identico byte a byte al original (`cmp`).

## 2.7 Como se determino que el conjunto esta completo

Se usaron tres verificaciones independientes:

1. **Contra la fuente:** se consultaron los 12 meses de cada tipo. Los meses
   2026-01 a 2026-08 responden `200` y estan descargados. Los meses 2026-09 a
   2026-12 responden `403`, es decir, la TLC todavia no los publica (lo cual es
   esperable por el atraso de publicacion). El universo esperado son 16 archivos
   y hay 16.
2. **Integridad de cada archivo:** `--verificar` confirma, para cada archivo, la
   firma `PAR1` al inicio y al final y que su tamanio es exactamente el
   `Content-Length` del servidor:

   ```text
   completos     : 16
   no publicados : 8
   faltantes     : 0
   ```

3. **Lectura con DuckDB:** todos los archivos se pueden leer y contienen
   registros, sin huecos de meses:

   ```sql
   SELECT split_part(filename, '/', 3) AS tipo,
          count(DISTINCT filename)     AS archivos,
          count(*)                     AS registros
   FROM read_parquet('data/raw/*/2026/*.parquet', filename = true, union_by_name = true)
   GROUP BY 1 ORDER BY 1;
   ```

   | tipo   | archivos | registros  | tamanio |
   |--------|---------:|-----------:|--------:|
   | green  | 8        | 337,114    | 7.9 MB  |
   | yellow | 8        | 29,703,355 | 488 MB  |

   Por mes, yellow tiene entre 3.3 y 4.1 millones de viajes y green entre 37 mil
   y 45 mil, sin meses vacios ni valores anormalmente bajos que indiquen un
   archivo incompleto.

Como el script consulta al servidor en cada ejecucion, cuando la TLC publique
2026-09 en adelante basta con volver a ejecutarlo: bajara solo los meses nuevos.
