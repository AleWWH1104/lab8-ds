"""Benchmark Ej. 6: mismas consultas sobre los Parquet y sobre una tabla DuckDB materializada.

Para cada volumen de datos:
  1. crea un esquema `parquet_<vol>` con una vista `viajes` que lee los Parquet;
  2. crea un esquema `tabla_<vol>` con la tabla `viajes` materializada (mide cuanto tarda);
  3. ejecuta cada consulta de sql/ej6_benchmark.sql sobre los dos esquemas,
     una vez en frio y luego --repeticiones veces, y guarda los tiempos.

La base del benchmark (data/processed/benchmark.duckdb) se borra al inicio y al final.
No toca data/processed/taxis.duckdb.

Uso:
    python scripts/benchmark.py
    python scripts/benchmark.py --repeticiones 3 --volumenes 1_mes 2026
"""

import argparse
import csv
import glob
import os
import statistics
import time
from pathlib import Path

from crear_tabla import RAIZ, conectar, patrones, sql_viajes
from run_sql import leer_consultas

VOLUMENES = {
    "1_mes": dict(anios=[2026], meses="01"),
    "2026": dict(anios=[2026]),
    "2024_2026": dict(anios=[2024, 2026]),
    "todos": dict(anios=None),
}
DB = RAIZ / "data" / "processed" / "benchmark.duckdb"
SALIDA = RAIZ / "docs" / "resultados" / "ej6_benchmark.csv"


def tamanio_parquet(anios, meses="*"):
    return sum(os.path.getsize(f) for lista in patrones(anios, meses) for p in lista for f in glob.glob(p))


def medir(con, sql):
    inicio = time.perf_counter()
    con.execute(sql).fetchall()
    return time.perf_counter() - inicio


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--volumenes", nargs="+", default=["1_mes", "2026", "2024_2026"], choices=VOLUMENES)
    parser.add_argument("--repeticiones", type=int, default=5)
    parser.add_argument("--consultas", type=Path, default=RAIZ / "sql" / "ej6_benchmark.sql")
    args = parser.parse_args()

    consultas = leer_consultas(args.consultas)
    for ruta in (DB, DB.with_name(DB.name + ".wal")):
        ruta.unlink(missing_ok=True)
    con = conectar(DB)

    filas = []
    for vol in args.volumenes:
        yellow, green = patrones(**VOLUMENES[vol])
        seleccion = sql_viajes(yellow, green)

        con.execute(f"CREATE SCHEMA parquet_{vol}")
        con.execute(f"CREATE VIEW parquet_{vol}.viajes AS {seleccion}")

        con.execute(f"CREATE SCHEMA tabla_{vol}")
        carga = medir(con, f"CREATE TABLE tabla_{vol}.viajes AS {seleccion}")
        con.execute("CHECKPOINT")
        registros = con.execute(f"SELECT count(*) FROM tabla_{vol}.viajes").fetchone()[0]
        mb_parquet = tamanio_parquet(**VOLUMENES[vol]) / 2**20
        print(f"\n== {vol}: {registros:,} registros, {mb_parquet:,.0f} MiB de Parquet, tabla creada en {carga:.2f} s")
        filas.append(dict(volumen=vol, registros=registros, consulta="(crear tabla)", estrategia="tabla",
                          frio_s=round(carga, 4), mediana_s=round(carga, 4), min_s=round(carga, 4),
                          max_s=round(carga, 4), mb_parquet=round(mb_parquet, 1)))

        for c in consultas:
            for estrategia in ("parquet", "tabla"):
                con.execute(f"SET search_path = '{estrategia}_{vol}'")
                frio = medir(con, c["sql"])
                tiempos = [medir(con, c["sql"]) for _ in range(args.repeticiones)]
                fila = dict(volumen=vol, registros=registros, consulta=c["titulo"], estrategia=estrategia,
                            frio_s=round(frio, 4), mediana_s=round(statistics.median(tiempos), 4),
                            min_s=round(min(tiempos), 4), max_s=round(max(tiempos), 4),
                            mb_parquet=round(mb_parquet, 1))
                filas.append(fila)
                print(f"  {c['titulo'][:45]:45} {estrategia:8} frio {frio:7.3f} s  mediana {fila['mediana_s']:7.3f} s")

        con.execute(f"DROP SCHEMA tabla_{vol} CASCADE")
        con.execute(f"DROP SCHEMA parquet_{vol} CASCADE")
        con.execute("CHECKPOINT")

    con.close()
    for ruta in (DB, DB.with_name(DB.name + ".wal")):
        ruta.unlink(missing_ok=True)

    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    with SALIDA.open("w", newline="", encoding="utf-8") as f:
        escritor = csv.DictWriter(f, fieldnames=list(filas[0]))
        escritor.writeheader()
        escritor.writerows(filas)
    print(f"\nGuardado en {SALIDA}")


if __name__ == "__main__":
    main()
