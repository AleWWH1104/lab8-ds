"""Construye el cubo de agregados que consume el tablero de Metabase (Ej. 7).

Lee la vista `viajes_limpios` de data/processed/taxis.duckdb (en solo lectura) y
crea las tablas de sql/ej7_cubo.sql en data/processed/indicadores.duckdb. El cubo
tiene unas decenas de miles de filas, asi que Metabase lo consulta en
milisegundos en lugar de recorrer 120 millones de viajes. Se vuelve a crear desde
cero cada vez; al agregar un anio basta con regenerar taxis.duckdb y correr este script.

Uso:
    python scripts/crear_indicadores.py
    python scripts/crear_indicadores.py --taxis data/processed/taxis.duckdb --salida data/processed/otro.duckdb
"""

import argparse
import time
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
TAXIS_POR_DEFECTO = RAIZ / "data" / "processed" / "taxis.duckdb"
SALIDA_POR_DEFECTO = RAIZ / "data" / "processed" / "indicadores.duckdb"
SQL_CUBO = RAIZ / "sql" / "ej7_cubo.sql"


def main() -> None:
    parser = argparse.ArgumentParser(description="Crea el cubo de agregados del Ej. 7.")
    parser.add_argument("--taxis", type=Path, default=TAXIS_POR_DEFECTO)
    parser.add_argument("--salida", type=Path, default=SALIDA_POR_DEFECTO)
    argumentos = parser.parse_args()

    if not argumentos.taxis.exists():
        raise SystemExit(f"No existe {argumentos.taxis}; ejecute primero scripts/crear_tabla.py")

    argumentos.salida.unlink(missing_ok=True)
    argumentos.salida.parent.mkdir(parents=True, exist_ok=True)
    temporal = argumentos.salida.parent / "tmp"

    conexion = duckdb.connect(str(argumentos.salida))
    conexion.execute("SET memory_limit = '4GB'")
    conexion.execute("SET preserve_insertion_order = false")
    conexion.execute(f"SET temp_directory = '{temporal}'")
    conexion.execute(f"ATTACH '{argumentos.taxis}' AS t (READ_ONLY)")

    inicio = time.perf_counter()
    conexion.execute(SQL_CUBO.read_text())
    segundos = time.perf_counter() - inicio

    print(f"Cubo creado en {argumentos.salida} ({segundos:.1f} s)")
    for tabla in ("cubo_viajes", "cubo_zonas"):
        filas = conexion.execute(f"SELECT count(*) FROM {tabla}").fetchone()[0]
        print(f"  {tabla:<12} {filas:>9,} filas")
    anios = conexion.execute("SELECT DISTINCT anio FROM cubo_viajes ORDER BY anio").fetchall()
    print(f"  anios: {', '.join(str(a[0]) for a in anios)}")
    conexion.close()
    print(f"Tamanio del archivo: {argumentos.salida.stat().st_size / 2**20:,.1f} MiB")


if __name__ == "__main__":
    main()
