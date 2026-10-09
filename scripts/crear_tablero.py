"""Crea el tablero del Ej. 7 en Metabase a traves de su API.

Pasos (se puede ejecutar varias veces; actualiza lo que ya existe):
  1. Espera a que Metabase este disponible y crea el usuario administrador local
     la primera vez (o inicia sesion si ya existe).
  2. Registra la base DuckDB data/processed/indicadores.duckdb en modo solo lectura.
  3. Convierte cada consulta de sql/ej7_indicadores.sql en una tarjeta (pregunta
     nativa) con su visualizacion.
  4. Arma el tablero "Taxis NYC 2024-2026" con las tarjetas.

Las credenciales son solo para el ambiente local de Docker (Metabase escucha en
127.0.0.1); no usar estos valores fuera del laboratorio.

Uso (con el ambiente levantado y el cubo creado con scripts/crear_indicadores.py):
    python scripts/crear_tablero.py
    python scripts/crear_tablero.py --url http://localhost:3000   # desde fuera de Docker
"""

import argparse
import re
import sys
import time
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parent.parent
SQL_INDICADORES = RAIZ / "sql" / "ej7_indicadores.sql"

URL_POR_DEFECTO = "http://metabase:3000"   # nombre del servicio en docker-compose
CORREO = "admin@lab8.local"
CLAVE = "Lab8-duckdb-2026"
BASE_NOMBRE = "Taxis NYC (indicadores)"
BASE_ARCHIVO = "/workspace/data/processed/indicadores.duckdb"
COLECCION = "Lab 8 - Taxis NYC"
TABLERO = "Taxis NYC 2024-2026"

# Visualizacion de cada indicador y su posicion en el tablero (cuadricula de 24 columnas).
# dimensiones y metricas son nombres de columnas devueltas por la consulta.
INDICADORES = {
    "7.0": dict(display="scalar", fila=0, col=0, ancho=6, alto=4),
    "7.1": dict(display="line", dim=["mes", "anio"], met=["viajes"],
                fila=0, col=6, ancho=18, alto=4),
    "7.2": dict(display="line", dim=["hora", "tipo"], met=["pct_viajes"],
                fila=4, col=0, ancho=12, alto=6),
    "7.4": dict(display="line", dim=["mes", "anio"], met=["millones_usd"],
                fila=4, col=12, ancho=12, alto=6),
    "7.3": dict(display="bar", dim=["anio", "forma_pago"], met=["pct_viajes"],
                extra={"stackable.stack_type": "stacked"},
                fila=10, col=0, ancho=8, alto=6),
    "7.6": dict(display="line", dim=["mes", "anio"], met=["minutos_promedio"],
                fila=10, col=8, ancho=8, alto=6),
    "7.8": dict(display="line", dim=["mes", "anio"], met=["pct_green"],
                fila=10, col=16, ancho=8, alto=6),
    "7.5": dict(display="line", dim=["hora", "anio"], met=["propina_pct"],
                fila=16, col=0, ancho=12, alto=6),
    "7.7": dict(display="line", dim=["mes", "anio"], met=["pct_con_cargo"],
                fila=16, col=12, ancho=12, alto=6),
    "7.9": dict(display="bar", dim=["zona"], met=["viajes"],
                fila=22, col=0, ancho=24, alto=6),
}


class Metabase:
    def __init__(self, url: str):
        self.url = url.rstrip("/")
        self.http = requests.Session()

    def llamar(self, metodo: str, ruta: str, **kwargs):
        respuesta = self.http.request(metodo, f"{self.url}/api{ruta}", timeout=120, **kwargs)
        if not respuesta.ok:
            raise SystemExit(f"{metodo} {ruta} -> {respuesta.status_code}: {respuesta.text[:400]}")
        return respuesta.json() if respuesta.content else None

    def esperar(self) -> None:
        for _ in range(60):
            try:
                if self.http.get(f"{self.url}/api/health", timeout=5).json().get("status") == "ok":
                    return
            except requests.RequestException:
                pass
            time.sleep(5)
        raise SystemExit("Metabase no responde; revise `docker compose ps`")

    def iniciar_sesion(self) -> None:
        propiedades = self.llamar("GET", "/session/properties")
        if not propiedades.get("has-user-setup"):
            sesion = self.llamar("POST", "/setup", json={
                "token": propiedades["setup-token"],
                "user": {"first_name": "Lab", "last_name": "8", "email": CORREO, "password": CLAVE},
                "prefs": {"site_name": "Lab 8 DuckDB", "allow_tracking": False},
            })
            print("Usuario administrador creado")
        else:
            sesion = self.llamar("POST", "/session", json={"username": CORREO, "password": CLAVE})
        self.http.headers["X-Metabase-Session"] = sesion["id"]


def leer_indicadores() -> dict[str, tuple[str, str]]:
    """{'7.1': ('Viajes por mes y anio', 'SELECT ...')} a partir de sql/ej7_indicadores.sql."""
    texto = SQL_INDICADORES.read_text()
    partes = re.split(r"^-- (7\.\d+) (.+)$", texto, flags=re.MULTILINE)
    # partes = [preambulo, id, titulo, cuerpo, id, titulo, cuerpo, ...]
    return {
        partes[i]: (partes[i + 1].strip(), partes[i + 2].strip().rstrip(";").strip())
        for i in range(1, len(partes), 3)
    }


def asegurar_base(mb: Metabase) -> int:
    for base in mb.llamar("GET", "/database")["data"]:
        if base["name"] == BASE_NOMBRE:
            print(f"Base '{BASE_NOMBRE}' ya existe (id {base['id']})")
            return base["id"]
    base = mb.llamar("POST", "/database", json={
        "name": BASE_NOMBRE,
        "engine": "duckdb",
        "details": {"database_file": BASE_ARCHIVO, "read_only": True, "old_implicit_casting": True},
        "is_full_sync": True,
    })
    print(f"Base '{BASE_NOMBRE}' creada (id {base['id']})")
    return base["id"]


def asegurar_coleccion(mb: Metabase) -> int:
    for item in mb.llamar("GET", "/collection"):
        if item.get("name") == COLECCION and not item.get("archived"):
            return item["id"]
    return mb.llamar("POST", "/collection", json={"name": COLECCION})["id"]


def configuracion_visual(config: dict) -> dict:
    ajustes = {}
    if "dim" in config:
        ajustes["graph.dimensions"] = config["dim"]
        ajustes["graph.metrics"] = config["met"]
    ajustes.update(config.get("extra", {}))
    return ajustes


def guardar_tarjeta(mb: Metabase, base: int, coleccion: int, existentes: dict, clave: str,
                    titulo: str, sql: str, config: dict) -> int:
    cuerpo = {
        "name": f"{clave} {titulo}",
        "collection_id": coleccion,
        "display": config["display"],
        "dataset_query": {"type": "native", "database": base, "native": {"query": sql}},
        "visualization_settings": configuracion_visual(config),
    }
    if cuerpo["name"] in existentes:
        tarjeta = mb.llamar("PUT", f"/card/{existentes[cuerpo['name']]}", json=cuerpo)
    else:
        tarjeta = mb.llamar("POST", "/card", json=cuerpo)
    return tarjeta["id"]


def armar_tablero(mb: Metabase, coleccion: int, tarjetas: dict[str, int]) -> int:
    existentes = [d for d in mb.llamar("GET", "/dashboard") if d["name"] == TABLERO and not d.get("archived")]
    if existentes:
        id_tablero = existentes[0]["id"]
    else:
        id_tablero = mb.llamar("POST", "/dashboard", json={
            "name": TABLERO,
            "collection_id": coleccion,
            "description": "Indicadores de viajes de taxi de Nueva York (yellow y green), 2024 a 2026.",
        })["id"]
    dashcards = []
    for numero, (clave, id_tarjeta) in enumerate(sorted(tarjetas.items()), start=1):
        c = INDICADORES[clave]
        dashcards.append({
            "id": -numero, "card_id": id_tarjeta,
            "row": c["fila"], "col": c["col"], "size_x": c["ancho"], "size_y": c["alto"],
            "parameter_mappings": [], "visualization_settings": {},
        })
    mb.llamar("PUT", f"/dashboard/{id_tablero}", json={"dashcards": dashcards})
    return id_tablero


def main() -> None:
    parser = argparse.ArgumentParser(description="Crea el tablero del Ej. 7 en Metabase.")
    parser.add_argument("--url", default=URL_POR_DEFECTO, help=f"URL de Metabase (por defecto {URL_POR_DEFECTO})")
    argumentos = parser.parse_args()

    mb = Metabase(argumentos.url)
    mb.esperar()
    mb.iniciar_sesion()
    base = asegurar_base(mb)
    coleccion = asegurar_coleccion(mb)

    indicadores = leer_indicadores()
    faltan = set(INDICADORES) - set(indicadores)
    if faltan:
        raise SystemExit(f"Faltan consultas en {SQL_INDICADORES.name}: {sorted(faltan)}")

    tarjetas_previas = {
        t["name"]: t["id"] for t in mb.llamar("GET", "/card") if t.get("collection_id") == coleccion
    }
    tarjetas = {}
    for clave, (titulo, sql) in indicadores.items():
        tarjetas[clave] = guardar_tarjeta(mb, base, coleccion, tarjetas_previas, clave, titulo, sql,
                                          INDICADORES[clave])
        print(f"  tarjeta {clave} {titulo}")

    id_tablero = armar_tablero(mb, coleccion, tarjetas)
    print(f"\nTablero listo: http://localhost:3000/dashboard/{id_tablero}")
    print(f"Usuario: {CORREO}   Clave: {CLAVE}")


if __name__ == "__main__":
    sys.exit(main())
