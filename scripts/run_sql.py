"""Ejecuta un archivo .sql con DuckDB. Cada consulta empieza con una linea '-- <inciso> <titulo>'."""

import argparse
import time
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
MAX_FILAS = 50


def leer_consultas(ruta):
    consultas = []
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if linea.startswith("-- "):
            consultas.append({"titulo": linea[3:].strip(), "sql": []})
        elif consultas:
            consultas[-1]["sql"].append(linea)
    for c in consultas:
        c["sql"] = "\n".join(c["sql"]).strip()
    return consultas


def formato(valor):
    if valor is None:
        return "NULL"
    if isinstance(valor, float):
        return f"{valor:.4f}".rstrip("0").rstrip(".")
    return str(valor)


def tabla_texto(columnas, filas):
    celdas = [[formato(v) for v in f] for f in filas]
    anchos = [max([len(c)] + [len(f[i]) for f in celdas]) for i, c in enumerate(columnas)]
    linea = lambda vals: " | ".join(v.ljust(a) for v, a in zip(vals, anchos))
    return "\n".join([linea(columnas), "-+-".join("-" * a for a in anchos)] + [linea(f) for f in celdas])


def tabla_md(columnas, filas):
    salida = ["| " + " | ".join(columnas) + " |", "|" + "---|" * len(columnas)]
    salida += ["| " + " | ".join(formato(v).replace("|", "\\|") for v in f) + " |" for f in filas]
    return "\n".join(salida)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archivo", type=Path)
    parser.add_argument("--solo", nargs="+", help="incisos a ejecutar, p. ej. 3.1 3.6")
    parser.add_argument("--md", type=Path, help="guarda consultas y resultados en markdown")
    parser.add_argument("--db", default=":memory:")
    args = parser.parse_args()

    consultas = leer_consultas(args.archivo)
    if args.solo:
        consultas = [c for c in consultas if c["titulo"].split()[0] in args.solo + ["0"]]

    con = duckdb.connect(args.db)
    con.execute(f"SET file_search_path = '{RAIZ}'")

    md = [f"# Resultados de {args.archivo.name}"]
    for c in consultas:
        inicio = time.perf_counter()
        con.execute(c["sql"])
        columnas = [d[0] for d in con.description] if con.description else []
        filas = con.fetchall() if columnas and columnas != ["Count"] else []
        segundos = time.perf_counter() - inicio

        print(f"\n{c['titulo']}")
        if filas:
            print(tabla_texto(columnas, filas[:MAX_FILAS]))
        print(f"({len(filas)} filas, {segundos:.2f} s)")

        md += ["", f"## {c['titulo']}", "", "```sql", c["sql"], "```", ""]
        if filas:
            md += [tabla_md(columnas, filas[:MAX_FILAS]), ""]
        md.append(f"{len(filas)} filas, {segundos:.2f} s")

    if args.md:
        args.md.parent.mkdir(parents=True, exist_ok=True)
        args.md.write_text("\n".join(md) + "\n", encoding="utf-8")
        print(f"\nGuardado en {args.md}")


if __name__ == "__main__":
    main()
