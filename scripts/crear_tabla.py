"""Materializa los Parquet de data/raw en una base DuckDB (data/processed/taxis.duckdb).

Crea la tabla `viajes` (yellow y green con columnas comunes, igual que la vista
`viajes` de sql/ej3_exploracion.sql) y la vista `viajes_limpios` con el filtro
base del Ej. 3. Incluye todos los anios descargados. Se vuelve a crear desde cero
cada vez que se ejecuta, asi que basta correrlo de nuevo al agregar un anio.

Uso:
    python scripts/crear_tabla.py
    python scripts/crear_tabla.py --db data/processed/otra.duckdb --anios 2026
"""

import argparse
import time
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
DB_POR_DEFECTO = RAIZ / "data" / "processed" / "taxis.duckdb"

COLUMNAS_FECHA = r"""
       regexp_extract(filename, '_(\d{4})-\d{2}\.parquet$', 1)::INTEGER AS anio_archivo,
       regexp_extract(filename, '_\d{4}-(\d{2})\.parquet$', 1)::INTEGER AS mes_archivo"""


def sql_viajes(patron_yellow, patron_green):
    """SELECT que une yellow y green con columnas comunes a partir de patrones de archivos."""
    return f"""
SELECT 'yellow' AS tipo, anio_archivo, mes_archivo, VendorID,
       tpep_pickup_datetime AS pickup, tpep_dropoff_datetime AS dropoff,
       passenger_count, trip_distance, RatecodeID, store_and_fwd_flag,
       PULocationID, DOLocationID, payment_type,
       fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
       congestion_surcharge, Airport_fee AS airport_fee, NULL::DOUBLE AS ehail_fee,
       cbd_congestion_fee, total_amount, NULL::BIGINT AS trip_type
FROM (SELECT *, {COLUMNAS_FECHA}
      FROM read_parquet({patron_yellow!r}, filename = true, union_by_name = true))
UNION ALL BY NAME
SELECT 'green' AS tipo, anio_archivo, mes_archivo, VendorID,
       lpep_pickup_datetime AS pickup, lpep_dropoff_datetime AS dropoff,
       passenger_count, trip_distance, RatecodeID, store_and_fwd_flag,
       PULocationID, DOLocationID, payment_type,
       fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
       congestion_surcharge, NULL::DOUBLE AS airport_fee, ehail_fee,
       cbd_congestion_fee, total_amount, trip_type
FROM (SELECT *, {COLUMNAS_FECHA}
      FROM read_parquet({patron_green!r}, filename = true, union_by_name = true))
"""


SQL_VIAJES_LIMPIOS = """
CREATE OR REPLACE VIEW viajes_limpios AS
SELECT *,
       date_diff('second', pickup, dropoff) / 60.0 AS duracion_min,
       trip_distance / (date_diff('second', pickup, dropoff) / 3600.0) AS velocidad_mph,
       CASE payment_type
           WHEN 0 THEN 'Flex Fare' WHEN 1 THEN 'Tarjeta' WHEN 2 THEN 'Efectivo'
           WHEN 3 THEN 'Sin cargo' WHEN 4 THEN 'Disputa' WHEN 5 THEN 'Desconocido'
           WHEN 6 THEN 'Anulado' ELSE 'Nulo' END AS forma_pago
FROM viajes
WHERE year(pickup) = anio_archivo AND month(pickup) = mes_archivo
  AND dropoff > pickup
  AND dropoff - pickup < INTERVAL 6 HOUR
  AND trip_distance > 0 AND trip_distance <= 100
  AND total_amount >= 0
QUALIFY row_number() OVER (
    PARTITION BY tipo, VendorID, pickup, dropoff, PULocationID, DOLocationID, total_amount
    ORDER BY fare_amount) = 1
"""


def patrones(anios=None, meses="*"):
    """Listas de patrones de archivos (yellow, green) para los anios indicados (todos si anios es None)."""
    carpetas = [str(a) for a in anios] if anios else ["*"]
    raw = RAIZ / "data" / "raw"
    return tuple(
        [str(raw / tipo / c / f"{tipo}_tripdata_*-{meses}.parquet") for c in carpetas]
        for tipo in ("yellow", "green")
    )


def conectar(db):
    con = duckdb.connect(str(db))
    con.execute("SET memory_limit = '4GB'")
    con.execute("SET preserve_insertion_order = false")
    return con


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DB_POR_DEFECTO)
    parser.add_argument("--anios", nargs="+", type=int, help="por defecto, todos los anios descargados")
    args = parser.parse_args()

    args.db.parent.mkdir(parents=True, exist_ok=True)
    for ruta in (args.db, args.db.with_name(args.db.name + ".wal")):
        ruta.unlink(missing_ok=True)

    yellow, green = patrones(args.anios)
    con = conectar(args.db)
    inicio = time.perf_counter()
    con.execute(f"CREATE TABLE viajes AS {sql_viajes(yellow, green)}")
    con.execute(SQL_VIAJES_LIMPIOS)
    con.execute("CHECKPOINT")
    segundos = time.perf_counter() - inicio

    print(f"Tabla viajes creada en {args.db} ({segundos:.1f} s)")
    for tipo, anio, registros in con.execute(
        "SELECT tipo, anio_archivo, count(*) FROM viajes GROUP BY ALL ORDER BY tipo DESC, anio_archivo"
    ).fetchall():
        print(f"  {tipo:6} {anio}  {registros:>12,}")
    con.close()
    print(f"Tamanio del archivo: {args.db.stat().st_size / 2**20:,.0f} MiB")


if __name__ == "__main__":
    main()
